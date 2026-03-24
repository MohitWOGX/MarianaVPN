import 'package:flutter/material.dart';

class AppColors {
  // ── Background — deep layered dark, not flat black ────────────────────────
  static const Color bgDeep    = Color(0xFF060810);  // darkest — behind everything
  static const Color bg        = Color(0xFF0B0F1E);  // main scaffold
  static const Color bgLayer   = Color(0xFF0F1628);  // card layer
  static const Color bgCard    = Color(0xFF141B2D);  // elevated cards
  static const Color bgCardTop = Color(0xFF1A2238);  // top-most cards

  // ── Glass ──────────────────────────────────────────────────────────────────
  static const Color glassBg     = Color(0x0FFFFFFF);
  static const Color glassBorder = Color(0x18FFFFFF);
  static const Color glassBorderStrong = Color(0x28FFFFFF);

  // ── Accent — electric cyan ─────────────────────────────────────────────────
  static const Color accent      = Color(0xFF00D4FF);
  static const Color accentSoft  = Color(0xFF00AADD);
  static const Color accentGlow  = Color(0x3000D4FF);
  static const Color accentDeep  = Color(0xFF006EFF);

  // ── States ──────────────────────────────────────────────────────────────────
  static const Color connected     = Color(0xFF00E5A0);
  static const Color connectedGlow = Color(0x3000E5A0);
  static const Color disconnected  = Color(0xFFFF4B6E);
  static const Color disconnectedGlow = Color(0x30FF4B6E);
  static const Color connecting    = Color(0xFFFFB800);
  static const Color connectingGlow = Color(0x30FFB800);

  // ── RGB ring colors ────────────────────────────────────────────────────────
  static const List<Color> rgbColors = [
    Color(0xFF00D4FF), // cyan
    Color(0xFF006EFF), // blue
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
    Color(0xFFFF4B6E), // red
    Color(0xFFFF8C00), // orange
    Color(0xFFFFD700), // yellow
    Color(0xFF00E5A0), // green
    Color(0xFF00D4FF), // back to cyan
  ];

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF7A8BAA);
  static const Color textMuted     = Color(0xFF3D4F6E);

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF006EFF)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF060810), Color(0xFF0B0F1E), Color(0xFF0D1525)],
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
  );

  // ── Mesh gradient stop colors ──────────────────────────────────────────────
  static const Color meshTeal   = Color(0x1400D4FF);
  static const Color meshBlue   = Color(0x10006EFF);
  static const Color meshPurple = Color(0x0C8B5CF6);
  static const Color meshGreen  = Color(0x0C00E5A0);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Outfit',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.connected,
      surface: AppColors.bgCard,
    ),
  );
}
