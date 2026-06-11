import 'package:flutter/foundation.dart';

/// Crash reporting service — currently a no-op stub.
///
/// To enable real crash reporting:
/// 1. Add `sentry_flutter: ^9.0.0` to pubspec.yaml dependencies
/// 2. Replace this file with a Sentry implementation using your project DSN
/// 3. Wrap runApp() in runZonedGuarded and register FlutterError.onError
class CrashService {
  static Future<void> initialize() async {}

  static Future<void> recordError(Object exception, StackTrace? stack,
      {String? context}) async {
    if (kDebugMode) {
      debugPrint('[CrashService] $context: $exception');
      if (stack != null) debugPrint(stack.toString());
    }
  }
}
