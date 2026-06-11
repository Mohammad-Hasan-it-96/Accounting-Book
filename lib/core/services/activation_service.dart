import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';
/// خدمة التفعيل — مخصّصة لتطبيق دفتر الحسابات
class ActivationService {
  static final ActivationService _instance = ActivationService._internal();
  factory ActivationService() => _instance;
  ActivationService._internal();
  // ─── مفاتيح SharedPreferences ────────────────────────────────────────────
  static const _keyIsActivated = 'is_activated';
  static const _keyDeviceId    = 'device_id';
  static const _keyUserName    = 'user_name';
  static const _keyUserPhone   = 'user_phone';
  // ─── حالة التفعيل ────────────────────────────────────────────────────────
  Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsActivated) ?? false;
  }
  // ─── بيانات المستخدم ─────────────────────────────────────────────────────
  Future<String?> getUserName()  async => (await SharedPreferences.getInstance()).getString(_keyUserName);
  Future<String?> getUserPhone() async => (await SharedPreferences.getInstance()).getString(_keyUserPhone);
  Future<void> saveUserData(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName,  name.trim());
    await prefs.setString(_keyUserPhone, phone.trim());
  }
  // ─── توليد معرّف الجهاز ───────────────────────────────────────────────────
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDeviceId);
    if (saved != null && saved.isNotEmpty) return saved;
    String rawId = 'accounting_book_fallback';
    try {
      if (Platform.isAndroid) {
        final aid = await const AndroidId().getId();
        if (aid != null && aid.isNotEmpty) {
          rawId = aid;
        } else {
          rawId = (await DeviceInfoPlugin().androidInfo).id;
        }
      } else if (Platform.isIOS) {
        rawId = (await DeviceInfoPlugin().iosInfo).identifierForVendor ?? 'ios_fallback';
      }
    } catch (_) {}
    // salt مخصص للتطبيق
    final hash = sha256.convert(utf8.encode('${rawId}_accounting_book_app')).toString();
    await prefs.setString(_keyDeviceId, hash);
    return hash;
  }
  // ─── إرسال طلب التفعيل ───────────────────────────────────────────────────
  Future<ActivationResult> requestActivation({
    required String name,
    required String phone,
  }) async {
    try {
      await saveUserData(name, phone);
      final deviceId = await getDeviceId();
      final apiUrl   = await SettingsService().getApiUrl();
      final response = await http.post(
        Uri.parse('$apiUrl/create_device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id'  : deviceId,
          'full_name'  : name.trim(),
          'phone'      : phone.trim(),
          'app_name'   : 'daftar_hesabat',
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawVerified = body['data']?['is_verified'] ?? body['is_verified'];
        final verified = rawVerified == true || rawVerified == 1;
        if (verified) {
          await _markActivated();
          return ActivationResult.success('تم التفعيل بنجاح! مرحباً $name');
        }
        return ActivationResult.pending('تم إرسال طلب التفعيل.\nسيتم تفعيل الجهاز قريباً — اضغط "تحقق من التفعيل" بعد موافقة المطوّر.');
      }
      if (response.statusCode == 409 || response.statusCode == 422) {
        // الجهاز مسجّل مسبقاً — تحقق من الحالة
        return checkActivation();
      }
      return ActivationResult.error('خطأ من السيرفر (${response.statusCode}). حاول مجدداً أو تواصل مع الدعم.');
    } on SocketException {
      return ActivationResult.error('لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مجدداً.');
    } on TimeoutException {
      return ActivationResult.error('انتهت مهلة الاتصال. حاول مجدداً.');
    } on FormatException {
      return ActivationResult.error('استجابة غير متوقعة من الخادم.');
    } on http.ClientException {
      return ActivationResult.error('تعذر الوصول إلى السيرفر. تحقق من الاتصال.');
    } on Exception {
      return ActivationResult.error('حدث خطأ غير متوقع. حاول مجدداً.');
    }
  }
  // ─── التحقق من حالة التفعيل على السيرفر ─────────────────────────────────
  Future<ActivationResult> checkActivation() async {
    try {
      final deviceId = await getDeviceId();
      final apiUrl   = await SettingsService().getApiUrl();
      final response = await http.post(
        Uri.parse('$apiUrl/check_device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': deviceId , 'app_name': 'daftar_hesabat'}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawVerified = body['data']?['is_verified'] ?? body['is_verified'];
        final verified = rawVerified == true || rawVerified == 1;
        if (verified) {
          await _markActivated();
          final name = await getUserName() ?? '';
          return ActivationResult.success('تم التفعيل بنجاح!${name.isNotEmpty ? " مرحباً $name" : ""}');
        }
        return ActivationResult.pending('الجهاز في انتظار موافقة المطوّر.\nتواصل معه عبر واتساب أو تيليغرام.');
      }
      return ActivationResult.error('تعذر التحقق (${response.statusCode}). حاول لاحقاً.');
    } on SocketException {
      return ActivationResult.error('لا يوجد اتصال بالإنترنت.');
    } on TimeoutException {
      return ActivationResult.error('انتهت مهلة الاتصال. حاول مجدداً.');
    } on FormatException {
      return ActivationResult.error('استجابة غير متوقعة من الخادم.');
    } on Exception {
      return ActivationResult.error('حدث خطأ غير متوقع. حاول مجدداً.');
    }
  }
  Future<void> _markActivated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsActivated, true);
  }
  /// إعادة التعيين — للاختبار أو نقل الترخيص لجهاز آخر
  Future<void> resetActivation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsActivated);
  }
}
// ─── نتيجة التفعيل ────────────────────────────────────────────────────────────
enum _Status { success, pending, error }
class ActivationResult {
  final _Status _status;
  final String message;
  const ActivationResult._(_Status s, this.message) : _status = s;
  factory ActivationResult.success(String msg) => ActivationResult._(_Status.success, msg);
  factory ActivationResult.pending(String msg)  => ActivationResult._(_Status.pending,  msg);
  factory ActivationResult.error(String msg)    => ActivationResult._(_Status.error,    msg);
  bool get isSuccess => _status == _Status.success;
  bool get isPending  => _status == _Status.pending;
  bool get isError    => _status == _Status.error;
}
