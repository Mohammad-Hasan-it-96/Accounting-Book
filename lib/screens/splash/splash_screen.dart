import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/activation_service.dart';
import '../../providers/theme_provider.dart';
import '../activation/activation_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    // ─── animation بسيط: scale bounce → fade النص ──────────────────────────
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.12), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0),  weight: 35),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.45, 1.0, curve: Curves.easeIn)),
    );

    _ctrl.forward();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ─── منطق التهيئة ────────────────────────────────────────────────────────
  Future<void> _init() async {
    // كل المهام تعمل بالتوازي — لا انتظار متسلسل
    final results = await Future.wait<dynamic>([
      context.read<ThemeProvider>().load(),     // [0] تحميل الثيم
      ActivationService().isActivated(),         // [1] هل التطبيق مفعّل؟
      Future.delayed(const Duration(milliseconds: 800)), // [2] حد أدنى للعرض
    ]);

    if (!mounted) return;

    final isActivated = results[1] as bool;

    // انتقال Fade خفيف
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            isActivated ? const HomeScreen() : const ActivationScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    // ملاحظة:
    // • HomeScreen يتولى loadCurrencies() و checkForUpdate() بعد العرض
    // • force_update يعالجه UpdateDialog في HomeScreen (canPop=false)
  }

  // ─── واجهة Splash ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── أيقونة مع scale bounce ───────────────────────────────
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ─── اسم التطبيق + وصف مختصر ─────────────────────────────
            FadeTransition(
              opacity: _fade,
              child: const Column(
                children: [
                  Text(
                    'دفتر حسابات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'إدارة الحسابات بسهولة',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
            // ─── مؤشر تحميل خفيف ─────────────────────────────────────
            FadeTransition(
              opacity: _fade,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
