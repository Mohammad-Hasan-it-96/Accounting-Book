import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';
import '../../core/constants/app_constants.dart';

/// مستودع العمليات على جدول العملاء
class CustomerRepository {
  final DatabaseHelper _dbHelper;
  CustomerRepository(this._dbHelper);

  Future<Database> get _db async => _dbHelper.db;

  /// جلب كل العملاء
  Future<List<Customer>> getAll() async {
    final db = await _db;
    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(
        '''SELECT c.*, g.name AS group_name
           FROM ${AppConstants.tableCustomers} c
           LEFT JOIN ${AppConstants.tableGroups} g ON g.ID = c.g_id
           ORDER BY c.name''',
      );
    } catch (_) {
      rows = await db.query(AppConstants.tableCustomers, orderBy: 'name');
    }
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  /// البحث بالاسم
  Future<List<Customer>> search(String query) async {
    final db = await _db;
    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(
        '''SELECT c.*, g.name AS group_name
           FROM ${AppConstants.tableCustomers} c
           LEFT JOIN ${AppConstants.tableGroups} g ON g.ID = c.g_id
           WHERE c.name LIKE ?
           ORDER BY c.name''',
        ['%$query%'],
      );
    } catch (_) {
      rows = await db.query(
        AppConstants.tableCustomers,
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'name',
      );
    }
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  /// إضافة عميل جديد
  Future<int> insert(Customer customer) async {
    final db = await _db;
    return db.insert(AppConstants.tableCustomers, customer.toMap());
  }

  /// تعديل عميل
  Future<int> update(Customer customer) async {
    final db = await _db;
    return db.update(
      AppConstants.tableCustomers,
      customer.toMap(),
      where: 'ID = ?',
      whereArgs: [customer.id],
    );
  }

  /// التحقق إن كان للعميل حركات مرتبطة
  Future<bool> hasTransactions(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${AppConstants.tableTransactions} WHERE cus_id = ?',
      [id],
    );
    final count = (rows.first['cnt'] as num?)?.toInt() ?? 0;
    return count > 0;
  }

  /// حذف عميل
  Future<int> delete(int id) async {
    final db = await _db;
    if (await hasTransactions(id)) {
      throw StateError('customer_has_transactions');
    }
    return db.delete(
      AppConstants.tableCustomers,
      where: 'ID = ?',
      whereArgs: [id],
    );
  }
}

