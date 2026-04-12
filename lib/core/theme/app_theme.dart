import 'package:flutter/material.dart';

class AppTheme {
  // الألوان الأساسية - هادئة وبسيطة
  static const Color primary = Color(0xFF1565C0);     // أزرق داكن
  static const Color primaryLight = Color(0xFF1E88E5); // أزرق فاتح
  static const Color income = Color(0xFF2E7D32);       // أخضر (له / دائن)
  static const Color expense = Color(0xFFC62828);      // أحمر (عليه / مدين)
  static const Color neutral = Color(0xFF546E7A);      // رمادي مزرق

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      // خط واضح للعربية
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

