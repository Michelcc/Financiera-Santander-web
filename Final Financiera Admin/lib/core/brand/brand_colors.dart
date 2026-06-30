import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const red = Color(0xFFEC0000);
  static const darkRed = Color(0xFFB91C1C);
  static const ink = Color(0xFF1C1C1C);
  static const muted = Color(0xFF6B7280);
  static const surface = Color(0xFFF4F5F7);
  static const cardShadow = Color(0x1A111827);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC0000), Color(0xFFC40000)],
  );
}
