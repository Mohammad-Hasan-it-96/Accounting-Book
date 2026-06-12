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
  }

  // ─── استيراد قاعدة بيانات خارجية ────────────────────────────────────────
  Future<bool> importDatabase(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return false;

      // التحقق من سلامة الملف المصدر قبل الاستبدال
      if (!await _validateSourceDatabase(sourcePath)) return false;

      await closeDb();

      final dbPath = await getDatabasesPath();
      final targetPath = join(dbPath, AppConstants.dbName);
      await sourceFile.copy(targetPath);

      _db = await _initDb();
      await _ensureLegacyCompatibility();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _validateSourceDatabase(String path) async {
    Database? tempDb;
    try {
      tempDb = await openDatabase(path, readOnly: true);
      final result = await tempDb.rawQuery('PRAGMA integrity_check');
      if (result.isEmpty) return false;
      final status = result.first.values.first?.toString().toLowerCase();
      return status == 'ok';
    } catch (_) {
      return false;
    } finally {
      await tempDb?.close();
    }
  }

  // ─── تصدير نسخة احتياطية ─────────────────────────────────────────────────
  Future<String?> exportDatabase(String fileName) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, AppConstants.dbName);

      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final targetPath = join(dir.path, fileName);

      await File(sourcePath).copy(targetPath);
      return targetPath;
    } catch (e) {
      return null;
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
  }

  // ─── التحقق من وجود الجداول والأعمدة الأساسية ─────────────────────────────
  Future<bool> validateTables() async {
    try {
      final database = await db;

      final required = <String, Set<String>>{
        AppConstants.tableCustomers: {'id', 'name'},
        AppConstants.tableTransactions: {'id', 'cus_id', 'in', 'out', 'date_'},
        AppConstants.tableCurrency: {'id', 'name'},
      };

      for (final entry in required.entries) {
        final table = entry.key;
        final mustHave = entry.value;
        if (!await _tableExists(database, table)) return false;
        final cols = await _tableColumns(database, table);
        if (!cols.containsAll(mustHave)) return false;
      }

      // reminders اختياري: وجوده أو غيابه لا يفشل التحقق.
      return true;
    } catch (_) {
      return false;
    }
  }
}

