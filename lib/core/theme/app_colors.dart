import 'package:flutter/widgets.dart';

/// ألوان التطبيق الموحّدة — المصدر الوحيد للألوان الثابتة.
/// أي لون يُكرَّر في الواجهة يجب أن يُعرَّف هنا بدل تكرار القيمة الحرفية.
/// (تدرّجات Material الرمادية/الحالة تبقى عبر `Colors.*` لأنها ثوابت مُسمّاة أصلاً.)
class AppColors {
  AppColors._();

  // ─── العلامة ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0);      // أزرق داكن
  static const Color primaryLight = Color(0xFF1E88E5); // أزرق فاتح

  // ─── دلالي: مطلوب (دائن) / مدفوع (مدين) ──────────────────────────────────
  static const Color income = Color(0xFF2E7D32);       // أخضر
  static const Color incomeDark = Color(0xFF1B5E20);   // أخضر داكن (أرقام الرصيد)
  static const Color expense = Color(0xFFC62828);      // أحمر
  static const Color expenseDark = Color(0xFFB71C1C);  // أحمر داكن (أرقام الرصيد)

  // ─── أسطح ────────────────────────────────────────────────────────────────
  static const Color cardDark = Color(0xFF272727);     // خلفية البطاقة في الوضع الداكن

  // ─── قنوات الدعم (ألوان علامات تجارية) ──────────────────────────────────
  static const Color whatsApp = Color(0xFF25D366);
  static const Color telegram = Color(0xFF0088CC);
}
