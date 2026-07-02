import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/services/pin_service.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'data/database/database_helper.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/lock/lock_screen.dart';
import 'screens/splash/splash_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  // مؤقّت أحادي الاتجاه لقياس مدّة بقاء التطبيق في الخلفية. نستخدم Stopwatch
  // (ساعة رتيبة) بدل DateTime.now() حتى لا يستطيع تغيير ساعة الجهاز أو التوقيت
  // الصيفي تجاوز القفل التلقائي (فرق سالب/ضخم مع الساعة الجدارية).
  final Stopwatch _backgrounded = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _backgrounded
        ..reset()
        ..start();
    } else if (state == AppLifecycleState.resumed && _backgrounded.isRunning) {
      final elapsed = _backgrounded.elapsed.inSeconds;
      _backgrounded
        ..stop()
        ..reset();
      final timeout = await SettingsService().getAutoLockTimeout();
      if (timeout <= 0) return;
      if (elapsed < timeout) return;
      final pinEnabled = await PinService().isPinEnabled();
      if (!pinEnabled) return;
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LockScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider(DatabaseHelper())),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'دفتر حسابات',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // التطبيق عربي بالكامل: نثبّت اللغة على العربية حتى لا تُعرَض الواجهة
          // بترتيب LTR على الأجهزة غير العربية (يقلب التخطيط ويكسر اتجاه الأيقونات).
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // منع تكسُّر التخطيط عند أحجام الخط الكبيرة.
          // نضع حدًّا أعلى فقط (1.3) دون حدٍّ أدنى: تثبيت الحد الأدنى عند 1.0
          // يتعارض مع إعادة قصّ Flutter الداخلية (مثل ترويسة منتقي التاريخ) عندما
          // يكون مقياس خط الجهاز ≤ 1.0، فيفشل التأكيد maxScale > minScale.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
              ),
              child: child!,
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}



