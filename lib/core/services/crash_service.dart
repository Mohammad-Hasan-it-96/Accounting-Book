import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// خدمة الإبلاغ عن الأعطال.
///
/// طبقتان:
/// 1. **سجل محلّي** على الجهاز (`crash_log.txt`) — يعمل دائماً حتى في الإصدار،
///    ويبقى أثراً يمكن مشاركته للتشخيص. هذا هو السلوك الافتراضي بلا أي إعداد.
/// 2. **Sentry (إبلاغ عن بُعد)** — يُهيَّأ *فقط* عند تمرير DSN وقت البناء:
///    ```
///    flutter build appbundle --release --dart-define=SENTRY_DSN=https://...
///    ```
///    بلا DSN تبقى الطبقة الأولى فقط (لا يُرسَل أي شيء عن بُعد).
///
/// كلا المسارين (FlutterError.onError و runZonedGuarded في main.dart) يمرّان عبر
/// [recordError]، فيُرسَل العطل إلى Sentry مرّة واحدة من مكان واحد. نُهيّئ Sentry
/// بلا appRunner ونُبقي FlutterError.onError الخاص بنا (يُضبط في main بعد
/// initialize) هو المعالج الوحيد، تفادياً للالتقاط المزدوج.
class CrashService {
  static File? _logFile;
  static bool _sentryEnabled = false;

  /// DSN يُمرَّر وقت البناء عبر --dart-define (لا يُخزَّن في المستودع).
  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  /// أقصى حجم لملف السجل قبل تقليمه (256 كيلوبايت).
  static const int _maxLogBytes = 256 * 1024;

  static Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/crash_log.txt');
    } catch (_) {
      _logFile = null;
    }
    await _initSentry();
  }

  static Future<void> _initSentry() async {
    if (_dsn.isEmpty) return; // بلا DSN: إبلاغ محلّي فقط.
    try {
      await SentryFlutter.init((options) {
        options.dsn = _dsn;
        options.debug = kDebugMode;
        options.environment = kReleaseMode ? 'production' : 'development';
        // معدّل عيّنات تتبّع الأداء (0.0–1.0). اضبطه حسب الحاجة/الميزانية.
        options.tracesSampleRate = 0.2;
        // نلتقط الأخطاء يدوياً عبر recordError؛ لا نستخدم appRunner كي لا يُنشئ
        // Sentry منطقته الخاصة أو يلتقط الأخطاء مرّتين.
      });
      _sentryEnabled = true;
    } catch (_) {
      // فشل تهيئة Sentry (DSN غير صالح مثلاً) لا يجب أن يمنع إقلاع التطبيق.
      _sentryEnabled = false;
    }
  }

  static Future<void> recordError(Object exception, StackTrace? stack,
      {String? context}) async {
    if (kDebugMode) {
      debugPrint('[CrashService] $context: $exception');
      if (stack != null) debugPrint(stack.toString());
    }
    await _appendToLog(exception, stack, context);
    await _sendToSentry(exception, stack, context);
  }

  static Future<void> _sendToSentry(
      Object exception, StackTrace? stack, String? context) async {
    if (!_sentryEnabled) return;
    try {
      await Sentry.captureException(
        exception,
        stackTrace: stack,
        withScope: (scope) {
          if (context != null) scope.setTag('origin', context);
        },
      );
    } catch (_) {
      // لا نُسقط التطبيق بسبب فشل الإرسال؛ يبقى السجل المحلّي أثراً.
    }
  }

  static Future<void> _appendToLog(
      Object exception, StackTrace? stack, String? context) async {
    final file = _logFile;
    if (file == null) return;
    try {
      final buffer = StringBuffer()
        ..writeln('=== ${DateTime.now().toIso8601String()} '
            '${context ?? ''} ===')
        ..writeln(exception.toString());
      if (stack != null) buffer.writeln(stack.toString());
      buffer.writeln();
      await file.writeAsString(buffer.toString(),
          mode: FileMode.append, flush: true);
      await _trimLog(file);
    } catch (_) {
      // لا نُسقط التطبيق بسبب فشل تسجيل العطل.
    }
  }

  // يُبقي حجم الملف محدوداً بالاحتفاظ بآخر جزء منه فقط.
  static Future<void> _trimLog(File file) async {
    try {
      if (await file.length() <= _maxLogBytes) return;
      final content = await file.readAsString();
      if (content.length <= _maxLogBytes) return;
      await file.writeAsString(content.substring(content.length - _maxLogBytes));
    } catch (_) {}
  }
}
