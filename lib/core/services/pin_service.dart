import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── اشتقاق المفتاح (PBKDF2-HMAC-SHA256) خارج خيط الواجهة ────────────────────
// تُنفَّذ عبر compute في عزلة منفصلة حتى لا تُجمّد الواجهة أثناء التكرارات.
// message: {'pin': String, 'salt': List<int>, 'iterations': int} → قيمة b64.
String _deriveKeyIsolate(Map<String, dynamic> args) {
  final pin = args['pin'] as String;
  final salt = (args['salt'] as List).cast<int>();
  final iterations = args['iterations'] as int;
  final dk = _pbkdf2(utf8.encode(pin), salt, iterations, 32);
  return base64.encode(dk);
}

// تنفيذ PBKDF2 قياسي فوق HMAC-SHA256 (RFC 2898). dkLen بالبايت.
List<int> _pbkdf2(List<int> password, List<int> salt, int iterations, int dkLen) {
  final hmac = Hmac(sha256, password);
  final numBlocks = (dkLen / 32).ceil();
  final out = <int>[];
  for (var block = 1; block <= numBlocks; block++) {
    final blockIndex = [
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];
    var u = hmac.convert([...salt, ...blockIndex]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.addAll(t);
  }
  return out.sublist(0, dkLen);
}

class PinService {
  static final PinService _instance = PinService._internal();
  factory PinService() => _instance;
  PinService._internal();

  static const _keyPin            = 'app_pin_hash';
  static const _keyPinEnabled     = 'app_pin_enabled';
  static const _keyFailedAttempts = 'pin_failed_attempts';
  static const _keyLockedUntil    = 'pin_locked_until';

  static const int maxFailedAttempts      = 5;
  static const int lockoutDurationMinutes = 5;

  // معاملات KDF لصيغة التخزين v2. الصيغة: v2$<saltB64>$<iterations>$<dkB64>.
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength       = 16;
  static const String _hashV2Prefix  = 'v2';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isPinEnabled() async {
    final val = await _storage.read(key: _keyPinEnabled);
    return val == 'true';
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _keyPin, value: await _hashV2(pin));
    await _storage.write(key: _keyPinEnabled, value: 'true');
    await clearFailedAttempts();
  }

  Future<void> changePin(String newPin) async {
    await _storage.write(key: _keyPin, value: await _hashV2(newPin));
    await clearFailedAttempts();
  }

  Future<void> disablePin() async {
    await _storage.delete(key: _keyPin);
    await _storage.write(key: _keyPinEnabled, value: 'false');
    await clearFailedAttempts();
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _keyPin);
    if (stored == null) return false;

    // صيغة v2 (PBKDF2 + salt): اشتق بنفس الـ salt/التكرارات المخزّنة وقارن.
    if (stored.startsWith('$_hashV2Prefix\$')) {
      final parts = stored.split(r'$');
      if (parts.length != 4) return false;
      final List<int> salt;
      try {
        salt = base64.decode(parts[1]);
      } catch (_) {
        return false;
      }
      final iterations = int.tryParse(parts[2]) ?? _pbkdf2Iterations;
      final expected = parts[3];
      final actual = await compute(_deriveKeyIsolate, <String, dynamic>{
        'pin': pin,
        'salt': salt,
        'iterations': iterations,
      });
      return _constantTimeEquals(actual, expected);
    }

    // صيغة قديمة (SHA-256 غير مملّح): تحقّق، وعند النجاح رقِّ التخزين إلى v2.
    if (_constantTimeEquals(_legacyHash(pin), stored)) {
      try {
        await _storage.write(key: _keyPin, value: await _hashV2(pin));
      } catch (_) {
        // فشل الترقية لا يمنع فتح القفل؛ سنعيد المحاولة في المرّة القادمة.
      }
      return true;
    }
    return false;
  }

  // ─── قفل المحاولات الفاشلة ───────────────────────────────────────────────
  Future<bool> isLockedOut() async {
    final v = await _storage.read(key: _keyLockedUntil);
    if (v == null) return false;
    final ms = int.tryParse(v);
    if (ms == null) return false;
    return DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  Future<DateTime?> lockedUntil() async {
    final v = await _storage.read(key: _keyLockedUntil);
    if (v == null) return null;
    final ms = int.tryParse(v);
    if (ms == null) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().isBefore(dt) ? dt : null;
  }

  Future<int> getFailedAttempts() async {
    final val = await _storage.read(key: _keyFailedAttempts);
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<void> recordFailedAttempt() async {
    final current = await getFailedAttempts();
    final next = current + 1;
    await _storage.write(key: _keyFailedAttempts, value: next.toString());
    // لا نُصفّر العدّاد عند القفل: يبقى ≥ الحد، فبعد انتهاء مهلة القفل تؤدّي أول
    // محاولة فاشلة إلى قفل فوري مجدّداً بدل منح 5 محاولات كل نافذة إلى ما لا
    // نهاية. يُصفَّر العدّاد فقط عند فتح ناجح (clearFailedAttempts).
    if (next >= maxFailedAttempts) {
      final until =
          DateTime.now().add(const Duration(minutes: lockoutDurationMinutes));
      await _storage.write(
          key: _keyLockedUntil, value: until.millisecondsSinceEpoch.toString());
    }
  }

  Future<void> clearFailedAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockedUntil);
  }

  // يبني تجزئة v2 بـ salt عشوائي جديد لكل عملية تعيين/تغيير.
  Future<String> _hashV2(String pin) async {
    final salt = _randomBytes(_saltLength);
    final dkB64 = await compute(_deriveKeyIsolate, <String, dynamic>{
      'pin': pin,
      'salt': salt,
      'iterations': _pbkdf2Iterations,
    });
    return [
      _hashV2Prefix,
      base64.encode(salt),
      '$_pbkdf2Iterations',
      dkB64,
    ].join(r'$');
  }

  // التجزئة القديمة (للتحقّق من تثبيتات ما قبل الترقية فقط).
  String _legacyHash(String pin) =>
      sha256.convert(utf8.encode('daftar_pin_$pin')).toString();

  List<int> _randomBytes(int n) {
    final rnd = Random.secure();
    return List<int>.generate(n, (_) => rnd.nextInt(256));
  }

  // مقارنة بزمن ثابت لتفادي تسريب المعلومات عبر توقيت المقارنة.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
