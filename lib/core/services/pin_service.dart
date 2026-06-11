import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class PinService {
  static final PinService _instance = PinService._internal();
  factory PinService() => _instance;
  PinService._internal();

  static const _keyPin = 'app_pin_hash';
  static const _keyPinEnabled = 'app_pin_enabled';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isPinEnabled() async {
    final val = await _storage.read(key: _keyPinEnabled);
    return val == 'true';
  }

  Future<void> setPin(String pin) async {
    final hash = _hash(pin);
    await _storage.write(key: _keyPin, value: hash);
    await _storage.write(key: _keyPinEnabled, value: 'true');
  }

  Future<void> disablePin() async {
    await _storage.delete(key: _keyPin);
    await _storage.write(key: _keyPinEnabled, value: 'false');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _keyPin);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  String _hash(String pin) =>
      sha256.convert(utf8.encode('daftar_pin_$pin')).toString();
}
