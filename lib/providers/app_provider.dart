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
  bool _hasError = false;

  List<Currency> get currencies => _currencies;
  bool get loading => _loading;
  bool get hasError => _hasError;

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
    _hasError = false;
    notifyListeners();
    try {
      final repo = CurrencyRepository(dbHelper);
      _currencies = await repo.getAll();
    } catch (_) {
      _currencies = [];
      _hasError = true;
    }
    _loading = false;
    notifyListeners();
  }

  /// إعادة التحميل بعد استيراد قاعدة بيانات
  Future<void> reload() async {
    await loadCurrencies();
  }
}

