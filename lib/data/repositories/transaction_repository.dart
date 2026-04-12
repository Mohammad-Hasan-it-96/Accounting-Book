import 'package:sqflite/sqflite.dart' hide Transaction;
import '../database/database_helper.dart';
import '../models/transaction.dart' as tx_model;
import '../../core/constants/app_constants.dart';
import '../../core/helpers/format_helper.dart';

/// مستودع العمليات على جدول الحركات
class TransactionRepository {
  final DatabaseHelper _dbHelper;
  TransactionRepository(this._dbHelper);

  Future<Database> get _db async => _dbHelper.db;

  /// حركات عميل محدد لعملة محددة، مرتبة من الأحدث
  Future<List<tx_model.Transaction>> getByCustomerAndCurrency(
      int cusId, int currId) async {
    final db = await _db;
    final rows = await db.query(
      AppConstants.tableTransactions,
      where: 'cus_id = ? AND curr_id = ?',
      whereArgs: [cusId, currId],
      orderBy: 'date_ DESC, ID DESC',
    );
    return rows.map((r) => tx_model.Transaction.fromMap(r)).toList();
  }

  /// كل حركات عملة معينة (لحساب الأرصدة)
  Future<List<tx_model.Transaction>> getByCurrency(int currId) async {
    final db = await _db;
    final rows = await db.query(
      AppConstants.tableTransactions,
      where: 'curr_id = ?',
      whereArgs: [currId],
    );
    return rows.map((r) => tx_model.Transaction.fromMap(r)).toList();
  }

  /// إضافة حركة
  Future<int> insert(tx_model.Transaction transaction) async {
    final db = await _db;
    return db.insert(AppConstants.tableTransactions, transaction.toMap());
  }

  /// تعديل حركة
  Future<int> update(tx_model.Transaction transaction) async {
    final db = await _db;
    return db.update(
      AppConstants.tableTransactions,
      transaction.toMap(),
      where: 'ID = ?',
      whereArgs: [transaction.id],
    );
  }

  /// حذف حركة
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(
      AppConstants.tableTransactions,
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// رصيد عميل في عملة معينة
  Future<double> getBalance(int cusId, int currId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''SELECT SUM(CASE WHEN "in"=1 THEN "out" ELSE -"out" END) as balance
         FROM ${AppConstants.tableTransactions}
         WHERE cus_id=? AND curr_id=?''',
      [cusId, currId],
    );
    return (rows.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// ملخص كل العملاء في عملة واحدة بـ query واحد:
  /// {cusId → {balance: double, txCount: int, lastTxDate: DateTime?}}
  Future<Map<int, CustomerSummary>> getCustomerSummaries(int currId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''SELECT cus_id,
                SUM(CASE WHEN "in"=1 THEN "out" ELSE -"out" END) AS balance,
                COUNT(*) AS tx_count,
                MAX(date_) AS last_tx_date
         FROM ${AppConstants.tableTransactions}
         WHERE curr_id = ?
         GROUP BY cus_id''',
      [currId],
    );
    final result = <int, CustomerSummary>{};
    for (final r in rows) {
      final id = (r['cus_id'] as num).toInt();
      result[id] = CustomerSummary(
        balance: (r['balance'] as num?)?.toDouble() ?? 0.0,
        txCount: (r['tx_count'] as num?)?.toInt() ?? 0,
        lastTxDate: FormatHelper.parseDate((r['last_tx_date'] ?? '').toString()),
      );
    }
    return result;
  }
}

/// ملخص مبسّط يُعاد من getCustomerSummaries
class CustomerSummary {
  final double balance;
  final int txCount;
  final DateTime? lastTxDate;
  const CustomerSummary({
    required this.balance,
    required this.txCount,
    this.lastTxDate,
  });
}

