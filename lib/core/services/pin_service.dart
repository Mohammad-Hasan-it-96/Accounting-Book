import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

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

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isPinEnabled() async {
    final val = await _storage.read(key: _keyPinEnabled);
    return val == 'true';
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _keyPin, value: _hash(pin));
    await _storage.write(key: _keyPinEnabled, value: 'true');
    await clearFailedAttempts();
  }

  Future<void> changePin(String newPin) async {
    await _storage.write(key: _keyPin, value: _hash(newPin));
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
    return stored == _hash(pin);
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
    if (next >= maxFailedAttempts) {
      final until = DateTime.now().add(const Duration(minutes: lockoutDurationMinutes));
      await _storage.write(key: _keyLockedUntil, value: until.millisecondsSinceEpoch.toString());
      await _storage.write(key: _keyFailedAttempts, value: '0');
    } else {
      await _storage.write(key: _keyFailedAttempts, value: next.toString());
    }
  }

  Future<void> clearFailedAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockedUntil);
  }

  String _hash(String pin) =>
      sha256.convert(utf8.encode('daftar_pin_$pin')).toString();
}
