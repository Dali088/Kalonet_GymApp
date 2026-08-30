import 'package:flutter/material.dart';

abstract final class KalonetColors {
  // Figma Page 1 foundation: black, pale green, sea green, and slate.
  static const background = Color(0xFF000000);
  static const backgroundSoft = Color(0xFF020805);
  static const surfaceSunken = Color(0xFF030B06);
  static const surface = Color(0xFF06130C);
  static const surfaceElevated = Color(0xFF0A1C11);
  static const surfaceGlass = Color(0x0D3CB371);
  static const border = Color(0xFF173522);
  static const borderStrong = Color(0xFF2B6240);
  static const borderPale = Color(0x2698FB98);
  static const primary = Color(0xFF3CB371);
  static const primaryBright = Color(0xFF98FB98);
  static const primaryDeep = Color(0xFF197844);
  static const textPrimary = Color(0xFFF4FAF5);
  static const textSecondary = Color(0xFFA7B5AC);
  static const textMuted = Color(0xFF708090);
  static const error = Color(0xFFFF6B6B);
  static const errorSurface = Color(0x33FF6B6B);
  static const errorBorder = Color(0x99FF6B6B);
  static const errorText = Color(0xFFFFB3B3);

  // Semantic accents keep the existing brand palette, while making the
  // meaning of a metric explicit to every screen that renders it.
  static const nutrition = Color(0xFFF97316);
  static const hydration = Color(0xFF3B82F6);
  static const steps = Color(0xFFFFE100);
  static const activity = Color(0xFFA855F7);
  static const gamification = Color(0xFFE7C65C);
  static const warning = Color(0xFFFFC857);
  static const success = primary;
  static const scrim = Color(0xB8030604);
}
