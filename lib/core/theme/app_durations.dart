/// مُدد الحركات والتغذية الراجعة الموحّدة في الواجهة.
/// ملاحظة: مهلات الشبكة ومؤقّتات المنطق (timeouts، periodic timers،
/// جدولة النسخ الاحتياطي) ليست جزءاً من نظام التصميم وتبقى في طبقتها.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);   // حركات صغيرة (الشرائح)
  static const Duration medium = Duration(milliseconds: 350); // انتقالات الصفحات
  static const Duration slow = Duration(milliseconds: 900);   // الحركة الافتتاحية / إعادة التوجيه
  static const Duration splashHold =
      Duration(milliseconds: 800); // الحد الأدنى لعرض شاشة البداية

  static const Duration snackbar = Duration(seconds: 3);
  static const Duration snackbarShort = Duration(seconds: 2);
}
