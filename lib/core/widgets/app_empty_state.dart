import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// حالة فارغة موحّدة — أيقونة + عنوان + وصف قصير + زر إجراء اختياري.
/// تُستخدم عند غياب البيانات (قائمة فارغة، لا نتائج بحث، لا حركات…).
/// لا تُكرّر بناء العمود/الأيقونة/النصوص يدوياً في الشاشات.
class AppEmptyState extends StatelessWidget {
  /// الأيقونة التعبيرية أعلى الحالة (رمادية فاتحة).
  final IconData icon;

  /// العنوان الأساسي (سطر واحد عادةً).
  final String title;

  /// وصف قصير اختياري أسفل العنوان.
  final String? description;

  /// زر إجراء اختياري — يظهر فقط عند تمرير [actionLabel] و[onAction] معاً.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// أيقونة اختيارية للزر (تجعله `ElevatedButton.icon`).
  final IconData? actionIcon;

  /// حجم الأيقونة — الافتراضي [AppIconSize.empty] (64). مرّر [AppIconSize.xxl]
  /// لحالة فارغة أصغر داخل لوحة مدمجة.
  final double iconSize;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.iconSize = AppIconSize.empty,
  });

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: Colors.grey.shade300),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.grey.shade600),
              ),
            ],
            if (hasAction) ...[
              const SizedBox(height: AppSpacing.xl),
              if (actionIcon != null)
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel!),
                )
              else
                ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
