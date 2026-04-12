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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // إنشاء الجداول فقط إذا لم تكن موجودة (قاعدة بيانات جديدة)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCustomers} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gsm TEXT,
        g_id INTEGER,
        cus_type_id INTEGER
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
        cus_id INTEGER,
        "in" INTEGER,
        "out" REAL,
        date_ TEXT,
        remarks TEXT,
        curr_id INTEGER,
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
    // بيانات افتراضية للعملات
    await db.insert(AppConstants.tableCurrency, {'name': 'محلي'});
    await db.insert(AppConstants.tableCurrency, {'name': 'دولار'});
  }

  // ─── استيراد قاعدة بيانات خارجية ────────────────────────────────────────
  Future<bool> importDatabase(String sourcePath) async {
    try {
      // إغلاق الاتصال الحالي
      await closeDb();

      final dbPath = await getDatabasesPath();
      final targetPath = join(dbPath, AppConstants.dbName);

      // نسخ الملف
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return false;
      await sourceFile.copy(targetPath);

      // إعادة الاتصال + مواءمة قواعد قديمة
      _db = await _initDb();
      await _ensureLegacyCompatibility();
      return true;
    } catch (e) {
      return false;
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

  // ─── نسخة احتياطية تلقائية قبل الاستيراد ────────────────────────────────
  Future<String?> autoBackup() async {
    final now = DateTime.now();
    final name =
        'auto_backup_${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}.db';
    return exportDatabase(name);
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
      await _addColumnIfMissing(
          database, AppConstants.tableCustomers, 'cus_type_id', 'INTEGER');
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

