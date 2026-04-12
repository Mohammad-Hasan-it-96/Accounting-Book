import 'package:flutter/material.dart';
import '../data/database/database_helper.dart';
import '../data/models/currency.dart';
import '../data/repositories/currency_repository.dart';

/// Provider مركزي خفيف - يخزن العملات المتاحة فقط
class AppProvider extends ChangeNotifier {
  final DatabaseHelper dbHelper;

  AppProvider(this.dbHelper);

  List<Currency> _currencies = [];
  bool _loading = false;

  List<Currency> get currencies => _currencies;
  bool get loading => _loading;

  /// العملة الليرة (أول عملة يكون displayName == 'ليرة')
  Currency? get liraCurrency =>
      _currencies.cast<Currency?>().firstWhere(
            (c) => c?.isLira == true,
            orElse: () => null,
          );

  /// العملة الدولار
  Currency? get dollarCurrency =>
      _currencies.cast<Currency?>().firstWhere(
            (c) => c?.isDollar == true,
            orElse: () => null,
          );

  Future<void> loadCurrencies() async {
    _loading = true;
    notifyListeners();
    try {
      final repo = CurrencyRepository(dbHelper);
      _currencies = await repo.getAll();
    } catch (_) {
      _currencies = [];
    }
    _loading = false;
    notifyListeners();
  }

  /// إعادة التحميل بعد استيراد قاعدة بيانات
  Future<void> reload() async {
    await loadCurrencies();
  }
}

