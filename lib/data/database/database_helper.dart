import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';

/// خدمة SQLite المركزية - Singleton
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  // ─── تهيئة قاعدة البيانات ────────────────────────────────────────────────
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCustomers} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gsm TEXT,
        g_id INTEGER,
        cus_type_id INTEGER,
        notes TEXT,
        is_archived INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCurrency} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableTransactions} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        cus_id INTEGER REFERENCES ${AppConstants.tableCustomers}(ID),
        "in" INTEGER,
        "out" REAL,
        date_ TEXT,
        remarks TEXT,
        curr_id INTEGER REFERENCES ${AppConstants.tableCurrency}(ID),
        t_cus_id INTEGER,
        now_ TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableGroups} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCusType} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
    await _createIndexes(db);
    // بيانات افتراضية للعملات
    await db.insert(AppConstants.tableCurrency, {'name': 'محلي'});
    await db.insert(AppConstants.tableCurrency, {'name': 'دولار'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createIndexes(db);
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, AppConstants.tableCustomers, 'notes', 'TEXT');
      await _addColumnIfMissing(db, AppConstants.tableCustomers, 'is_archived', 'INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      // فهرس مركّب جديد (idx_tx_cus_curr). _createIndexes يستخدم IF NOT EXISTS
      // فلا يضرّ إعادة استدعائه، ويضمن وجود جميع الفهارس بعد الترقية.
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_cus_id ON ${AppConstants.tableTransactions}(cus_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_curr_id ON ${AppConstants.tableTransactions}(curr_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_date ON ${AppConstants.tableTransactions}(date_)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cus_name ON ${AppConstants.tableCustomers}(name)');
    // فهرس مركّب للاستعلام الأكثر سخونة: حركات عميل في عملة محددة
    // (WHERE cus_id=? AND curr_id=?) — يخدم شاشة تفاصيل العميل وحساب الرصيد.
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_cus_curr ON ${AppConstants.tableTransactions}(cus_id, curr_id)');
  }

  // ─── استيراد قاعدة بيانات خارجية ────────────────────────────────────────
  // آمن ضد فقدان البيانات: نتحقق من سلامة الملف المصدر ومن مطابقته لمخطط
  // التطبيق *قبل* استبدال قاعدة البيانات الحيّة، ثم ننسخ إلى ملف مؤقّت ونعيد
  // تسميته ذرّياً، ونحتفظ بنسخة تراجع نستعيدها عند أي فشل.
  Future<bool> importDatabase(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return false;

    // 1) التحقق من سلامة ومخطط الملف المصدر قبل لمس قاعدة البيانات الحيّة.
    if (!await _validateSourceDatabase(sourcePath)) return false;

    final dbPath = await getDatabasesPath();
    final targetPath = join(dbPath, AppConstants.dbName);
    final tempPath = '$targetPath.import_tmp';
    final backupPath = '$targetPath.import_bak';

    await closeDb();

    final targetFile = File(targetPath);
    final hadExisting = await targetFile.exists();

    try {
      // 2) احتفظ بنسخة تراجع من قاعدة البيانات الحالية.
      if (hadExisting) await targetFile.copy(backupPath);

      // 3) انسخ المصدر إلى ملف مؤقّت ثم أعد تسميته ذرّياً فوق الهدف.
      await sourceFile.copy(tempPath);
      await File(tempPath).rename(targetPath);

      // احذف ملفّي WAL/SHM القديمين حتى لا يُدمجا في القاعدة المستوردة الجديدة
      // (قد يؤدّي بقاؤهما إلى تلف البيانات عند الفتح).
      await _deleteSidecars(targetPath);

      // 4) أعد الفتح وطبّق مواءمة الأعمدة القديمة ثم تحقّق نهائياً.
      _db = await _initDb();
      await _ensureLegacyCompatibility();
      await _createIndexes(await db);

      if (!await validateTables()) {
        await _rollbackImport(targetPath, backupPath, hadExisting);
        return false;
      }

      await _cleanupImportArtifacts(tempPath, backupPath);
      return true;
    } catch (_) {
      await _rollbackImport(targetPath, backupPath, hadExisting);
      await _cleanupImportArtifacts(tempPath, null);
      return false;
    }
  }

  // يستعيد قاعدة البيانات الأصلية من نسخة التراجع بعد فشل الاستيراد.
  Future<void> _rollbackImport(
      String targetPath, String backupPath, bool hadExisting) async {
    try {
      await closeDb();
      await _deleteSidecars(targetPath);
      final backup = File(backupPath);
      if (await backup.exists()) {
        await backup.copy(targetPath);
        await backup.delete();
      } else if (!hadExisting) {
        // لم تكن هناك قاعدة بيانات قبل الاستيراد: احذف الملف التالف إن وُجد.
        final target = File(targetPath);
        if (await target.exists()) await target.delete();
      }
    } catch (_) {
      // لا شيء أكثر يمكن فعله؛ سيُعاد الفتح أدناه.
    } finally {
      _db = await _initDb();
    }
  }

  // يحذف ملفّي WAL/SHM المصاحبين لقاعدة البيانات (إن وُجدا).
  Future<void> _deleteSidecars(String targetPath) async {
    for (final suffix in const ['-wal', '-shm']) {
      try {
        final f = File('$targetPath$suffix');
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _cleanupImportArtifacts(String tempPath, String? backupPath) async {
    try {
      final temp = File(tempPath);
      if (await temp.exists()) await temp.delete();
      if (backupPath != null) {
        final backup = File(backupPath);
        if (await backup.exists()) await backup.delete();
      }
    } catch (_) {}
  }

  // يتحقّق من سلامة الملف (integrity_check) ومن مطابقته لمخطط التطبيق،
  // بفتحه للقراءة فقط دون المساس بقاعدة البيانات الحيّة.
  Future<bool> _validateSourceDatabase(String path) async {
    Database? tempDb;
    try {
      tempDb = await openDatabase(path, readOnly: true);
      final result = await tempDb.rawQuery('PRAGMA integrity_check');
      if (result.isEmpty) return false;
      final status = result.first.values.first?.toString().toLowerCase();
      if (status != 'ok') return false;
      return await _hasRequiredSchema(tempDb);
    } catch (_) {
      return false;
    } finally {
      await tempDb?.close();
    }
  }

  // ─── تصدير نسخة احتياطية ─────────────────────────────────────────────────
  // ملاحظة: الوجهة هي تخزين خاص بالتطبيق
  // (getExternalStorageDirectory → /Android/data/<pkg>/files، أو مجلّد
  // المستندات). هذه النسخ تُحذف عند إزالة تثبيت التطبيق ولا تظهر للمستخدم في
  // مدير الملفات. للاحتفاظ الدائم يجب على المستخدم استخدام «مشاركة/تصدير» يدوياً
  // لحفظ الملف في موقع يختاره.
  Future<String?> exportDatabase(String fileName) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, AppConstants.dbName);

      // دمج سجل WAL في الملف الرئيسي قبل النسخ حتى تكون النسخة متّسقة ولا تفقد
      // آخر الكتابات (وإلا فقد تكون النسخة ناقصة إن كانت قاعدة البيانات بوضع WAL).
      await _checkpointWal();

      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final targetPath = join(dir.path, fileName);

      await File(sourcePath).copy(targetPath);
      return targetPath;
    } catch (e) {
      return null;
    }
  }

  // يدمج سجلّ WAL في ملف قاعدة البيانات الرئيسي (لا يفعل شيئاً خارج وضع WAL).
  Future<void> _checkpointWal() async {
    try {
      final database = await db;
      await database.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // إن تعذّر عمل checkpoint نُكمل بنسخ الملف كما هو.
    }
  }

  // ─── نسخة احتياطية تلقائية (تحتفظ بآخر 5 نسخ فقط) ─────────────────────
  Future<String?> autoBackup() async {
    final now = DateTime.now();
    final name =
        'auto_backup_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.db';
    final result = await exportDatabase(name);
    if (result != null) await _rotateBackups();
    return result;
  }

  // احتفظ بآخر 5 نسخ تلقائية فقط
  Future<void> _rotateBackups() async {
    try {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('auto_backup_') && f.path.endsWith('.db'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      const keepCount = 5;
      if (files.length > keepCount) {
        for (final f in files.take(files.length - keepCount)) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> closeDb() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<bool> _tableExists(Database database, String table) async {
    final res = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return res.isNotEmpty;
  }

  Future<Set<String>> _tableColumns(Database database, String table) async {
    final rows = await database.rawQuery('PRAGMA table_info($table)');
    return rows
        .map((r) => (r['name'] ?? '').toString().trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  Future<void> _addColumnIfMissing(
    Database database,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await _tableColumns(database, table);
    if (!columns.contains(column.toLowerCase())) {
      await database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // ─── مواءمة قواعد بيانات قديمة مع الأعمدة اللازم�� للتطبيق ────────────────
  Future<void> _ensureLegacyCompatibility() async {
    final database = await db;

    if (await _tableExists(database, AppConstants.tableCustomers)) {
      await _addColumnIfMissing(database, AppConstants.tableCustomers, 'gsm', 'TEXT');
      await _addColumnIfMissing(database, AppConstants.tableCustomers, 'g_id', 'INTEGER');
      await _addColumnIfMissing(database, AppConstants.tableCustomers, 'cus_type_id', 'INTEGER');
      await _addColumnIfMissing(database, AppConstants.tableCustomers, 'notes', 'TEXT');
      await _addColumnIfMissing(database, AppConstants.tableCustomers, 'is_archived', 'INTEGER DEFAULT 0');
    }

    if (await _tableExists(database, AppConstants.tableTransactions)) {
      await _addColumnIfMissing(database, AppConstants.tableTransactions, 'remarks', 'TEXT');
      await _addColumnIfMissing(database, AppConstants.tableTransactions, 'curr_id', 'INTEGER');
      await _addColumnIfMissing(database, AppConstants.tableTransactions, 't_cus_id', 'INTEGER');
      await _addColumnIfMissing(database, AppConstants.tableTransactions, 'now_', 'TEXT');
    }

    await database.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableGroups} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCusType} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
    // reminders اختياري: لا ننشئه ولا نفرضه كي تبقى الاستعادة متوافقة مع كل النسخ.

    // اضمن وجود الفهارس بعد أي مواءمة (مثلاً بعد استيراد قاعدة قديمة
    // user_version‏≥3 تتخطّى _onUpgrade فتبقى بلا فهارس). idempotent.
    await _createIndexes(database);
  }

  // ─── التحقق من وجود الجداول والأعمدة الأساسية ─────────────────────────────
  Future<bool> validateTables() async {
    try {
      return await _hasRequiredSchema(await db);
    } catch (_) {
      return false;
    }
  }

  // يتحقّق من وجود الجداول والأعمدة الأساسية التي يحتاجها التطبيق في [database].
  Future<bool> _hasRequiredSchema(Database database) async {
    const required = <String, Set<String>>{
      AppConstants.tableCustomers: {'id', 'name'},
      AppConstants.tableTransactions: {'id', 'cus_id', 'in', 'out', 'date_'},
      AppConstants.tableCurrency: {'id', 'name'},
    };

    for (final entry in required.entries) {
      if (!await _tableExists(database, entry.key)) return false;
      final cols = await _tableColumns(database, entry.key);
      if (!cols.containsAll(entry.value)) return false;
    }

    // reminders اختياري: وجوده أو غيابه لا يفشل التحقق.
    return true;
  }
}

