import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'app_snackbar.dart';

/// يعرض Dialog بتفاصيل التحديث المتاح.
/// إذا كان [info.forceUpdate] == true لا يمكن إغلاق الـ Dialog.
class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  // ─── عرض الـ Dialog من أي مكان ────────────────────────────────────────────
  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  Future<void> _openApk(BuildContext ctx) async {
    if (info.apkUrl.isEmpty) return;
    final uri = Uri.parse(info.apkUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (ctx.mounted) {
        AppSnackBar.error(ctx, 'تعذر فتح رابط التحديث');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      // منع إغلاق الـ Dialog بزر الرجوع عند force_update
      canPop: !info.forceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titlePadding: EdgeInsets.zero,
        title: _Header(primary: primary, forceUpdate: info.forceUpdate),
        content: _Content(info: info),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً'),
            ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () => _openApk(context),
            icon: const Icon(Icons.system_update_outlined, size: AppIconSize.md),
            label: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }
}

// ─── رأس الـ Dialog ───────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Color primary;
  final bool forceUpdate;
  const _Header({required this.primary, required this.forceUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: AppRadius.lgRadius),
      ),
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg, horizontal: AppSpacing.xl),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.system_update_outlined,
                color: primary, size: AppIconSize.lg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forceUpdate ? 'تحديث إلزامي!' : 'يوجد تحديث جديد',
                  style: AppTextStyles.subtitleBold,
                ),
                if (forceUpdate)
                  const Text(
                    'يجب التحديث للاستمرار في استخدام التطبيق',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── محتوى الـ Dialog ─────────────────────────────────────────────────────────
class _Content extends StatelessWidget {
  final UpdateInfo info;
  const _Content({required this.info});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.xs),
          // ─── رقم الإصدار ──────────────────────────────────────────
          _VersionRow(info: info),
          if (info.changelog.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            // ─── سجل التغييرات ────────────────────────────────────
            const Text(
              'ما الجديد:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: AppFontSize.body),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                info.changelog,
                style: const TextStyle(fontSize: AppFontSize.body, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── صف رقم الإصدار ──────────────────────────────────────────────────────────
class _VersionRow extends StatelessWidget {
  final UpdateInfo info;
  const _VersionRow({required this.info});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(Icons.new_releases_outlined, size: AppIconSize.sm, color: primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'الإصدار الجديد: ',
          style: TextStyle(fontSize: AppFontSize.body, color: Colors.grey.shade700),
        ),
        Text(
          '${info.latestVersion}+${info.latestBuild}',
          style: TextStyle(
            fontSize: AppFontSize.body,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
      ],
    );
  }
}

