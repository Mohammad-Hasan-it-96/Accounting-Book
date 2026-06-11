import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/services/pin_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _localAuth = LocalAuthentication();
  String _entered = '';
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (mounted) setState(() => _biometricAvailable = canCheck && isSupported);
      if (_biometricAvailable) _tryBiometric();
    } catch (_) {}
  }

  Future<void> _tryBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'استخدم بصمتك أو وجهك لفتح التطبيق',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (authenticated && mounted) Navigator.pop(context, true);
    } catch (_) {}
  }

  void _pressDigit(String digit) {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 4 || _entered.length == 6) _verify();
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    final ok = await PinService().verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'رمز غير صحيح';
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'أدخل رمز القفل',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
            const SizedBox(height: 24),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _entered.length
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Numpad
            _NumPad(
              onDigit: _pressDigit,
              onDelete: _backspace,
              onBiometric: _biometricAvailable ? _tryBiometric : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  const _NumPad({
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        ...rows.map(
          (row) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) => _PadButton(label: d, onTap: () => onDigit(d))).toList(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            onBiometric != null
                ? _PadButton(
                    icon: Icons.fingerprint,
                    onTap: onBiometric!,
                  )
                : const SizedBox(width: 80),
            _PadButton(label: '0', onTap: () => onDigit('0')),
            _PadButton(icon: Icons.backspace_outlined, onTap: onDelete),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _PadButton({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Center(
          child: label != null
              ? Text(label!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500))
              : Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
