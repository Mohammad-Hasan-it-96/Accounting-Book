import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';

/// مساعد موحّد لفتح الروابط الخارجية.
class UrlHelper {
  UrlHelper._();

  /// يفتح [url] في تطبيق خارجي، ويعرض [errorMessage] عند فشل الفتح.
  static Future<void> open(
    BuildContext context,
    String url, {
    String errorMessage = 'تعذر فتح الرابط',
  }) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppSnackBar.error(context, errorMessage);
      }
    }
  }
}
