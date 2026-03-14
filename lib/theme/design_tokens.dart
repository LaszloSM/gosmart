import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoSmart Design Tokens — single source of truth
// ─────────────────────────────────────────────────────────────────────────────

abstract class GSColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  /// Dark navy — use as background or dark surface color only.
  static const primary = Color(0xFF1A1A2E);

  /// Teal — primary interactive / CTA color (replaces old blue for foreground use).
  static const accent = Color(0xFF00D4AA);
  static const accentHover = Color(0xFF00B894);
  static const accentLight = Color(0xFFE6FAF6);

  /// Violet — secondary accent, eco points, card gradients.
  static const accentAlt = Color(0xFF6C63FF);
  static const accentAltLight = Color(0xFFEEEDFF);

  // ── Eco ────────────────────────────────────────────────────────────────────
  static const eco = Color(0xFF3CB371);
  static const ecoLight = Color(0xFFE8F5EE);
  static const ecoDark = Color(0xFF28865A);

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const bg = Color(0xFFF5F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFFF5F6FA);
  static const border = Color(0xFFE8ECF2);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF8F9BB3);
  static const textDisabled = Color(0xFFC5CCD9);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success = Color(0xFF2ED573);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFFFA502);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFFF4757);
  static const errorLight = Color(0xFFFFF0F1);
  static const info = Color(0xFF3498DB);
  static const infoLight = Color(0xFFDBEAFE);

  // ── Transport modes ────────────────────────────────────────────────────────
  static const car = Color(0xFF00D4AA);
  static const taxi = Color(0xFFFFA502);
  static const bus = Color(0xFF6C63FF);
  static const bike = Color(0xFF3CB371);
  static const walk = Color(0xFF8F9BB3);
  static const metro = Color(0xFFFF4757);

}

abstract class GSSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

abstract class GSRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28; // updated from 24 — used for bottom sheets
  static const double full = 9999;

  static BorderRadius get cardRadius => BorderRadius.circular(xl);
  static BorderRadius get buttonRadius => BorderRadius.circular(full);
  static BorderRadius get chipRadius => BorderRadius.circular(full);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(xxl));
}

abstract class GSShadow {
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: GSColors.textPrimary.withOpacity(0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: GSColors.textPrimary.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: GSColors.textPrimary.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: GSColors.textPrimary.withOpacity(0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: GSColors.textPrimary.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// Soft floating card shadow — use for cards and sheets.
  static List<BoxShadow> get card => [
        const BoxShadow(
          color: Color(0x14000000), // black @ 8% opacity
          blurRadius: 20,
          offset: Offset(0, 4),
        ),
      ];

  /// Accent glow — use for primary CTA buttons.
  static List<BoxShadow> get accent => [
        const BoxShadow(
          color: Color(0x5900D4AA), // accent @ 35% opacity
          blurRadius: 24,
          offset: Offset(0, 4),
        ),
      ];

  /// Kept as alias for accent shadow (backward compat with button code).
  static List<BoxShadow> get primary => accent;

  static List<BoxShadow> get eco => [
        BoxShadow(
          color: GSColors.eco.withOpacity(0.22),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get neumorphic => [
        BoxShadow(
          color: GSColors.textPrimary.withOpacity(0.07),
          blurRadius: 14,
          offset: const Offset(6, 6),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.9),
          blurRadius: 10,
          offset: const Offset(-4, -4),
        ),
      ];
}

abstract class GSDuration {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const page = Duration(milliseconds: 300);
}

abstract class GSSize {
  static const double touchTarget = 44;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double bottomNav = 72;
  static const double topBar = 56;
}
