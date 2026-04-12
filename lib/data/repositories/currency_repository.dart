import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/currency.dart';
import '../../core/constants/app_constants.dart';

/// مستودع العملات
class CurrencyRepository {
  final DatabaseHelper _dbHelper;
  CurrencyRepository(this._dbHelper);

  Future<Database> get _db async => _dbHelper.db;

  Future<List<Currency>> getAll() async {
    final db = await _db;
    final rows = await db.query(AppConstants.tableCurrency);
    return rows.map(Currency.fromMap).toList();
  }
}

