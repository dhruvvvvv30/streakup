import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for StreakUp's visual language.
/// Reused across Home, Tasks, Streak Progress, Calendar, and Auth.
class AppColors {
  static const background = Color(0xFFF7F6FF);
  static const purple = Color(0xFF6C5CE7);
  static const ink = Color(0xFF1E1C3B);
  static const sub = Color(0xFF8B8C9E);
  static const lightPurple = Color(0xFFF1EFFF);
  static const cardBorder = Color(0xFFECEFFC);
  static const white = Colors.white;
  static const error = Color(0xFFEB5757);
  static const success = Color(0xFF27AE60);
}

class AppText {
  // Big screen titles ("To-do List", "Journal", "Community")
  static TextStyle headline({double size = 32, Color? color}) => GoogleFonts.schoolbell(
    fontSize: size,
    fontWeight: FontWeight.bold,
    color: color ?? AppColors.ink,
  );

  // Section titles / card headers
  static TextStyle title({double size = 16, Color? color, FontWeight weight = FontWeight.w900}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color ?? AppColors.ink);

  // Body / labels
  static TextStyle body({double size = 14, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color ?? AppColors.sub);

  // Buttons
  static TextStyle button({double size = 15, Color? color}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: FontWeight.w800, color: color ?? Colors.white);
}

BoxDecoration appCard({double radius = 22, Color? fill}) => BoxDecoration(
  color: fill ?? AppColors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.cardBorder, width: 1.2),
);