import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'core/services/crash_service.dart';
import 'core/services/backup_scheduler_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await CrashService.initialize();

      FlutterError.onError = (details) {
        CrashService.recordError(details.exception, details.stack,
            context: 'FlutterError');
      };

      runApp(const App());

      // تهيئة غير حرجة بعد الإقلاع حتى لا نؤخّر أول إطار: WorkManager يحتاج فقط
      // إلى التسجيل مرّة، والمهمة الدورية تبقى مسجّلة عبر التشغيلات.
      unawaited(_initBackgroundServices());
    },
    (error, stack) => CrashService.recordError(error, stack),
  );
}

Future<void> _initBackgroundServices() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
    // إعادة تسجيل المهمة الدورية إن كانت مفعّلة سابقاً (registerPeriodicTask
    // بوضع replace فيدمبوتنت — آمن التكرار).
    final autoBackupOn = await BackupSchedulerService.isEnabled();
    if (autoBackupOn) await BackupSchedulerService.enable();
  } catch (e, s) {
    await CrashService.recordError(e, s, context: 'initBackgroundServices');
  }
}
