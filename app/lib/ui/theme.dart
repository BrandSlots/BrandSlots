import 'package:flutter/material.dart';

// PetStation design tokens
const _gray50  = Color(0xFFF9FAFB);
const _gray100 = Color(0xFFF3F4F6);
const _gray200 = Color(0xFFE5E7EB);
const _gray300 = Color(0xFFD1D5DB);
const _gray400 = Color(0xFF9CA3AF);
const _gray500 = Color(0xFF6B7280);
const _gray700 = Color(0xFF374151);
const _gray900 = Color(0xFF111827);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _gray900,
      brightness: Brightness.light,
    ).copyWith(
      surface: Colors.white,
      onSurface: _gray900,
    ),

    // Inter font throughout
    fontFamily: 'Inter',

    // bg-gray-50
    scaffoldBackgroundColor: _gray50,

    textTheme: const TextTheme(
      // page title: text-xl font-semibold
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _gray900, letterSpacing: -0.3),
      // panel heading: text-base font-semibold
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _gray900),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _gray900),
      // body
      bodyLarge:  TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _gray900),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _gray500),
      bodySmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _gray500),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _gray900),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _gray500, letterSpacing: 0.5),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: _gray900,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _gray900,
      ),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _gray100),
      ),
      margin: EdgeInsets.zero,
    ),

    // Primary filled button: bg-gray-900 text-white rounded-lg text-sm font-medium px-4 py-2
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _gray900,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 36),
        elevation: 0,
      ),
    ),

    // Secondary outlined button: bg-white text-gray-700 border-gray-200 rounded-lg text-sm font-medium
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _gray700,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: _gray200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 36),
        elevation: 0,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _gray500,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 36),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _gray900,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 36),
        elevation: 0,
      ),
    ),

    // Input: border-gray-200 rounded-lg text-sm
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: _gray400, fontSize: 14),
      labelStyle: const TextStyle(color: _gray500, fontSize: 14, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gray900, width: 1.5),
      ),
    ),

    iconTheme: const IconThemeData(color: _gray400, size: 16),

    dividerTheme: const DividerThemeData(
      color: _gray100,
      thickness: 1,
      space: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: _gray100,
      selectedColor: _gray900,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _gray700),
      secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _gray900,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: _gray500,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: _gray900,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _gray900,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 20);
        }
        return const IconThemeData(color: _gray400, size: 20);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _gray900);
        }
        return const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: _gray400);
      }),
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
