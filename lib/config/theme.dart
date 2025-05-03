import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.red,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      elevation: 0,
    ),
    textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
    colorScheme: const ColorScheme.dark().copyWith(
      primary: Colors.red,
      secondary: Colors.redAccent,
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
