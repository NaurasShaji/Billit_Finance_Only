import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppColors {
  static const brand = Color(0xFF087E70);
  static const brandDeep = Color(0xFF0B5F57);
  static const brandLight = Color(0xFF0FA391);
  static const positive = Color(0xFF1B8A5A);
  static const negative = Color(0xFFC0392B);
  static const warning = Color(0xFFE08A00);
  static const brown = Color(0xFFB07A4F);
  static const indigo = Color(0xFF5C6BC0);
}

/// Theme-aware colours, so every screen works in both light and dark mode.
extension AppContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get ink => isDark ? const Color(0xFFE6EEF0) : const Color(0xFF14232B);
  Color get muted => isDark ? const Color(0xFF9DAEB8) : const Color(0xFF5F7280);
  Color get hairline =>
      isDark ? const Color(0xFF2A383B) : const Color(0xFFE5EAED);
  Color get softFill =>
      isDark ? const Color(0xFF1F2C2F) : const Color(0xFFF1F4F5);
  Color get accent => isDark ? AppColors.brandLight : AppColors.brand;
  Color get good => isDark ? const Color(0xFF4FC697) : AppColors.positive;
  Color get bad => isDark ? const Color(0xFFFF8E7F) : AppColors.negative;
  Color get caution => isDark ? const Color(0xFFFFB84D) : AppColors.warning;
}

/// Remembers the chosen appearance (system / light / dark) between launches.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();
  static const _key = 'theme_mode';
  static const _storage = FlutterSecureStorage();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final value = await _storage.read(key: _key);
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      _mode = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {}
  }
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    );
    final accent = dark ? AppColors.brandLight : AppColors.brand;
    final canvas = dark ? const Color(0xFF0E1517) : const Color(0xFFF5F7F8);
    final surface = dark ? const Color(0xFF162023) : Colors.white;
    final line = dark ? const Color(0xFF2A383B) : const Color(0xFFE5EAED);
    final fieldLine = dark ? const Color(0xFF34464A) : const Color(0xFFDDE3E7);
    final ink = dark ? const Color(0xFFE6EEF0) : const Color(0xFF14232B);
    final muted = dark ? const Color(0xFF9DAEB8) : const Color(0xFF5F7280);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: fieldLine),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: fieldLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: dark ? .25 : .14),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: dark ? .25 : .14),
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: line),
        selectedColor: accent.withValues(alpha: dark ? .28 : .16),
        checkmarkColor: accent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    );
  }
}
