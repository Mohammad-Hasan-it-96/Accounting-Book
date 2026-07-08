import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// نوافذ التأكيد الموحّدة — المصدر الوحيد لحوارات «نعم/لا».
/// لا تنشئ [AlertDialog] يدوياً للتأكيد أو الحذف؛ استخدم [AppDialog.confirm]
/// لتوحيد العناوين والنصوص والأزرار والألوان والمسافات عبر التطبيق.
class AppDialog {
  AppDialog._();

  /// نافذة تأكيد بزرّين. تُعيد `true` عند الضغط على زر التأكيد و`false` خلاف ذلك
  /// (إلغاء أو إغلاق بالنقر خارج النافذة).
  ///
  /// [destructive] يجعل زر التأكيد أحمر مع أيقونة تحذير في العنوان — للحذف
  /// والإجراءات غير القابلة للتراجع.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }
}

class _AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  const _AppConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        destructive ? AppColors.expense : Theme.of(context).colorScheme.primary;
    final headerIcon =
        icon ?? (destructive ? Icons.warning_amber_rounded : null);

    return AlertDialog(
      title: Row(
        children: [
          if (headerIcon != null) ...[
            Icon(headerIcon, color: accent, size: AppIconSize.lg),
            Gap.w12,
          ],
          // بلا style صريح كي يرث نمط عنوان الحوار من الثيم — فيتطابق مع باقي الحوارات.
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(
        message,
        style: AppTextStyles.bodyLarge.copyWith(height: 1.5),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.expense,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
