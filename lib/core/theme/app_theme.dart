import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';

class AppTheme {
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

  // شريط علوي موحّد: ارتفاع ثابت، أيقونات بيضاء بحجم موحّد،
  // حشوة عنوان ثابتة، وطباعة موحّدة عبر كل الشاشات.
  static const AppBarTheme _appBarBase = AppBarTheme(
    foregroundColor: Colors.white,
    elevation: 2,
    centerTitle: true,
    toolbarHeight: kToolbarHeight,
    titleSpacing: AppSpacing.lg,
    iconTheme: IconThemeData(color: Colors.white, size: AppIconSize.lg),
    actionsIconTheme:
        IconThemeData(color: Colors.white, size: AppIconSize.lg),
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
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: _appBarBase.copyWith(backgroundColor: AppColors.primary),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
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
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Roboto',
      appBarTheme: _appBarBase.copyWith(backgroundColor: Colors.grey.shade900),
      cardTheme: CardThemeData(
        elevation: 1,
        color: AppColors.cardDark,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
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
