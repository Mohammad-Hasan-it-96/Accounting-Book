import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';

/// مساعد موحّد لفتح الروابط الخارجية.
class UrlHelper {
  UrlHelper._();

  // مخططات مسموح بها فقط — دفاع في العمق لو مرّر مستدعٍ مستقبلي مدخلاً غير موثوق.
  static const Set<String> _allowedSchemes = {
    'https',
    'http',
    'mailto',
    'tel',
    'sms',
    'whatsapp',
    'tg',
  };

  /// يفتح [url] في تطبيق خارجي، ويعرض [errorMessage] عند فشل الفتح أو رفض المخطط.
  static Future<void> open(
    BuildContext context,
    String url, {
    String errorMessage = 'تعذر فتح الرابط',
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
      if (context.mounted) AppSnackBar.error(context, errorMessage);
      return;
    }
    bool ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      AppSnackBar.error(context, errorMessage);
    }
  }
}
