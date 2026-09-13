import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';

abstract final class AppTheme {
  static const _radius = 18.0;

  static ThemeData get light => _build(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.primary,
          onSecondary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outlineVariant: AppColors.fieldBorder,
        ),
        scaffold: AppColors.surface,
        appBarForeground: AppColors.textPrimary,
        fill: AppColors.surfaceMuted,
        accent: AppColors.primary,
        navIndicator: AppColors.wave,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.darkAccent,
          onPrimary: Colors.white,
          secondary: AppColors.darkAccent,
          onSecondary: Colors.white,
          surface: AppColors.darkSurface,
          onSurface: Colors.white,
          onSurfaceVariant: AppColors.darkSecondaryText,
          outlineVariant: AppColors.darkDivider,
        ),
        scaffold: AppColors.darkBg,
        appBarForeground: Colors.white,
        fill: AppColors.darkSurface,
        accent: AppColors.darkAccent,
        navIndicator: Color(0x442F80FF),
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffold,
    required Color appBarForeground,
    required Color fill,
    required Color accent,
    required Color navIndicator,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: appBarForeground,
      ),
      textTheme: _textTheme(brightness),
      inputDecorationTheme: _inputDecoration(colorScheme, fill),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return brightness == Brightness.dark
              ? const Color(0xFF3A3F4B)
              : const Color(0xFFE5E7EB);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        trackOutlineWidth: WidgetStateProperty.all(0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        indicatorColor: navIndicator,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? accent
                : (brightness == Brightness.dark
                    ? AppColors.darkSecondaryText
                    : AppColors.textSecondary),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? accent
                : (brightness == Brightness.dark
                    ? AppColors.darkSecondaryText
                    : AppColors.textSecondary),
          );
        }),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: accent,
          side: BorderSide(color: accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        showDragHandle: true,
      ),
      dividerColor: colorScheme.outlineVariant,
      cardColor: colorScheme.surface,
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final primary = brightness == Brightness.light
        ? AppColors.textPrimary
        : Colors.white;
    final secondary = brightness == Brightness.light
        ? AppColors.textSecondary
        : AppColors.darkSecondaryText;

    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: secondary,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static InputDecorationTheme _inputDecoration(
    ColorScheme colorScheme,
    Color fill,
  ) {
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: color),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIconColor: colorScheme.onSurfaceVariant,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: border(colorScheme.outlineVariant),
      enabledBorder: border(colorScheme.outlineVariant),
      focusedBorder: border(colorScheme.primary),
      errorBorder: border(colorScheme.error),
      focusedErrorBorder: border(colorScheme.error),
    );
  }
}
