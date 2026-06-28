import 'package:flutter/widgets.dart';

/// نظام أبعاد موحّد (Design Tokens) لكامل التطبيق.
/// الهدف: توحيد المسافات والحواف وأحجام الأيقونات والنصوص بدل القيم المبعثرة.
/// مبني على شبكة 4 نقاط (4-pt grid).

/// المسافات (padding / margin / فواصل SizedBox)
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// نصف قطر الحواف. للعناصر الدائرية (الشرائح/الشارات) استخدم StadiumBorder.
class AppRadius {
  AppRadius._();

  static const double sm = 8;   // الحقول، البطاقات الصغيرة
  static const double md = 12;  // البطاقات والحاويات
  static const double lg = 16;  // النوافذ المنبثقة والأوراق السفلية

  static const Radius smRadius = Radius.circular(sm);
  static const Radius mdRadius = Radius.circular(md);
  static const Radius lgRadius = Radius.circular(lg);

  static const BorderRadius smAll = BorderRadius.all(smRadius);
  static const BorderRadius mdAll = BorderRadius.all(mdRadius);
  static const BorderRadius lgAll = BorderRadius.all(lgRadius);
}

/// أحجام الأيقونات
class AppIconSize {
  AppIconSize._();

  static const double sm = 16;
  static const double md = 20;  // الحجم الافتراضي
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;   // أيقونة حالة فارغة داخل بطاقة
  static const double empty = 64;  // أيقونة حالة فارغة بملء الشاشة
}

/// مقياس أحجام النصوص (Type Scale)
class AppFontSize {
  AppFontSize._();

  static const double micro = 10;    // أرقام ثانوية كثيفة
  static const double caption = 11;
  static const double small = 12;
  static const double body = 13;
  static const double bodyLg = 14;
  static const double subtitle = 16;
  static const double title = 18;
  static const double headline = 20;
  static const double display = 26;
}

/// فواصل جاهزة لتقليل تكرار SizedBox
class Gap {
  Gap._();

  static const Widget xs = SizedBox(width: AppSpacing.xs, height: AppSpacing.xs);
  static const Widget sm = SizedBox(width: AppSpacing.sm, height: AppSpacing.sm);
  static const Widget md = SizedBox(width: AppSpacing.md, height: AppSpacing.md);
  static const Widget lg = SizedBox(width: AppSpacing.lg, height: AppSpacing.lg);
  static const Widget xl = SizedBox(width: AppSpacing.xl, height: AppSpacing.xl);

  static const Widget h4 = SizedBox(height: AppSpacing.xs);
  static const Widget h8 = SizedBox(height: AppSpacing.sm);
  static const Widget h12 = SizedBox(height: AppSpacing.md);
  static const Widget h16 = SizedBox(height: AppSpacing.lg);
  static const Widget h24 = SizedBox(height: AppSpacing.xxl);
  static const Widget h32 = SizedBox(height: AppSpacing.xxxl);

  static const Widget w4 = SizedBox(width: AppSpacing.xs);
  static const Widget w8 = SizedBox(width: AppSpacing.sm);
  static const Widget w12 = SizedBox(width: AppSpacing.md);
}
