import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF087E70);
  static const brandLight = Color(0xFF0FA391);
  static const positive = Color(0xFF1B8A5A);
  static const negative = Color(0xFFC0392B);
  static const warning = Color(0xFFE08A00);
  static const ink = Color(0xFF14232B);
  static const muted = Color(0xFF5F7280);
  static const border = Color(0xFFE5EAED);
  static const background = Color(0xFFF5F7F8);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDDE3E7)),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: Colors.white, surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder, enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.brand, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: const BorderSide(color: Color(0xFFDDE3E7)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700)),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      navigationBarTheme: NavigationBarThemeData(
        height: 68, backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand.withValues(alpha: .14),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) => TextStyle(fontSize: 11, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.brand : AppColors.muted)),
      ),
      tabBarTheme: const TabBarThemeData(labelColor: AppColors.brand, unselectedLabelColor: AppColors.muted, indicatorColor: AppColors.brand, labelStyle: TextStyle(fontWeight: FontWeight.w700)),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), side: const BorderSide(color: AppColors.border)),
    );
  }
}
