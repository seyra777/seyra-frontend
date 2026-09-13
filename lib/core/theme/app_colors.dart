import 'package:flutter/material.dart';

/// Light brand tokens stay Seyra blue.
/// Dark palette: navy `#07142E`, primary `#2F80FF`, cyan `#35D5F5`, indigo `#5865F2`.
abstract final class AppColors {
  static const Color primary = Color(0xFF4B7CF5);
  static const Color primaryDark = Color(0xFF2F62F0);
  static const Color cyan = Color(0xFF3EC6F5);
  static const Color royal = Color(0xFF5D5FEF);
  static const Color navy = Color(0xFF0F1B3D);
  static const Color blobCyan = Color(0xFF7EDDFF);
  static const Color blobBlue = Color(0xFF4C8CFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5F7FB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color fieldBorder = Color(0xFFE5E7EB);
  static const Color wave = Color(0xFFDCE8FF);
  static const Color receivedBubbleLight = Color(0xFFEEF2F8);

  static const Color darkBg = Color(0xFF07142E);
  static const Color darkSurface = Color(0xFF101F3A);
  static const Color darkAccent = Color(0xFF2F80FF);
  static const Color darkCyan = Color(0xFF35D5F5);
  static const Color darkIndigo = Color(0xFF5865F2);
  static const Color darkSecondaryText = Color(0xFFAFC0D8);
  static const Color darkInputFill = Color(0xFF101F3A);
  static const Color darkInputBorder = Color(0xFF2459A8);
  static const Color darkBlobDeep = Color(0xFF1557B8);
  static const Color darkBlobCyan = Color(0xFF35B9E8);
  static const Color darkReceivedBubble = Color(0xFF12243F);
  static const Color darkDivider = Color(0xFF1A3A66);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [cyan, royal],
  );

  static const LinearGradient darkBrandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [darkCyan, darkIndigo],
  );

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color accentOf(BuildContext context) {
    return isDark(context) ? darkAccent : primary;
  }

  static LinearGradient brandGradientOf(BuildContext context) {
    return isDark(context) ? darkBrandGradient : brandGradient;
  }

  static Color scaffoldOf(BuildContext context) {
    return isDark(context) ? darkBg : surface;
  }

  static Color cardOf(BuildContext context) {
    return isDark(context) ? darkSurface : surface;
  }

  static Color mutedOf(BuildContext context) {
    return isDark(context) ? darkSurface : surfaceMuted;
  }

  static Color textOf(BuildContext context) {
    return isDark(context) ? Colors.white : textPrimary;
  }

  static Color hintOf(BuildContext context) {
    return isDark(context) ? darkSecondaryText : textSecondary;
  }

  static Color borderOf(BuildContext context) {
    return isDark(context) ? darkDivider : fieldBorder;
  }

  static Color dangerOf(BuildContext context) {
    return isDark(context) ? const Color(0xFFFF8A80) : const Color(0xFFB91C1C);
  }

  static Color dangerFillOf(BuildContext context) {
    return isDark(context) ? const Color(0xFF2A1518) : const Color(0xFFFEF2F2);
  }

  static Color dangerBorderOf(BuildContext context) {
    return isDark(context) ? const Color(0xFF6B2C2C) : const Color(0xFFFECACA);
  }

  static Color dangerTitleOf(BuildContext context) {
    return isDark(context) ? const Color(0xFFFF8A80) : const Color(0xFF991B1B);
  }

  static Color dangerBodyOf(BuildContext context) {
    return isDark(context) ? const Color(0xFFE7B6B6) : const Color(0xFF7F1D1D);
  }

  static Color avatarFillOf(BuildContext context) {
    return isDark(context)
        ? darkAccent.withValues(alpha: 0.28)
        : wave;
  }

  static Color avatarFgOf(BuildContext context) {
    return isDark(context) ? Colors.white : primaryDark;
  }

  static Color receivedBubbleOf(BuildContext context) {
    return isDark(context) ? darkReceivedBubble : receivedBubbleLight;
  }

  static InputDecoration searchField(
    BuildContext context, {
    required String hint,
    IconData icon = Icons.search,
  }) {
    final radius = BorderRadius.circular(18);
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: mutedOf(context),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderOf(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderOf(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: accentOf(context)),
      ),
    );
  }
}

abstract final class AppAssets {
  static const seyraIcon = 'assets/branding/Logo/Icon_Design_1.png';
  static const seyraLogoLight = 'assets/branding/Logo/Logo-Version-1.webp';
  static const seyraLogoDark = 'assets/branding/Logo/Logo-Version-2.webp';
  /// Legacy path kept for older call sites; prefer [seyraLogoLight]/[seyraLogoDark].
  static const seyraLogo = seyraLogoDark;
}
