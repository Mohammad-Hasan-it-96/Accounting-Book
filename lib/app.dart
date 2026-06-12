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
  DateTime? _pausedAt;

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
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final timeout = await SettingsService().getAutoLockTimeout();
      if (timeout <= 0) return;
      final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
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
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      ),
    );
  }
}



