import 'package:flutter/material.dart';
import 'app_dimens.dart';

class AppTheme {
  // الألوان الأساسية - هادئة وبسيطة
  static const Color primary = Color(0xFF1565C0);      // أزرق داكن
  static const Color primaryLight = Color(0xFF1E88E5); // أزرق فاتح
  static const Color income = Color(0xFF2E7D32);       // أخضر (مطلوب / دائن)
  static const Color expense = Color(0xFFC62828);      // أحمر (مدفوع / مدين)

  // أحجام موحّدة لعناصر التحكم
  static const double _buttonMinHeight = 48;

  // ─── أنماط المكوّنات المشتركة بين الفاتح والداكن ──────────────────────────
  static OutlinedBorder get _buttonShape =>
      RoundedRectangleBorder(borderRadius: AppRadius.mdAll);

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, _buttonMinHeight),
          shape: _buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      );

  static FilledButtonThemeData get _filledButtonTheme => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, _buttonMinHeight),
          shape: _buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      );

  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, _buttonMinHeight),
          shape: _buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
        style: TextButton.styleFrom(shape: _buttonShape),
      );

  // الافتراضي يطابق معيار Material 3 (24) حتى لا تتقلّص الأيقونات غير المحدّدة
  static const IconThemeData _iconTheme =
      IconThemeData(size: AppIconSize.lg);

  static InputDecorationTheme get _inputDecorationTheme =>
      const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: AppRadius.smAll),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      );

  // الشرائح والشارات: حواف دائرية كاملة (Material 3)
  static ChipThemeData get _chipTheme => const ChipThemeData(
        shape: StadiumBorder(),
      );

  static DialogThemeData get _dialogTheme => DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      );

  static const AppBarTheme _appBarBase = AppBarTheme(
    foregroundColor: Colors.white,
    elevation: 2,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: AppFontSize.title,
      fontWeight: FontWeight.bold,
    ),
  );

  // ─── Light Theme ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: _appBarBase.copyWith(backgroundColor: primary),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      iconTheme: _iconTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      chipTheme: _chipTheme,
      dialogTheme: _dialogTheme,
      inputDecorationTheme: _inputDecorationTheme,
    );
  }

  // ─── Dark Theme ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Roboto',
      appBarTheme: _appBarBase.copyWith(backgroundColor: Colors.grey.shade900),
      cardTheme: CardThemeData(
        elevation: 1,
        color: const Color(0xFF272727),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
      ),
      iconTheme: _iconTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      chipTheme: _chipTheme,
      dialogTheme: _dialogTheme,
      inputDecorationTheme: _inputDecorationTheme,
    );
  }
}
