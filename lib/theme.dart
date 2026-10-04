import 'package:flutter/material.dart';
import 'package:eatsoon/logic/expiry_logic.dart';

/// EatSoon design system. Warm paper background, ink text, and a
/// traffic-light urgency palette. Flat colors only — no gradients.
class EatSoonColors {
  static const Color paper = Color(0xFFFDFBF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF2B2D42);
  static const Color inkMuted = Color(0xFF6B6E82);
  static const Color tomato = Color(0xFFD64545);
  static const Color tomatoTint = Color(0xFFF9E4E1);
  static const Color amber = Color(0xFFE9A13B);
  static const Color amberTint = Color(0xFFFBF0DA);
  static const Color fresh = Color(0xFF4C956C);
  static const Color freshTint = Color(0xFFE2EFE6);
  static const Color divider = Color(0xFFEAE4D8);
}

/// Maps urgency to its semantic color.
Color urgencyColor(Urgency u) {
  switch (u) {
    case Urgency.expired:
    case Urgency.urgent:
      return EatSoonColors.tomato;
    case Urgency.warning:
      return EatSoonColors.amber;
    case Urgency.fresh:
      return EatSoonColors.fresh;
  }
}

/// Tint background for urgency.
Color urgencyTint(Urgency u) {
  switch (u) {
    case Urgency.expired:
    case Urgency.urgent:
      return EatSoonColors.tomatoTint;
    case Urgency.warning:
      return EatSoonColors.amberTint;
    case Urgency.fresh:
      return EatSoonColors.freshTint;
  }
}

ThemeData eatSoonTheme() {
  const ink = EatSoonColors.ink;
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: EatSoonColors.paper,
    colorScheme: const ColorScheme.light(
      primary: EatSoonColors.tomato,
      onPrimary: Colors.white,
      surface: EatSoonColors.surface,
      onSurface: ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: EatSoonColors.paper,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    textTheme: const TextTheme(
      // Large title — one per screen max.
      headlineLarge: TextStyle(
        color: ink,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      // Body.
      bodyLarge: TextStyle(color: ink, fontSize: 17, height: 1.4),
      bodyMedium: TextStyle(color: ink, fontSize: 15, height: 1.4),
      // Caption.
      labelMedium: TextStyle(color: EatSoonColors.inkMuted, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EatSoonColors.tomato,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EatSoonColors.tomato,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        minimumSize: const Size(44, 44),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EatSoonColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EatSoonColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EatSoonColors.tomato, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: EatSoonColors.divider),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: EatSoonColors.divider,
  );
}
