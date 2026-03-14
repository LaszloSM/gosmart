import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoSmart Design Tokens — single source of truth (mirrors design-tokens.json)
// ─────────────────────────────────────────────────────────────────────────────

abstract class GSColors {
  // Brand
  static const primary = Color(0xFF2D5BFF);
  static const primaryHover = Color(0xFF1A45E8);
  static const primaryLight = Color(0xFFEEF2FF);

  static const eco = Color(0xFF3CB371);
  static const ecoLight = Color(0xFFE8F5EE);
  static const ecoDark = Color(0xFF28865A);

  // Neutral
  static const bg = Color(0xFFF5F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFEFF1F6);
  static const border = Color(0xFFE2E6F0);
  static const textPrimary = Color(0xFF0B1226);
  static const textSecondary = Color(0xFF5A6484);
  static const textDisabled = Color(0xFFA8B0C8);

  // Semantic
  static const success = Color(0xFF22C55E);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDBEAFE);

  // Transport modes
  static const car = Color(0xFF2D5BFF);
  static const taxi = Color(0xFFF59E0B);
  static const bus = Color(0xFF8B5CF6);
  static const bike = Color(0xFF3CB371);
  static const walk = Color(0xFF5A6484);
  static const metro = Color(0xFFEF4444);
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
  static const double xxl = 24;
  static const double full = 9999;

  static BorderRadius get cardRadius => BorderRadius.circular(lg);
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

  static List<BoxShadow> get primary => [
        BoxShadow(
          color: GSColors.primary.withOpacity(0.25),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

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
  static const page = Duration(milliseconds: 350);
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
