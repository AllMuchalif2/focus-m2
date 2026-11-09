import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C63FF),
        secondary: Color(0xFF03DAC6),
        surface: Color(0xFF1E1E2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF12121A),
    );
  }
}

