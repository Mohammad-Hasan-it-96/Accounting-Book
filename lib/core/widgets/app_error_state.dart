import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// حالة خطأ موحّدة — المصدر الوحيد لواجهات الأخطاء في التطبيق.
/// لا تُكرّر بناء صفّ/عمود الخطأ يدوياً في الشاشات.
///
/// - `AppErrorState(...)` : حالة خطأ بملء المساحة (موسَّطة) لقسم/شاشة فشل تحميلها،
///   مع زر «إعادة المحاولة» اختياري.
/// - `AppErrorState.inline(...)` : شريط خطأ نحيف يُوضع داخل قائمة أو أعلى صفحة
///   لا تزال تعمل (خطأ غير حاجب).
class AppErrorState extends StatelessWidget {
  /// الأيقونة التعبيرية.
  final IconData icon;

  /// النص الأساسي (الرسالة في النمط النحيف).
  final String title;

  /// رسالة وصفية اختيارية أسفل العنوان (النمط الكامل فقط).
  final String? message;

  /// زر «إعادة المحاولة» الاختياري — يظهر فقط عند تمرير [onRetry].
  final VoidCallback? onRetry;
  final String retryLabel;

  final bool _inline;

  const AppErrorState({
    super.key,
    this.icon = Icons.error_outline,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
  }) : _inline = false;

  /// شريط خطأ نحيف بمحاذاة أفقية — لخطأ غير حاجب داخل صفحة لا تزال تعمل.
  const AppErrorState.inline({
    super.key,
    required this.title,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
    this.icon = Icons.warning_amber_rounded,
  }) : message = null,
       _inline = true;

  @override
  Widget build(BuildContext context) => _inline ? _buildInline() : _buildFull();

  Widget _buildInline() {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: Colors.orange.shade700),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.small.copyWith(color: Colors.orange.shade700),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }

  Widget _buildFull() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.empty, color: Colors.red.shade300),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.grey.shade500),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
