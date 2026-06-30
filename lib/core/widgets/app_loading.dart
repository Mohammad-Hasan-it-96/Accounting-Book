import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// مؤشّر التحميل الموحّد — المصدر الوحيد لمؤشّرات الانتظار في التطبيق.
/// لا تُنشئ `CircularProgressIndicator` يدوياً في الشاشات.
///
/// - `AppLoading()` : مؤشّر بملء المساحة المتاحة وموسَّط (لشاشة تنتظر جلب البيانات).
/// - `AppLoading.inline(...)` : مؤشّر صغير بحجم ثابت يُوضع داخل زر أو عنصر قائمة
///   (بدل الأيقونة أثناء تنفيذ العملية).
class AppLoading extends StatelessWidget {
  /// مؤشّر موسَّط بملء المساحة.
  const AppLoading({super.key})
      : _size = null,
        _strokeWidth = null,
        _color = null;

  /// مؤشّر صغير بحجم ثابت. الحجم الافتراضي [AppIconSize.md] (20).
  const AppLoading.inline({
    super.key,
    double size = AppIconSize.md,
    double strokeWidth = 2,
    Color? color,
  })  : _size = size,
        _strokeWidth = strokeWidth,
        _color = color;

  final double? _size;
  final double? _strokeWidth;
  final Color? _color;

  @override
  Widget build(BuildContext context) {
    final indicator = CircularProgressIndicator(
      strokeWidth: _strokeWidth ?? 4,
      color: _color,
    );
    if (_size == null) return Center(child: indicator);
    return SizedBox(width: _size, height: _size, child: indicator);
  }
}
