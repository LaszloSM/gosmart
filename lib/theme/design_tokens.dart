import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoSmart Design Tokens — "Kinetic Flow" dark edition
// ─────────────────────────────────────────────────────────────────────────────

abstract class GSColors {
  // ── Base surface hierarchy (dark layering system) ──────────────────────────
  /// Deepest base — use as scaffold/page background.
  static const primary = Color(0xFF0A0E1A);

  /// Sectioning layer — separates background from cards.
  static const surfaceContainerLow = Color(0xFF0E1320);

  /// Default card surface.
  static const surface = Color(0xFF141928);

  /// Elevated card / prominent element.
  static const surfaceContainerHigh = Color(0xFF1A1F2F);

  /// Modals, sheets, overlays.
  static const surfaceContainerHighest = Color(0xFF202537);

  /// Active / highlighted states (e.g. focused input ring).
  static const surfaceBright = Color(0xFF252B3F);

  // ── Kinetic Green — primary interactive / CTA ──────────────────────────────
  static const accent = Color(0xFF5CFD80);
  static const accentHover = Color(0xFF4BEE74);

  /// Used as gradient endpoint on primary buttons.
  static const accentContainer = Color(0xFF02C953);

  /// Dark container for accent-tinted backgrounds.
  static const accentLight = Color(0xFF003711);

  // ── Cyan — secondary accent ────────────────────────────────────────────────
  static const accentAlt = Color(0xFF45FEC9);
  static const accentAltLight = Color(0xFF006C52);

  // ── Sky Blue — tertiary ────────────────────────────────────────────────────
  static const tertiary = Color(0xFF57BCFF);
  static const tertiaryLight = Color(0xFF003552);

  // ── Eco ────────────────────────────────────────────────────────────────────
  static const eco = Color(0xFF5CFD80);
  static const ecoLight = Color(0xFF003711);
  static const ecoDark = Color(0xFF4BEE74);

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const bg = Color(0xFF0A0E1A);

  /// Alias kept for legacy uses — equals surfaceContainerLow.
  static const surfaceDark = Color(0xFF0E1320);

  /// Subtle outline — replaces hard 1px borders (use at 15–40% opacity).
  static const border = Color(0xFF444756);

  static const textPrimary = Color(0xFFE2E4F6);
  static const textSecondary = Color(0xFFA7AABB);
  static const textDisabled = Color(0xFF717584);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success = Color(0xFF5CFD80);
  static const successLight = Color(0xFF003711);
  static const warning = Color(0xFFFFA502);
  static const warningLight = Color(0xFF3D2600);
  static const error = Color(0xFFFF7351);
  static const errorLight = Color(0xFF3D1500);
  static const info = Color(0xFF57BCFF);
  static const infoLight = Color(0xFF003552);

  // ── Transport modes ────────────────────────────────────────────────────────
  static const car = Color(0xFF5CFD80);    // kinetic green
  static const taxi = Color(0xFFFFA502);   // amber
  static const bus = Color(0xFF6C63FF);    // violet (kept for visual distinction)
  static const bike = Color(0xFF45FEC9);   // cyan
  static const walk = Color(0xFFA7AABB);   // muted
  static const metro = Color(0xFFFF7351);  // coral red

  // ── Card ───────────────────────────────────────────────────────────────────
  static const cardGold = Color(0xFFC9A84C);
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
  static const double xxl = 28;
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
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF5CFD80).withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 40,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF5CFD80).withValues(alpha: 0.06),
          blurRadius: 40,
          offset: const Offset(0, 0),
        ),
      ];

  /// Ambient floating card shadow — tinted with kinetic green.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 32,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF5CFD80).withValues(alpha: 0.04),
          blurRadius: 32,
          offset: const Offset(0, 0),
        ),
      ];

  /// Kinetic green glow — use for primary CTA buttons.
  static List<BoxShadow> get accent => [
        BoxShadow(
          color: const Color(0xFF5CFD80).withValues(alpha: 0.28),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ];

  /// Alias kept for backward compat.
  static List<BoxShadow> get primary => accent;

  static List<BoxShadow> get eco => [
        BoxShadow(
          color: GSColors.eco.withValues(alpha: 0.24),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get neumorphic => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.40),
          blurRadius: 14,
          offset: const Offset(6, 6),
        ),
        BoxShadow(
          color: GSColors.surfaceBright.withValues(alpha: 0.6),
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

abstract class GSGlass {
  static const double blur = 24;
  static const double backgroundOpacity = 0.88;
  static const double borderOpacity = 0.10;
  static const double borderWidth = 1.0;
}

abstract class GSGradient {
  /// Primary CTA gradient — kinetic green → cyan.
  static List<Color> get accentPill => [GSColors.accent, GSColors.accentAlt];

  /// Subtle gloss highlight for cards.
  static List<Color> get cardGloss =>
      [Colors.white.withValues(alpha: 0.05), Colors.transparent];

  /// Avatar ring gradient.
  static List<Color> get avatarRing => [GSColors.accent, GSColors.accentAlt];

  /// Primary button gradient.
  static List<Color> get primaryButton => [GSColors.accent, GSColors.accentAlt];

  /// Smart card gradient — deep navy → kinetic green.
  static List<Color> get smartCard =>
      [const Color(0xFF0A0E1A), GSColors.accent];
}

abstract class GSAnimDuration {
  static const countUp = Duration(milliseconds: 800);
  static const checkmarkStroke = Duration(milliseconds: 600);
  static const particleBurst = Duration(milliseconds: 700);
  static const int skeletonStagger = 80;
  static const pillSlide = Duration(milliseconds: 200);
}
