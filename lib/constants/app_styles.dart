import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared app styles and constants for consistent UI across all pages
class AppStyles {
  // Brand Colors
  static const Color primaryNavy = Color(0xFF1A1E3F);
  static const Color primaryRed = Color(0xFFD62828);
  static const Color warmWhite = Color(0xFFF8FAFE);
  
  // Brand Name Text Style (Standard across all pages)
  static TextStyle brandNameStyle({
    double fontSize = 20,
    Color? color,
    bool isDark = false,
  }) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? (isDark ? Colors.white : primaryNavy),
      letterSpacing: -0.5,
    );
  }
  
  // Brand Name Text Style for Light Backgrounds
  static TextStyle brandNameLight({double fontSize = 20}) {
    return brandNameStyle(fontSize: fontSize, color: primaryNavy);
  }
  
  // Brand Name Text Style for Dark Backgrounds  
  static TextStyle brandNameDark({double fontSize = 20}) {
    return brandNameStyle(fontSize: fontSize, color: Colors.white);
  }
  
  // Standard Montserrat Text Styles
  static TextStyle montserratRegular({
    double fontSize = 14,
    Color color = Colors.black87,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
    );
  }
  
  static TextStyle montserratMedium({
    double fontSize = 14,
    Color color = Colors.black87,
  }) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }
  
  static TextStyle montserratBold({
    double fontSize = 14,
    Color color = Colors.black87,
  }) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }
  
  // Playfair Display for decorative headings
  static TextStyle playfairHeading({
    double fontSize = 24,
    Color color = Colors.black87,
    FontWeight weight = FontWeight.bold,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
    );
  }
}
