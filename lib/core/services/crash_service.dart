import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// خدمة الإبلاغ عن الأعطال.
///
/// حالياً تكتب الأعطال في ملف محلّي على الجهاز (يعمل حتى في نسخة الإصدار)
/// ليكون هناك أثر يمكن مشاركته للتشخيص، بدل فقدان الأعطال تماماً.
///
/// لتفعيل الإبلاغ عن بُعد (موصى به قبل النشر):
/// 1. أضف `sentry_flutter: ^9.0.0` إلى pubspec.yaml
/// 2. استبدل هذا الملف بتنفيذ Sentry باستخدام DSN مشروعك
/// 3. أبقِ على تغليف runApp بـ runZonedGuarded وتسجيل FlutterError.onError
class CrashService {
  static File? _logFile;

  /// أقصى حجم لملف السجل قبل تقليمه (256 كيلوبايت).
  static const int _maxLogBytes = 256 * 1024;

  static Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/crash_log.txt');
    } catch (_) {
      _logFile = null;
    }
  }

  static Future<void> recordError(Object exception, StackTrace? stack,
      {String? context}) async {
    if (kDebugMode) {
      debugPrint('[CrashService] $context: $exception');
      if (stack != null) debugPrint(stack.toString());
    }
    await _appendToLog(exception, stack, context);
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
