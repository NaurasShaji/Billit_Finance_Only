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

/// Theme-aware colours shared by screens and reusable widgets.
extension AppContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get ink => isDark ? const Color(0xFFE6EEF0) : const Color(0xFF14232B);
  Color get muted => isDark ? const Color(0xFF9DAEB8) : const Color(0xFF5F7280);
  Color get hairline => isDark ? const Color(0xFF2A383B) : const Color(0xFFE5EAED);
  Color get softFill => isDark ? const Color(0xFF202D30) : const Color(0xFFF1F4F5);
  Color get accent => isDark ? const Color(0xFF42C7B2) : AppColors.brand;
  Color get good => isDark ? const Color(0xFF63D6A5) : AppColors.positive;
  Color get bad => isDark ? const Color(0xFFFF8E83) : AppColors.negative;
  Color get caution => isDark ? const Color(0xFFFFC266) : AppColors.warning;
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
    final accent = dark ? const Color(0xFF42C7B2) : AppColors.brand;
    final canvas = dark ? const Color(0xFF0B1214) : const Color(0xFFF5F7F8);
    final surface = dark ? const Color(0xFF151F22) : Colors.white;
    final elevatedSurface = dark ? const Color(0xFF1B292C) : const Color(0xFFFAFBFC);
    final line = dark ? const Color(0xFF2B3A3E) : const Color(0xFFE5EAED);
    final fieldLine = dark ? const Color(0xFF3A4D51) : const Color(0xFFDDE3E7);
    final ink = dark ? const Color(0xFFE8F0F1) : const Color(0xFF14232B);
    final muted = dark ? const Color(0xFFA3B3B9) : const Color(0xFF5F7280);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: dark ? const Color(0xFF06201C) : Colors.white,
      secondary: dark ? const Color(0xFF9ADFD4) : AppColors.brandDeep,
      onSecondary: dark ? const Color(0xFF10201D) : Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: fieldLine,
      outlineVariant: line,
      error: dark ? const Color(0xFFFF8E83) : AppColors.negative,
      onError: dark ? const Color(0xFF310B08) : Colors.white,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: fieldLine),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: surface,
      dividerColor: line,
      textTheme: Typography.material2021().black.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      primaryTextTheme: Typography.material2021().white.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      iconTheme: IconThemeData(color: muted),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: ink,
        subtitleTextStyle: TextStyle(color: muted, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: muted.withValues(alpha: .82)),
        helperStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: accent, width: 1.7),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: fieldLine),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: dark ? const Color(0xFF06201C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: muted, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevatedSurface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF29383B) : const Color(0xFF203034),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF34464A) : const Color(0xFF203034),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: dark ? .22 : .14),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? accent : muted,
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
        indicatorColor: accent.withValues(alpha: dark ? .22 : .14),
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevatedSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: line),
        selectedColor: accent.withValues(alpha: dark ? .24 : .16),
        checkmarkColor: accent,
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? accent : muted),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? accent.withValues(alpha: dark ? .16 : .10)
                  : surface),
          side: WidgetStateProperty.all(BorderSide(color: line)),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: line,
        circularTrackColor: line,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: .28),
        selectionHandleColor: accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : muted),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : Colors.transparent),
        checkColor: WidgetStateProperty.all(dark ? const Color(0xFF06201C) : Colors.white),
        side: BorderSide(color: muted),
      ),
    );
  }
}
