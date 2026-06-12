import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../constants/app_constants.dart';
import '../services/settings_service.dart';
import '../../data/database/database_helper.dart';

class BackupSchedulerService {
  static const autoBackupTask = 'com.daftar.auto_backup';
  static const _keyAutoBackupEnabled = 'auto_backup_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoBackupEnabled) ?? false;
  }

  static Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, true);
    await Workmanager().registerPeriodicTask(
      autoBackupTask,
      autoBackupTask,
      frequency: const Duration(days: 1),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, false);
    await Workmanager().cancelByUniqueName(autoBackupTask);
  }
}

// Must be a top-level function — called by WorkManager in the background
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == BackupSchedulerService.autoBackupTask ||
        task == AppConstants.dbName) {
      try {
        await DatabaseHelper().autoBackup();
        await SettingsService().setLastBackupDate(DateTime.now());
      } catch (_) {}
    }
    return true;
  });
}
