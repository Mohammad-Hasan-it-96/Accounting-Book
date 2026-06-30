import 'package:flutter/material.dart';
import '../helpers/form_validators.dart';
import '../theme/app_dimens.dart';

/// عناصر إدخال موحّدة للنماذج (Design Tokens للنماذج).
///
/// تضمن مظهراً وسلوكاً متّسقاً لكل الحقول: نفس التزيين (label + أيقونة)، نفس
/// علامة الحقل المطلوب (`*`)، ونفس منطق التحقق عبر [FormValidators].
/// الفاصل القياسي بين الحقول هو [Gap.h12].
///
/// حقل نصّي موحّد مبني على [TextFormField].
///
/// - [required] يضيف علامة `*` إلى التسمية، وعند غياب [validator] يفعّل تحقق
///   "حقل مطلوب" برسالة [requiredMessage].
/// - يعمل داخل `Form` أو بدونه (في الحوارات) — التحقق يبقى اختيارياً.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData? icon;
  final bool required;
  final String? requiredMessage;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.icon,
    this.required = false,
    this.requiredMessage,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValidator = validator ??
        (required
            ? FormValidators.required(requiredMessage ?? FormValidators.requiredMsg)
            : null);
    final lines = obscureText ? 1 : maxLines;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: lines,
      maxLength: maxLength,
      obscureText: obscureText,
      autofocus: autofocus,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: effectiveValidator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        // محاذاة التسمية للأعلى في الحقول متعددة الأسطر.
        alignLabelWithHint: lines > 1,
      ),
    );
  }
}

/// قائمة منسدلة موحّدة مبنية على [DropdownButtonFormField].
class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData? icon;
  final bool required;
  final String? requiredMessage;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.required = false,
    this.requiredMessage,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValidator = validator ??
        (required
            ? FormValidators.requiredValue<T>(
                requiredMessage ?? FormValidators.requiredMsg)
            : null);
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      items: items,
      onChanged: onChanged,
      validator: effectiveValidator,
    );
  }
}

/// حقل اختيار تاريخ موحّد: يظهر كحقل نموذج قابل للنقر يفتح `showDatePicker`.
class AppDateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool required;
  final DateTime? value;
  final String placeholder;
  final String Function(DateTime) format;
  final VoidCallback onTap;

  const AppDateField({
    super.key,
    required this.label,
    this.icon = Icons.calendar_today,
    this.required = false,
    required this.value,
    required this.format,
    required this.onTap,
    this.placeholder = 'اختر التاريخ',
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          hasValue ? format(value!) : placeholder,
          style: TextStyle(color: hasValue ? null : Colors.grey.shade600),
        ),
      ),
    );
  }
}
