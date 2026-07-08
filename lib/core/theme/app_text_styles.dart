import 'package:flutter/widgets.dart';
import 'app_dimens.dart';

/// أنماط نصوص قابلة لإعادة الاستخدام مبنية على مقياس [AppFontSize].
/// الأنماط الأساسية بلا لون أو وزن إضافي — يُطبَّق ما يلزم عند الاستخدام عبر
/// `copyWith(...)`، حفاظاً على المظهر دون فرض لون موحّد على كل النصوص.
class AppTextStyles {
  AppTextStyles._();

  // ─── المقياس الأساسي (الحجم فقط) ─────────────────────────────────────────
  static const TextStyle small = TextStyle(fontSize: AppFontSize.small);
  static const TextStyle body = TextStyle(fontSize: AppFontSize.body);
  static const TextStyle bodyLarge = TextStyle(fontSize: AppFontSize.bodyLg);
  static const TextStyle subtitle = TextStyle(fontSize: AppFontSize.subtitle);

  // ─── متغيّرات عريضة شائعة ────────────────────────────────────────────────
  static const TextStyle subtitleBold =
      TextStyle(fontSize: AppFontSize.subtitle, fontWeight: FontWeight.bold);
  static const TextStyle titleBold =
      TextStyle(fontSize: AppFontSize.title, fontWeight: FontWeight.bold);
  static const TextStyle headlineBold =
      TextStyle(fontSize: AppFontSize.headline, fontWeight: FontWeight.bold);
}
