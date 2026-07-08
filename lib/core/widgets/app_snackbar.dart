import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_durations.dart';

/// رسائل التنبيه (SnackBar) الموحّدة — المصدر الوحيد لرسائل النجاح/الخطأ/التحذير.
/// لا تُنشئ `SnackBar` يدوياً في الشاشات؛ استخدم هذه الدوال لضمان توحيد
/// الألوان والمدّة والأيقونات والسلوك (floating) عبر التطبيق.
class AppSnackBar {
  AppSnackBar._();

  /// رسالة نجاح (خضراء) — لعمليات تمّت بنجاح.
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.income, Icons.check_circle_outline);

  /// رسالة خطأ (حمراء) — لفشل عملية أو حالة غير متوقّعة.
  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.expense, Icons.error_outline);

  /// رسالة تحذير (برتقالية) — لتنبيه يحتاج انتباه المستخدم دون أن يكون خطأً.
  static void warning(BuildContext context, String message) =>
      _show(context, message, AppColors.warning, Icons.warning_amber_rounded);

  /// رسالة معلوماتية (زرقاء) — لإشعار محايد لا نجاح فيه ولا خطأ ولا تحذير
  /// (مثل: "جارٍ تحميل البيانات…").
  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.primary, Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: AppIconSize.lg),
              Gap.w12,
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: AppDurations.snackbar,
        ),
      );
  }
}
