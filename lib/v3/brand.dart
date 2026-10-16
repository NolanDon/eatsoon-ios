import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// Replaced with each app's values by the version 3 source sync.
const appId = 'eatsoon';
const apiAppId = 'eatsoon';
const appName = 'EatSoon';
const appKind = 'fridge';
const appTagline = 'Your fridge, ready to use.';
const brandFont = 'Bricolage Grotesque';
const paper = Color(0xFFF0F6F2);
const ink = Color(0xFF244D38);
const accent = Color(0xFF5C8A61);
bool _licensed = false;
ThemeData v3Theme() {
  if (!_licensed) {
    _licensed = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        brandFont,
      ], await rootBundle.loadString('assets/v3/fonts/Bricolage-OFL.txt'));
    });
  }
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: brandFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ink,
      primary: ink,
      secondary: accent,
      surface: paper,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: paper,
    textTheme: base.textTheme
        .apply(fontFamily: brandFont, bodyColor: ink, displayColor: ink)
        .copyWith(
          headlineLarge: const TextStyle(
            fontFamily: brandFont,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.12,
            color: ink,
          ),
          titleLarge: const TextStyle(
            fontFamily: brandFont,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: ink,
          ),
          bodyLarge: const TextStyle(
            fontFamily: brandFont,
            fontSize: 16,
            height: 1.4,
            color: ink,
          ),
          bodyMedium: const TextStyle(
            fontFamily: brandFont,
            fontSize: 16,
            height: 1.4,
            color: ink,
          ),
          labelLarge: const TextStyle(
            fontFamily: brandFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 62),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: brandFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: brandFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: brandFont,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .65),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: brandFont,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ink.withValues(alpha: .24)),
      ),
      textStyle: const TextStyle(
        fontFamily: brandFont,
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: DividerThemeData(color: ink.withValues(alpha: .12)),
  );
}
