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

      await Workmanager().initialize(callbackDispatcher);

      // Re-register periodic task if previously enabled
      final autoBackupOn = await BackupSchedulerService.isEnabled();
      if (autoBackupOn) await BackupSchedulerService.enable();

      runApp(const App());
    },
    (error, stack) => CrashService.recordError(error, stack),
  );
}
