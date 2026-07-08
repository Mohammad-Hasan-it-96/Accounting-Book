import 'package:flutter/widgets.dart';

/// مُحقّقات النماذج الموحّدة (Form Validators).
/// الهدف: توحيد منطق التحقق ورسائله عبر كل النماذج بدل تكرار الدوال المبعثرة.
/// تُمرَّر الرسالة الوصفية لكل حقل، بينما يبقى منطق التحقق (تجاهل الفراغات، فحص
/// الأرقام...) موحّداً في مكان واحد.
class FormValidators {
  FormValidators._();

  // ─── رسائل افتراضية موحّدة ───────────────────────────────────────────────
  static const String requiredMsg = 'هذا الحقل مطلوب';
  static const String invalidNumberMsg = 'أدخل رقماً صحيحاً';
  static const String positiveAmountMsg = 'أدخل مبلغاً أكبر من صفر';

  /// حقل نصّي مطلوب (يتجاهل المسافات حول النص).
  static FormFieldValidator<String> required([String message = requiredMsg]) {
    return (value) =>
        (value == null || value.trim().isEmpty) ? message : null;
  }

  /// قيمة مطلوبة لقائمة منسدلة (DropdownButtonFormField).
  static FormFieldValidator<T> requiredValue<T>([String message = requiredMsg]) {
    return (value) => value == null ? message : null;
  }

  /// مبلغ رقمي مطلوب وأكبر من الصفر.
  static FormFieldValidator<String> amount({
    String requiredMessage = requiredMsg,
    String invalidMessage = invalidNumberMsg,
    String positiveMessage = positiveAmountMsg,
  }) {
    return (value) {
      if (value == null || value.trim().isEmpty) return requiredMessage;
      final amount = double.tryParse(value.trim());
      if (amount == null) return invalidMessage;
      if (amount <= 0) return positiveMessage;
      return null;
    };
  }
}
