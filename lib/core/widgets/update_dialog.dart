import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

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
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط التحديث')),
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: _Header(primary: primary, forceUpdate: info.forceUpdate),
        content: _Content(info: info),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً'),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openApk(context),
            icon: const Icon(Icons.system_update_outlined, size: 18),
            label: const Text('تحديث الآن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.system_update_outlined, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forceUpdate ? 'تحديث إلزامي!' : 'يوجد تحديث جديد',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (forceUpdate)
                  const Text(
                    'يجب التحديث للاستمرار في استخدام التطبيق',
                    style: TextStyle(fontSize: 12, color: Colors.red),
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
          const SizedBox(height: 4),
          // ─── رقم الإصدار ──────────────────────────────────────────
          _VersionRow(info: info),
          if (info.changelog.isNotEmpty) ...[
            const SizedBox(height: 14),
            // ─── سجل التغييرات ────────────────────────────────────
            const Text(
              'ما الجديد:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.changelog,
                style: const TextStyle(fontSize: 13, height: 1.6),
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
        Icon(Icons.new_releases_outlined, size: 16, color: primary),
        const SizedBox(width: 6),
        Text(
          'الإصدار الجديد: ',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        Text(
          '${info.latestVersion}+${info.latestBuild}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
      ],
    );
  }
}

