import 'package:shared_preferences/shared_preferences.dart';

/// خدمة الإعدادات العامة — تُخزّن في SharedPreferences
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // ─── مفاتيح التخزين ──────────────────────────────────────────────────────
  static const _keyApiUrl          = 'api_url';
  static const _keyDarkMode        = 'dark_mode';
  static const _keyLastBackupDate  = 'last_backup_date';
  static const _keyAutoLockTimeout = 'auto_lock_timeout';

  // ─── قيم افتراضية ────────────────────────────────────────────────────────
  static const String defaultApiUrl          = 'https://harrypotter.foodsalebot.com/api';
  static const String supportEmail           = 'mohamad.hasan.it.96@gmail.com';
  static const String supportTelegram        = 'https://t.me/+963983820430';
  static const String supportWhatsApp        = '963983820430';
  static const String updateConfigUrl        =
      'https://raw.githubusercontent.com/Mohammad-Hasan-it-96/Accounting-Book/main/update_config.json';

  // ─── API URL ──────────────────────────────────────────────────────────────
  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiUrl) ?? defaultApiUrl;
  }

  Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiUrl, url);
  }

  Future<void> resetApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyApiUrl);
  }

  // ─── Dark Mode ────────────────────────────────────────────────────────────
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  // ─── تاريخ آخر نسخة احتياطية ─────────────────────────────────────────────
  Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastBackupDate);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastBackupDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastBackupDate, date.millisecondsSinceEpoch);
  }

  // ─── مهلة القفل التلقائي (بالثواني، 0 = معطّل) ──────────────────────────
  Future<int> getAutoLockTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAutoLockTimeout) ?? 0;
  }

  Future<void> setAutoLockTimeout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoLockTimeout, seconds);
  }
}
