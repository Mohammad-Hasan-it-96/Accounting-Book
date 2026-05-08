import 'package:flutter/material.dart';
import '../core/services/settings_service.dart';
class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;
  Future<void> load() async {
    _isDark = await SettingsService().getDarkMode();
    notifyListeners();
  }
  Future<void> toggle() async {
    _isDark = !_isDark;
    await SettingsService().setDarkMode(_isDark);
    notifyListeners();
  }
  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    await SettingsService().setDarkMode(value);
    notifyListeners();
  }
}
