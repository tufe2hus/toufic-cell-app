import 'package:flutter/material.dart';

class TouficCellTheme {
  static const Color brandBlue = Color(0xFF0F5AF2);
  static const Color brandTeal = Color(0xFF0E9F9A);
  static const Color brandInk = Color(0xFF111827);
  static const Color softBackground = Color(0xFFF3F5F9);
  static const Color sideRail = Color(0xFFF9FAFB);

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: Brightness.light,
      primary: brandBlue,
      secondary: brandTeal,
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFE9EEF7),
      onSurface: brandInk,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: softBackground,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFE6EAF2)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: brandInk,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        height: 74,
        indicatorColor: brandBlue.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? brandBlue : const Color(0xFF667085),
          );
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: sideRail,
        indicatorColor: Color(0x1F0F5AF2),
        selectedIconTheme: IconThemeData(color: brandBlue),
        selectedLabelTextStyle: TextStyle(
          color: brandBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: brandBlue, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: brandInk,
        labelStyle: const TextStyle(
          color: brandInk,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB)),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandTeal,
      brightness: Brightness.dark,
      primary: const Color(0xFF7FB4FF),
      secondary: const Color(0xFF48D7CF),
      surface: const Color(0xFF101828),
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF09111F),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF101828),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFF1F2937)),
        ),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF101828),
        indicatorColor: Colors.white.withValues(alpha: 0.12),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF101828),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF7FB4FF), width: 1.4),
        ),
      ),
    );
  }
}
