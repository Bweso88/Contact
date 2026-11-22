import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Système visuel « Harvest Field » (maquette Stitch, harvest_field/DESIGN.md).
/// Pensé pour le terrain : plein soleil, une main, contrastes forts, cibles de 48 px.
abstract final class HF {
  // Couleurs de marque
  static const terracotta = Color(0xFFC25E3E); // actions principales
  static const terracottaDark = Color(0xFF9A4023);
  static const sage = Color(0xFF4A7A68); // suivi, contacts confirmés
  static const sageDark = Color(0xFF2D5746);
  static const amber = Color(0xFFD9822B); // rappels, alertes douces
  static const charcoal = Color(0xFF1E293B); // texte

  // Surfaces
  static const canvas = Color(0xFFFAF8F5); // crème
  static const card = Color(0xFFFFFFFF);
  static const sand = Color(0xFFF3EFEA); // sections imbriquées, puces inactives
  static const linen = Color(0xFFE8E2D9); // bordures
  static const inputBorder = Color(0xFFD5CFC7);
  static const muted = Color(0xFF6B635C);

  // Lavis
  static const sageWash = Color(0xFFE8F2EC);
  static const amberWash = Color(0xFFFEF3E2);
  static const terracottaWash = Color(0xFFFAECE7);
  static const redWash = Color(0xFFFDE8E6);
  static const red = Color(0xFFBA1A1A);

  /// Polices : à placer dans assets/fonts (voir README). Sans les fichiers,
  /// Flutter retombe sur la police système, l'application fonctionne quand même.
  static const headingFont = 'PlusJakartaSans';
  static const bodyFont = 'Inter';

  static const radius = 8.0;
  static const cardRadius = 16.0;

  static const primaryGlow = [BoxShadow(color: Color(0x47C25E3E), blurRadius: 16, offset: Offset(0, 6))];
  static const modalShadow = [BoxShadow(color: Color(0x141E293B), blurRadius: 24, spreadRadius: -4, offset: Offset(0, 8))];

  static TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color color = charcoal}) =>
      TextStyle(fontFamily: headingFont, fontSize: size, fontWeight: weight, color: color, height: 1.3);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: terracotta,
      primary: terracotta,
      onPrimary: Colors.white,
      secondary: sage,
      onSecondary: Colors.white,
      tertiary: amber,
      surface: canvas,
      onSurface: charcoal,
      error: red,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: bodyFont,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontFamily: headingFont, fontSize: 24, fontWeight: FontWeight.w600, color: charcoal),
        headlineSmall: TextStyle(fontFamily: headingFont, fontSize: 20, fontWeight: FontWeight.w600, color: charcoal),
        titleLarge: TextStyle(fontFamily: headingFont, fontSize: 18, fontWeight: FontWeight.w600, color: charcoal),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: charcoal),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: charcoal),
        bodyMedium: TextStyle(fontSize: 14, height: 1.43, color: charcoal),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.44),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: charcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: headingFont, fontSize: 18, fontWeight: FontWeight.w600, color: charcoal),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(inputBorder),
        enabledBorder: border(inputBorder),
        focusedBorder: border(terracotta, 2),
        errorBorder: border(red),
        focusedErrorBorder: border(red, 2),
        hintStyle: const TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: headingFont, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: charcoal,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: linen),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: terracotta,
        side: const BorderSide(color: linen),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: charcoal),
        secondaryLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: terracottaWash,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? terracottaDark : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? terracottaDark : muted),
        ),
      ),
      dividerTheme: const DividerThemeData(color: linen, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Couleurs des pastilles de statut (« Spiritual Journey Stage Badges » de la maquette).
({Color bg, Color fg}) statusColors(ContactStatus s) => switch (s) {
  ContactStatus.nouveau || ContactStatus.aContacter => (bg: HF.sand, fg: const Color(0xFF57534E)),
  ContactStatus.contacte || ContactStatus.invite => (bg: HF.amberWash, fg: const Color(0xFFB45309)),
  ContactStatus.premiereVisite || ContactStatus.enAccompagnement => (bg: HF.sageWash, fg: const Color(0xFF234E3F)),
  ContactStatus.integre => (bg: HF.terracottaWash, fg: const Color(0xFF9C3D20)),
  ContactStatus.enPause || ContactStatus.injoignable => (bg: HF.sand, fg: HF.muted),
  ContactStatus.nePlusContacter => (bg: HF.redWash, fg: HF.red),
};
