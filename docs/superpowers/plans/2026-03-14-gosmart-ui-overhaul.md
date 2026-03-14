# GoSmart UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate the GoSmart Flutter prototype to professional Uber/InDrive-quality UI while preserving all existing functionality.

**Architecture:** Four phases executed in strict order — (1) Design System tokens + theme + GS* widgets, (2) file reorganization into features/, (3) screen-by-screen reconstruction using premium-ui-designer agent, (4) polish (skeleton loaders, transitions, map asset). Each phase ends with a green `flutter analyze` before proceeding.

**Tech Stack:** Flutter 3.x, Riverpod 2.x (manual), GoRouter 13, Supabase, Google Fonts (Inter), Material 3.

**Spec:** `docs/superpowers/specs/2026-03-14-gosmart-ui-overhaul-design.md`

---

## Chunk 1: Phase 1 — Design System

### Task 1: Update design_tokens.dart

**Files:**
- Modify: `lib/theme/design_tokens.dart`

> **Ordering note:** This task removes `GSColors.primaryLight`, `GSColors.primaryHover`, and `GSColors.surface2`. To avoid breaking `flutter analyze` before the widget files are updated in Tasks 3–5, backward-compat aliases are included in the new class. These are removed at the end of Task 5.

- [ ] **Step 1: Verify baseline**

```bash
flutter analyze
```
Note any existing warnings — compare after this task.

- [ ] **Step 2: Replace the full content of design_tokens.dart**

```dart
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

  // ── Migration aliases — REMOVE after Task 5 is complete ───────────────────
  static const primaryLight = accentLight;
  static const primaryHover = accentHover;
  static const surface2 = surfaceDark;
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
```

- [ ] **Step 3: Verify**

```bash
flutter analyze
```
Expected: 0 errors. The migration aliases ensure existing widget files compile unchanged.

- [ ] **Step 4: Commit**

```bash
git add lib/theme/design_tokens.dart
git commit -m "feat(theme): update design tokens — navy/teal/violet palette, GSRadius.xxl=28, GSShadow.card+accent"
```

---

### Task 2: Update app_theme.dart with Inter font + new ColorScheme

**Files:**
- Modify: `lib/theme/app_theme.dart`

- [ ] **Step 1: Replace the full content of app_theme.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32, fontWeight: FontWeight.w700,
        color: GSColors.textPrimary, height: 1.2,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: GSColors.textPrimary, height: 1.2,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w700,
        color: GSColors.textPrimary, height: 1.3,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: GSColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: GSColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w600,
        color: GSColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w600,
        color: GSColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500,
        color: GSColors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: GSColors.textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: GSColors.textPrimary, height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: GSColors.textSecondary, height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: GSColors.textDisabled, height: 1.5,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600,
        color: GSColors.textPrimary, // neutral default; buttons override this
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: GSColors.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: GSColors.textDisabled,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: GSColors.accent,
        onPrimary: Colors.white,
        primaryContainer: GSColors.accentLight,
        onPrimaryContainer: GSColors.primary,
        secondary: GSColors.accentAlt,
        onSecondary: Colors.white,
        secondaryContainer: GSColors.accentAltLight,
        onSecondaryContainer: GSColors.primary,
        tertiary: GSColors.eco,
        onTertiary: Colors.white,
        tertiaryContainer: GSColors.ecoLight,
        onTertiaryContainer: GSColors.ecoDark,
        error: GSColors.error,
        onError: Colors.white,
        errorContainer: GSColors.errorLight,
        onErrorContainer: GSColors.error,
        surface: GSColors.surface,
        onSurface: GSColors.textPrimary,
        surfaceContainerHighest: GSColors.surfaceDark,
        onSurfaceVariant: GSColors.textSecondary,
        outline: GSColors.border,
        outlineVariant: GSColors.border,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: GSColors.primary,
        onInverseSurface: Colors.white,
        inversePrimary: GSColors.accentLight,
      ),
      scaffoldBackgroundColor: GSColors.bg,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: GSColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: GSColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: GSColors.textPrimary, size: 24),
      ),

      // Card
      cardTheme: CardTheme(
        color: GSColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GSColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: const BorderSide(color: GSColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: const BorderSide(color: GSColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: const BorderSide(color: GSColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: const BorderSide(color: GSColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4, vertical: GSSpacing.s4,
        ),
        hintStyle: GoogleFonts.inter(color: GSColors.textDisabled, fontSize: 15),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GSColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GSColors.accent,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: GSColors.accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GSColors.accent,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: GSColors.surface,
        selectedItemColor: GSColors.accent,
        unselectedItemColor: GSColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: GSColors.surfaceDark,
        selectedColor: GSColors.accentLight,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: GSColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.full),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s3, vertical: GSSpacing.s1,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: GSColors.border, thickness: 1, space: 0,
      ),

      // Switch — use WidgetStateProperty (Flutter 3.19+)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return GSColors.accent;
          return GSColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return GSColors.accentLight;
          return GSColors.border;
        }),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/theme/app_theme.dart
git commit -m "feat(theme): apply Inter font via GoogleFonts + Material 3 ColorScheme with accent/navy palette"
```

---

### Task 3: Update gs_button.dart — AnimatedScale + accent colors

**Files:**
- Modify: `lib/widgets/gs_button.dart`

- [ ] **Step 1: Replace full file content**

```dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum GSButtonVariant { primary, secondary, outline, ghost, eco, danger }
enum GSButtonSize { sm, md, lg }

/// GoSmart reusable button with AnimatedScale press feedback.
class GSButton extends StatefulWidget {
  const GSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GSButtonVariant.primary,
    this.size = GSButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final GSButtonVariant variant;
  final GSButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final String? semanticLabel;

  @override
  State<GSButton> createState() => _GSButtonState();
}

class _GSButtonState extends State<GSButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final colors = _variantColors;
    final dims = _sizeDims;
    final isDisabled = widget.isLoading || widget.onPressed == null;

    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      button: true,
      child: AnimatedScale(
        scale: (_pressed && !isDisabled) ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeIn,
        child: GestureDetector(
          onTapDown: isDisabled ? null : _onTapDown,
          onTapUp: isDisabled ? null : _onTapUp,
          onTapCancel: isDisabled ? null : _onTapCancel,
          onTap: isDisabled ? null : widget.onPressed,
          child: SizedBox(
            width: widget.isFullWidth ? double.infinity : null,
            height: dims.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GSRadius.full),
                boxShadow: isDisabled
                    ? []
                    : widget.variant == GSButtonVariant.primary
                        ? GSShadow.accent
                        : widget.variant == GSButtonVariant.eco
                            ? GSShadow.eco
                            : [],
              ),
              child: Container(
                height: dims.height,
                padding: EdgeInsets.symmetric(horizontal: dims.hPad),
                decoration: BoxDecoration(
                  color: isDisabled ? GSColors.textDisabled : colors.bg,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                  border: widget.variant == GSButtonVariant.outline
                      ? Border.all(color: GSColors.accent, width: 1.5)
                      : widget.variant == GSButtonVariant.danger
                          ? Border.all(color: GSColors.error, width: 1.5)
                          : null,
                ),
                child: _buildChild(dims, colors, isDisabled),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(_SizeDims dims, _VariantColors colors, bool isDisabled) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: dims.iconSize,
          height: dims.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDisabled ? Colors.white : colors.fg,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leadingIcon != null) ...[
          Icon(widget.leadingIcon, size: dims.iconSize,
              color: isDisabled ? Colors.white : colors.fg),
          SizedBox(width: GSSpacing.s2),
        ],
        Text(
          widget.label,
          style: TextStyle(
            fontSize: dims.fontSize,
            fontWeight: FontWeight.w600,
            color: isDisabled ? Colors.white : colors.fg,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          SizedBox(width: GSSpacing.s2),
          Icon(widget.trailingIcon, size: dims.iconSize,
              color: isDisabled ? Colors.white : colors.fg),
        ],
      ],
    );
  }

  _VariantColors get _variantColors {
    switch (widget.variant) {
      case GSButtonVariant.primary:
        return _VariantColors(GSColors.accent, Colors.white);
      case GSButtonVariant.secondary:
        return _VariantColors(GSColors.accentLight, GSColors.accent);
      case GSButtonVariant.outline:
        return _VariantColors(Colors.transparent, GSColors.accent);
      case GSButtonVariant.ghost:
        return _VariantColors(Colors.transparent, GSColors.textSecondary);
      case GSButtonVariant.eco:
        return _VariantColors(GSColors.eco, Colors.white);
      case GSButtonVariant.danger:
        return _VariantColors(Colors.transparent, GSColors.error);
    }
  }

  _SizeDims get _sizeDims {
    switch (widget.size) {
      case GSButtonSize.sm:
        return _SizeDims(height: 36, hPad: 16, fontSize: 13, iconSize: 16);
      case GSButtonSize.md:
        return _SizeDims(height: 52, hPad: 24, fontSize: 15, iconSize: 20);
      case GSButtonSize.lg:
        return _SizeDims(height: 60, hPad: 32, fontSize: 17, iconSize: 22);
    }
  }
}

class _VariantColors {
  final Color bg;
  final Color fg;
  const _VariantColors(this.bg, this.fg);
}

class _SizeDims {
  final double height;
  final double hPad;
  final double fontSize;
  final double iconSize;
  const _SizeDims({
    required this.height,
    required this.hPad,
    required this.fontSize,
    required this.iconSize,
  });
}

// ─── Icon-only circular button ───────────────────────────────────────────────

class GSIconButton extends StatelessWidget {
  const GSIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = GSColors.surface,
    this.iconColor = GSColors.textPrimary,
    this.size = 44,
    this.tooltip,
    this.hasShadow = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final String? tooltip;
  final bool hasShadow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(GSRadius.full),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: hasShadow ? GSShadow.card : [],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/gs_button.dart
git commit -m "feat(widgets): GSButton — AnimatedScale press, accent CTA color, no ElevatedButton dependency"
```

---

### Task 4: Update gs_bottom_nav.dart — pill-style redesign

**Files:**
- Modify: `lib/widgets/gs_bottom_nav.dart`

- [ ] **Step 1: Replace full file content**

```dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Pill-style bottom navigation bar.
/// Active tab: icon + label inside an accent-tinted pill.
/// Inactive tabs: icon only, muted color.
class GSBottomNav extends StatelessWidget {
  const GSBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.route_rounded, label: 'Viajes'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Billetera'),
    _NavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: GSSize.bottomNav + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: GSColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(
            _items.length,
            (index) => Expanded(
              child: _NavTile(
                item: _items[index],
                isActive: currentIndex == index,
                onTap: () => onTap(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: GSDuration.normal,
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? GSSpacing.s3 : GSSpacing.s2,
              vertical: GSSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: isActive ? GSColors.accentLight : Colors.transparent,
              borderRadius: BorderRadius.circular(GSRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: GSSize.iconLg,
                  color: isActive ? GSColors.accent : GSColors.textDisabled,
                ),
                if (isActive) ...[
                  const SizedBox(width: GSSpacing.s1),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GSColors.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/gs_bottom_nav.dart
git commit -m "feat(widgets): redesign GSBottomNav with pill-style active indicator"
```

---

### Task 5: Update gs_card.dart, gs_text_field.dart, gs_bottom_sheet.dart

**Files:**
- Modify: `lib/widgets/gs_card.dart`
- Modify: `lib/widgets/gs_text_field.dart`
- Modify: `lib/widgets/gs_bottom_sheet.dart`

#### 5a — Replace gs_card.dart

- [ ] **Step 1: Replace full content of gs_card.dart**

```dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Base card with soft floating shadow and configurable padding/radius.
class GSCard extends StatelessWidget {
  const GSCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.color = GSColors.surface,
    this.shadow,
    this.border,
    this.onTap,
    this.clip = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final Color color;
  final List<BoxShadow>? shadow;
  final Border? border;
  final VoidCallback? onTap;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? GSRadius.xl; // default 20px
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        boxShadow: shadow ?? GSShadow.card,
        border: border,
      ),
      clipBehavior: clip,
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

// ─── Transport mode chip ──────────────────────────────────────────────────────

class GSModeChip extends StatelessWidget {
  const GSModeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GSDuration.normal,
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4,
          vertical: GSSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : GSColors.surfaceDark,
          borderRadius: BorderRadius.circular(GSRadius.full),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: GSSize.iconLg,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : GSColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Balance / info card ──────────────────────────────────────────────────────

class GSInfoCard extends StatelessWidget {
  const GSInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBgColor,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconBgColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      onTap: onTap,
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(GSRadius.md),
            ),
            child: Icon(icon, color: iconBgColor, size: GSSize.iconLg),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GSColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: GSColors.textPrimary,
                    )),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GSColors.textDisabled,
                      )),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Driver / Option card (route detail) ─────────────────────────────────────

class GSOptionCard extends StatelessWidget {
  const GSOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.imageUrl,
    required this.avatarUrl,
    required this.rating,
    this.onBook,
    this.isSelected = false,
  });

  final String title;
  final String subtitle;
  final String price;
  final String imageUrl;
  final String avatarUrl;
  final String rating;
  final VoidCallback? onBook;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      shadow: isSelected ? GSShadow.accent : GSShadow.card,
      border: isSelected
          ? Border.all(color: GSColors.accent, width: 2)
          : Border.all(color: GSColors.border, width: 1),
      padding: const EdgeInsets.all(GSSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(avatarUrl),
                backgroundColor: GSColors.surfaceDark,
              ),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: GSColors.textPrimary,
                        )),
                    Text(rating,
                        style: const TextStyle(
                          fontSize: 12,
                          color: GSColors.textSecondary,
                        )),
                  ],
                ),
              ),
              Text(price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: GSColors.accent,
                  )),
            ],
          ),
          const SizedBox(height: GSSpacing.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(GSRadius.md),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: GSColors.surfaceDark,
                child: const Icon(Icons.directions_car,
                    size: 48, color: GSColors.textDisabled),
              ),
            ),
          ),
          const SizedBox(height: GSSpacing.s3),
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 14, color: GSColors.textSecondary),
              const SizedBox(width: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: GSColors.textSecondary)),
              const Spacer(),
              if (onBook != null)
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GSRadius.full),
                    ),
                  ),
                  child: const Text('Reservar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

#### 5b — Replace gs_text_field.dart

- [ ] **Step 2: Replace full content of gs_text_field.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';

class GSTextField extends StatelessWidget {
  const GSTextField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.semanticLabel,
  });

  final String hint;
  final String? label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label ?? hint,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        maxLines: maxLines,
        enabled: enabled,
        autofocus: autofocus,
        textCapitalization: textCapitalization,
        style: const TextStyle(
          fontSize: 15,
          color: GSColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          labelText: label,
          counterText: '',
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: GSColors.textSecondary)
              : null,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class GSSearchBar extends StatelessWidget {
  const GSSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: readOnly ? onTap : null,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.full),
          boxShadow: GSShadow.card,
          border: Border.all(color: GSColors.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 22, color: GSColors.accent),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: readOnly
                  ? Text(hint,
                      style: const TextStyle(
                          color: GSColors.textDisabled, fontSize: 15))
                  : TextField(
                      controller: controller,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(
                          fontSize: 15, color: GSColors.textPrimary),
                    ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
```

#### 5c — Update gs_bottom_sheet.dart

- [ ] **Step 3: Update drag handle color and confirm xxl radius in gs_bottom_sheet.dart**

In `lib/widgets/gs_bottom_sheet.dart`, change the drag handle color from `GSColors.border` to `GSColors.accent.withOpacity(0.4)`:

```dart
// OLD
color: GSColors.border,

// NEW
color: GSColors.accent.withOpacity(0.4),
```

The `GSRadius.sheetRadius` already references `GSRadius.xxl` which is now 28px — no other change needed in this file.

#### 5d — Remove migration aliases from design_tokens.dart

- [ ] **Step 4: Remove the 3 migration aliases from GSColors in design_tokens.dart**

Delete these 4 lines at the bottom of `GSColors`:
```dart
// ── Migration aliases — REMOVE after Task 5 is complete ───────────────────
static const primaryLight = accentLight;
static const primaryHover = accentHover;
static const surface2 = surfaceDark;
```

- [ ] **Step 5: Verify — must be 0 errors after alias removal**

```bash
flutter analyze
```
Expected: 0 errors. If any file still references `primaryLight`, `primaryHover`, or `surface2`, the analyzer will report it — fix those references before proceeding.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/gs_card.dart lib/widgets/gs_text_field.dart lib/widgets/gs_bottom_sheet.dart lib/theme/design_tokens.dart
git commit -m "feat(widgets): update GSCard, GSTextField, GSSearchBar, GSBottomSheet with new design tokens; remove migration aliases"
```

---

### Task 6: Create skeleton loader, empty state, and error card widgets

**Files:**
- Create: `lib/widgets/gs_skeleton_loader.dart`
- Create: `lib/widgets/gs_empty_state.dart`

- [ ] **Step 1: Create gs_skeleton_loader.dart**

```dart
// lib/widgets/gs_skeleton_loader.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Animated shimmer skeleton for loading states.
class GSSkeletonLoader extends StatefulWidget {
  const GSSkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<GSSkeletonLoader> createState() => _GSSkeletonLoaderState();
}

class _GSSkeletonLoaderState extends State<GSSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: const [
                Color(0xFFE8ECF2),
                Color(0xFFF5F6FA),
                Color(0xFFE8ECF2),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for a transaction list item row.
class GSTransactionSkeleton extends StatelessWidget {
  const GSTransactionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GSSpacing.s4,
        vertical: GSSpacing.s3,
      ),
      child: Row(
        children: [
          const GSSkeletonLoader(width: 44, height: 44, radius: 22),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                GSSkeletonLoader(width: double.infinity, height: 14, radius: 4),
                SizedBox(height: GSSpacing.s2),
                GSSkeletonLoader(width: 100, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s3),
          const GSSkeletonLoader(width: 60, height: 14, radius: 4),
        ],
      ),
    );
  }
}

/// Skeleton for a full card shape (e.g., wallet physical card).
class GSCardSkeleton extends StatelessWidget {
  const GSCardSkeleton({super.key, this.height = 180});
  final double height;

  @override
  Widget build(BuildContext context) {
    return GSSkeletonLoader(
      width: double.infinity,
      height: height,
      radius: GSRadius.xl,
    );
  }
}
```

- [ ] **Step 2: Create gs_empty_state.dart**

```dart
// lib/widgets/gs_empty_state.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'gs_button.dart';

/// Reusable empty state with icon, message, and optional CTA.
class GSEmptyState extends StatelessWidget {
  const GSEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: GSColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: GSColors.accent),
            ),
            const SizedBox(height: GSSpacing.s4),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: GSSpacing.s2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: GSSpacing.s6),
              GSButton(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable error card with retry button.
class GSErrorCard extends StatelessWidget {
  const GSErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: GSColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 36, color: GSColors.error),
            ),
            const SizedBox(height: GSSpacing.s4),
            Text(
              'Algo salió mal',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GSSpacing.s2),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GSSpacing.s6),
            GSButton(
              label: 'Reintentar',
              onPressed: onRetry,
              isFullWidth: false,
              leadingIcon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/gs_skeleton_loader.dart lib/widgets/gs_empty_state.dart
git commit -m "feat(widgets): add GSSkeletonLoader, GSTransactionSkeleton, GSCardSkeleton, GSEmptyState, GSErrorCard"
```

---

## Chunk 2: Phase 2 — Architecture Reorganization

### Task 7: Move all screens to lib/features/

**Files:**
- Create: `lib/features/` directory tree
- Move: 13 screen files
- Modify: `lib/router/app_router.dart`

> **CRITICAL:** Complete ALL steps of this task before running `flutter analyze`. Do not do partial moves — the app only compiles after all moves + router update are done atomically.

- [ ] **Step 1: Create all feature subdirectories (one per line, safe on Windows bash)**

```bash
mkdir -p "lib/features/auth"
mkdir -p "lib/features/home"
mkdir -p "lib/features/wallet"
mkdir -p "lib/features/history"
mkdir -p "lib/features/profile"
mkdir -p "lib/features/routes"
mkdir -p "lib/features/ai_chat"
mkdir -p "lib/features/payment"
mkdir -p "lib/features/nfc_simulator"
```

- [ ] **Step 2: Move each screen file**

```bash
mv "lib/screens/onboarding/onboarding_screen.dart" "lib/features/auth/onboarding_screen.dart"
mv "lib/screens/onboarding/login_screen.dart" "lib/features/auth/login_screen.dart"
mv "lib/screens/onboarding/register_screen.dart" "lib/features/auth/register_screen.dart"
mv "lib/screens/onboarding/sms_verify_screen.dart" "lib/features/auth/sms_verify_screen.dart"
mv "lib/screens/home/home_screen.dart" "lib/features/home/home_screen.dart"
mv "lib/screens/wallet/wallet_screen.dart" "lib/features/wallet/wallet_screen.dart"
mv "lib/screens/history/history_screen.dart" "lib/features/history/history_screen.dart"
mv "lib/screens/profile/profile_screen.dart" "lib/features/profile/profile_screen.dart"
mv "lib/screens/route_planner/route_planner_screen.dart" "lib/features/routes/route_planner_screen.dart"
mv "lib/screens/route_detail/route_detail_screen.dart" "lib/features/routes/route_detail_screen.dart"
mv "lib/screens/ai_chat/ai_chat_screen.dart" "lib/features/ai_chat/ai_chat_screen.dart"
mv "lib/screens/payment_validation/payment_validation_screen.dart" "lib/features/payment/payment_validation_screen.dart"
mv "lib/screens/nfc_simulator/nfc_auth_simulator_screen.dart" "lib/features/nfc_simulator/nfc_auth_simulator_screen.dart"
```

- [ ] **Step 3: Update app_router.dart imports**

In `lib/router/app_router.dart`, replace the 13 import lines:

```dart
// Remove these lines:
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/login_screen.dart';
import '../screens/onboarding/register_screen.dart';
import '../screens/onboarding/sms_verify_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/route_planner/route_planner_screen.dart';
import '../screens/route_detail/route_detail_screen.dart';
import '../screens/ai_chat/ai_chat_screen.dart';
import '../screens/payment_validation/payment_validation_screen.dart';
import '../screens/nfc_simulator/nfc_auth_simulator_screen.dart';

// Replace with:
import '../features/auth/onboarding_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/sms_verify_screen.dart';
import '../features/home/home_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/history/history_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/routes/route_planner_screen.dart';
import '../features/routes/route_detail_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/payment/payment_validation_screen.dart';
import '../features/nfc_simulator/nfc_auth_simulator_screen.dart';
```

- [ ] **Step 4: Check imports inside moved screen files**

The old screen files were at `lib/screens/<domain>/<file>.dart` (2 dirs from lib root). The new location is `lib/features/<domain>/<file>.dart` (same depth). So relative imports like `../../widgets/`, `../../providers/`, `../../theme/`, `../../core/`, `../../services/` remain valid — no changes needed.

However, check for any cross-screen imports (one screen importing another). Run:

```bash
grep -r "screens/" lib/features/
```

If any results appear, update those import paths from `../../screens/...` to `../../features/...` or use the correct relative path.

- [ ] **Step 5: Verify lib/screens/ is fully empty before deleting**

```bash
find lib/screens/ -name "*.dart" 2>/dev/null
```

Expected output: empty (no files listed). If any `.dart` files appear, they were missed in Step 2 — move them before proceeding.

- [ ] **Step 6: Delete lib/screens/ directory**

```bash
rm -rf lib/screens/
```

- [ ] **Step 7: Verify build is green**

```bash
flutter analyze
```
Expected: 0 errors. **Do not proceed to Chunk 3 until this passes.**

- [ ] **Step 8: Commit (list specific changed files)**

```bash
git add lib/features/ lib/router/app_router.dart
git rm -r lib/screens/
git commit -m "refactor: move screens from lib/screens/ to lib/features/ — feature-based architecture"
```

---

## Chunk 3: Phase 3 — Screen Reconstruction (Home + Wallet)

> Each screen task uses the `premium-ui-designer` agent. Provide the exact prompt from each task step. After agent delivers code, paste it into the file, run `flutter analyze`, fix any errors, then commit.

### Task 8: Rebuild Home Screen

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Add: `assets/images/map_placeholder.png`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Download map asset**

**Option A — PowerShell:**
```powershell
Invoke-WebRequest -Uri "https://tile.openstreetmap.org/13/2048/2730.png" -OutFile "assets/images/map_placeholder.png"
```

**Option B — manual:** Open `https://tile.openstreetmap.org/13/2048/2730.png` in browser, save as `assets/images/map_placeholder.png`.

**Option C — placeholder:** Place any 800×600px city map PNG at `assets/images/map_placeholder.png`.

- [ ] **Step 2: Register assets in pubspec.yaml**

In `pubspec.yaml`, ensure the assets section includes:
```yaml
flutter:
  assets:
    - assets/images/map_placeholder.png
    - assets/images/onboarding_illustration.png
```

If the assets section doesn't exist, add it under `flutter:`.

- [ ] **Step 3: Invoke premium-ui-designer agent**

Prompt:
> "Rebuild `lib/features/home/home_screen.dart` for the GoSmart Flutter mobility app. Must be a `ConsumerStatefulWidget`. Imports: tokens from `../../theme/design_tokens.dart`, widgets from `../../widgets/` (GSBottomNav, GSSearchBar, GSModeChip, GSInfoCard, GSSkeletonLoader, GSErrorCard, GSEmptyState), providers from `../../providers/`, router from `../../router/app_router.dart`.
>
> Design — professional Uber-style, navy (#1A1A2E) + teal (#00D4AA):
>
> Layout: Stack with 3 layers:
> 1. Full-screen map: `Image.asset('assets/images/map_placeholder.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity)` + `Container` with `LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF1A1A2E)], stops: [0.4, 1.0])` overlay.
> 2. Top bar (Positioned, top: 0): SafeArea child, semi-transparent white card (Color(0xEEFFFFFF), borderRadius 16px, margin 16px horizontal + top), contains: Row with [CircleAvatar(radius:18, backgroundColor: GSColors.accentLight, child: Icon person accent) + 8px gap + Column('Hola 👋' bodySmall textSecondary, name from profileProvider.when(data: (p)=>p.name, loading: ()=>'...', error:(_,__)=>'Usuario') headlineSmall bold)] + Spacer + IconButton(Icons.notifications_rounded, color textSecondary, badge red dot if needed).
> 3. DraggableScrollableSheet(minChildSize:0.12, maxChildSize:0.90, initialChildSize:0.48, snap:true): white container with BorderRadius.vertical(top: Radius.circular(28)), boxShadow GSShadow.lg:
>    - Drag handle: centered Container(width:40, height:4, color: GSColors.accent.withOpacity(0.4), radius full), padding top 12px
>    - 16px gap
>    - GSSearchBar(hint:'¿A dónde vas?', readOnly:true, onTap: ()=>context.push(AppRoutes.routePlanner))
>    - 16px gap
>    - Section: 'Modo de viaje' label (labelSmall textSecondary) + 8px + SingleChildScrollView horizontal with 5 GSModeChip (Car icon:directions_car color:GSColors.car, Taxi icon:local_taxi color:GSColors.taxi, Bus icon:directions_bus color:GSColors.bus, Bike icon:pedal_bike color:GSColors.bike, Metro icon:subway color:GSColors.metro)
>    - 16px gap
>    - Row of 2 Expanded GSInfoCard: first shows balance from activeCardProvider (icon: account_balance_wallet_rounded, iconBgColor: GSColors.accent, title:'Saldo', value: formatted COP or skeleton), second shows eco points from profileProvider (icon: eco_rounded, iconBgColor: GSColors.eco, title:'Eco Points', value: '${p.ecoPoints} pts')
>    - 16px gap
>    - 'Viajes recientes' Row with title (titleMedium bold) + TextButton 'Ver todos' → context.push(AppRoutes.history)
>    - transactionListProvider.when: loading→Column(3x GSTransactionSkeleton), error→Text('Error al cargar', style bodyMedium textSecondary, center), data→ if empty: Padding(8px, Text('Sin viajes recientes', style bodyMedium textSecondary, center)) else Column(last 3 items as ListTile with leading CircleAvatar(backgroundColor: modeColor.withOpacity(0.15), child: Icon(modeIcon, color: modeColor, size:18)), title: Text(description, bodyMedium), trailing: Text(amount COP, titleSmall bold)))
>    - 16px gap
>    - AI chat promo card: Container(decoration: BoxDecoration(gradient: LinearGradient([GSColors.accent, GSColors.accentAlt], begin:topLeft, end:bottomRight), borderRadius:20px), padding:16px, child: Row[Column(Text('IA Asistente', labelSmall white70), Text('Planifica con IA', titleMedium white bold)) + Spacer + ElevatedButton('Chatear', style:white bg accent fg, onPressed: context.push(AppRoutes.aiChat))])
>    - 24px bottom padding
> 4. Bottom: Positioned bottom:0 left:0 right:0: GSBottomNav(currentIndex:0, onTap: switch(i){0:context.go(AppRoutes.home), 1:context.go(AppRoutes.history), 2:context.go(AppRoutes.wallet), 3:context.go(AppRoutes.profile)})
>
> Navigation handler for bottom nav in a method `_onNavTap(int index)` using context.go for all tabs."

- [ ] **Step 4: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_screen.dart assets/images/map_placeholder.png pubspec.yaml
git commit -m "feat(home): rebuild home screen — static map, draggable sheet, viajes recientes, AI promo"
```

---

### Task 9: Rebuild Wallet Screen

**Files:**
- Modify: `lib/features/wallet/wallet_screen.dart`

- [ ] **Step 1: Invoke premium-ui-designer agent**

Prompt:
> "Rebuild `lib/features/wallet/wallet_screen.dart` for GoSmart Flutter app. ConsumerStatefulWidget. Tokens: `../../theme/design_tokens.dart`. Widgets: `../../widgets/`. Providers: `../../providers/card_provider.dart`, `../../providers/transaction_provider.dart`.
>
> Design — dark navy (#1A1A2E) + teal (#00D4AA) + violet (#6C63FF):
>
> Scaffold(backgroundColor: GSColors.bg):
> - AppBar: title 'Mi Billetera' (Inter SemiBold), white background, no elevation, no back button (it's a tab root screen)
> - Body SingleChildScrollView, padding 16px horizontal:
>
> Section 1 — Physical card:
> activeCardProvider.when:
>   loading: GSCardSkeleton(height:200)
>   error: GSErrorCard(message:'No se pudo cargar la tarjeta', onRetry: ref.refresh(activeCardProvider))
>   data: Container(
>     width: double.infinity, aspectRatio: 1.65,
>     decoration: BoxDecoration(
>       gradient: LinearGradient(colors:[Color(0xFF1A1A2E), Color(0xFF6C63FF)], begin: topLeft, end: bottomRight),
>       borderRadius: BorderRadius.circular(20),
>       boxShadow: [BoxShadow(color: Color(0x406C63FF), blurRadius:32, offset:Offset(0,16))]
>     ),
>     padding: EdgeInsets.all(24),
>     child: Column(crossAxisAlignment:start, mainAxisAlignment:spaceBetween, children:[
>       Row[ Icon(Icons.credit_card_rounded, color:Color(0xFFFFD700), size:32) + Spacer + Text('GoSmart', style:white bold 18px Inter) ],
>       Text('•••• •••• •••• ${card.number?.substring(card.number!.length-4)??"0000"}', style:white 16px letterSpacing:3 ),
>       Row[ Column(crossAxisAlignment:start [Text('Saldo disponible', style:white70 11px), Text(formatCOP(card.balance), style:white bold 26px)]) + Spacer + Container(padding:EdgeInsets.symmetric(h:10,v:5), decoration:BoxDecoration(color: card.isLocked?GSColors.error:GSColors.success, borderRadius:full), child:Text(card.isLocked?'Bloqueada':'Activa', style:white 11px bold)) ]
>     ])
>   )
>
> Section 2 — Quick actions row (16px top margin):
> Row of 3 Expanded tappable cards (GSCard, onTap, padding 12px, shadow GSShadow.card):
>   - Recargar: Icon(add_circle_rounded, GSColors.accent, size:28) + Text('Recargar', bodySmall center)
>   - Pagar: Icon(qr_code_scanner_rounded, GSColors.accentAlt, size:28) + Text('Pagar', bodySmall center)
>   - Bloquear: Icon(card.isLocked?lock_open_rounded:lock_rounded, card.isLocked?GSColors.success:GSColors.error, size:28) + Text(card.isLocked?'Desbloquear':'Bloquear', bodySmall center) — onTap calls notifier.toggleLock()
> Space them with 8px gaps.
>
> Section 3 — 'Movimientos recientes' (16px top margin):
> Title row: Text('Movimientos recientes', titleMedium bold) + TextButton('Ver todos', accent) → context.go(AppRoutes.history)
> transactionListProvider.when:
>   loading: Column(5x GSTransactionSkeleton)
>   error: GSErrorCard(...)
>   data: if empty→GSEmptyState(icon:receipt_long_rounded, title:'Sin movimientos', subtitle:'Tus transacciones aparecerán aquí')
>         else Column(first 5 items: ListTile with leading CircleAvatar(bg: modeColor.withOpacity(0.15), child:Icon(modeIcon, modeColor, 18)), title:Text(description), subtitle:Text(formattedDate), trailing:Text(formattedAmount, bold titleMedium) )
>
> Section 4 — Card controls (16px top margin, GSCard padding 16px):
> Title 'Controles de tarjeta' (headlineSmall) then:
>   SwitchListTile(title:'Bloquear tarjeta', value:card.isLocked, onChanged: notifier.toggleLock, activeColor:GSColors.error)
>   ListTile(leading:Icon(report_problem_rounded, color:GSColors.error), title:Text('Reportar pérdida'), onTap: show snackbar 'Contacta con soporte')
>
> GSBottomNav(currentIndex:2, onTap: standard navigation switch)"

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/wallet/wallet_screen.dart
git commit -m "feat(wallet): rebuild wallet screen — physical card, quick actions, transactions"
```

---

## Chunk 4: Phase 3 — Screen Reconstruction (History + Profile)

### Task 10: Rebuild History Screen

**Files:**
- Modify: `lib/features/history/history_screen.dart`

- [ ] **Step 1: Invoke premium-ui-designer agent**

Prompt:
> "Rebuild `lib/features/history/history_screen.dart` for GoSmart. ConsumerStatefulWidget. Tokens `../../theme/design_tokens.dart`, widgets `../../widgets/`, providers `../../providers/transaction_provider.dart`.
>
> Scaffold(backgroundColor: GSColors.bg):
> - AppBar: 'Mis Viajes', white, no elevation
> - Body:
>
> State: `int _tabIndex = 0` (0=Viajes, 1=Tickets, 2=Recibos)
>
> Pill tab bar (Padding 16px all, Row of 3):
> Each tab is Expanded GestureDetector → setState tab. Active: Container(color:GSColors.accent, radius:full, padding sym h:16 v:8, child:Text(label, white, bold 13px)). Inactive: Container(color:GSColors.surfaceDark, ..., child:Text(label, textSecondary, 13px)). Animate with AnimatedContainer.
>
> Monthly summary card (margin h:16px v:8px, GSCard padding 16px):
> transactionListProvider.when data: compute totalSpent = sum of amounts, count = list.length.
> Row[ Column(Text('Total este mes', bodySmall textSecondary), Text(formatCOP(totalSpent), displaySmall bold accent)) + Spacer + Column(Text(count.toString(), displaySmall bold primary), Text('viajes', bodySmall textSecondary)) ]
> loading: GSSkeletonLoader(width:double.infinity, height:72, radius:20)
>
> Transaction list (based on _tabIndex — for MVP show same transactionListProvider data for all tabs):
> transactionListProvider.when:
>   loading: Column(5x GSTransactionSkeleton)
>   error: GSErrorCard(message: error.toString(), onRetry: ref.refresh(transactionListProvider))
>   data(list): if empty→GSEmptyState(icon:receipt_long_rounded, title:'No tienes viajes aún', subtitle:'Empieza tu primer viaje', actionLabel:'Planificar viaje', onAction: context.go(AppRoutes.routePlanner))
>   else ListView.separated of transaction cards:
>     Each card: Padding(h:16px,v:4px) GSCard(padding:12px onTap: null):
>       Row[ CircleAvatar(radius:22, bg:modeColor(t).withOpacity(0.15), child:Icon(modeIcon(t), modeColor(t), 20)) + 12px + Expanded(Column(crossAxisAxis:start [ Text(t.description??'Viaje', titleMedium), Text(formatDate(t.createdAt), bodySmall textSecondary) ])) + Column(crossAxisAxis:end [ Text(formatCOP(t.amount), titleMedium bold), 4px, statusBadge(t.status) ]) ]
>     statusBadge: Container(padding sym h:8 v:3, radius full, color:statusColor.withOpacity(0.12), child:Text(statusLabel, 11px bold color:statusColor))
>     Completado→success, Pendiente→warning, Cancelado→error
>     modeColor helper: switch(t.mode) car→GSColors.car, taxi→GSColors.taxi, bus→GSColors.bus, bike→GSColors.bike, walk→GSColors.walk, metro→GSColors.metro, _→GSColors.accent
>     modeIcon helper: switch same, icons: directions_car, local_taxi, directions_bus, pedal_bike, directions_walk, subway, _→commute
>   separator: SizedBox(height:4)
>   At bottom: if more items: Padding(16px, TextButton('Cargar más →', onPressed: ref.read(transactionListProvider.notifier).loadMore()))
>
> GSBottomNav(currentIndex:1, onTap: standard nav)"

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/history/history_screen.dart
git commit -m "feat(history): rebuild history screen — pill tabs, monthly summary, rich transaction cards"
```

---

### Task 11: Rebuild Profile Screen

**Files:**
- Modify: `lib/features/profile/profile_screen.dart`

- [ ] **Step 1: Invoke premium-ui-designer agent**

Prompt:
> "Rebuild `lib/features/profile/profile_screen.dart` for GoSmart. ConsumerStatefulWidget. Tokens `../../theme/design_tokens.dart`, widgets `../../widgets/`, providers `../../providers/profile_provider.dart` + `../../providers/transaction_provider.dart`, services `../../services/auth_service.dart`, router `../../router/app_router.dart`.
>
> Scaffold(backgroundColor:GSColors.bg, body: CustomScrollView with SliverAppBar + SliverToBoxAdapter):
>
> SliverAppBar(
>   expandedHeight:200, pinned:true, backgroundColor:transparent, elevation:0,
>   flexibleSpace: FlexibleSpaceBar(
>     background: Stack[
>       Container(decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF1A1A2E),Color(0xFF6C63FF)], begin:topLeft, end:bottomRight))),
>       Positioned(bottom:20, left:0, right:0, child: Column(
>         CircleAvatar(radius:44, backgroundColor:GSColors.accentLight, child: profileProvider.when(data:(p)=>p.avatarUrl!=null?NetworkImage:Icon(person_rounded,size:44,color:GSColors.accent), loading:()=>CircularProgressIndicator(), error:(_,__)=>Icon)),
>         8px,
>         profileProvider.when(data:(p)=>Text(p.name, style:white Inter bold 18px), loading:()=>GSSkeletonLoader(w:120,h:18,r:4), error:(_,__)=>Text('...')),
>         4px,
>         profileProvider.when(data:(p)=>Text(p.email??p.phone??'', style:white70 13px), ...)
>       ))
>     ]
>   ),
>   actions: [IconButton(Icons.edit_rounded, color:white, onPressed: show _EditPersonalInfoSheet)]
> )
>
> SliverToBoxAdapter: Column(
>
>   Stats row (GSCard margin h:16px top:16px, padding 16px):
>   Row[ _StatChip(label: '${txCount} Viajes', icon:route_rounded), divider, _StatChip(label:'${profile.ecoPoints??0} Pts Eco', icon:eco_rounded, color:GSColors.eco) ]
>   txCount from transactionListProvider.when(data:(l)=>l.length, loading:()=>0, error:(_,__)=>0)
>
>   _SettingsSection('Mi cuenta', [
>     _SettingsTile(Icons.person_outline_rounded, 'Información personal', onTap: show _EditPersonalInfoSheet),
>     _SettingsTile(Icons.notifications_outlined, 'Notificaciones', trailing: Switch(value:false, onChanged:(_){}, activeColor:GSColors.accent)),
>     _SettingsTile(Icons.language_rounded, 'Idioma', trailing: Text('Español', bodyMedium textSecondary)),
>   ]),
>
>   _SettingsSection('Seguridad', [
>     _SettingsTile(Icons.lock_outline_rounded, 'Cambiar contraseña', onTap: show _ChangePasswordSheet),
>     _SettingsTile(Icons.fingerprint_rounded, 'Login biométrico', trailing: Switch(value:false, onChanged:(_){}, activeColor:GSColors.accent)),
>     _SettingsTile(Icons.privacy_tip_outlined, 'Política de privacidad'),
>   ]),
>
>   _SettingsSection('Tarjeta', [
>     _SettingsTile(Icons.credit_card_rounded, 'Bloquear tarjeta', onTap: context.go(AppRoutes.wallet)),
>     _SettingsTile(Icons.report_problem_outlined, 'Reportar pérdida', iconColor: GSColors.error, textColor: GSColors.error),
>   ]),
>
>   _SettingsSection('Soporte', [
>     _SettingsTile(Icons.help_outline_rounded, 'Centro de ayuda'),
>     _SettingsTile(Icons.chat_bubble_outline_rounded, 'Chat en vivo'),
>     _SettingsTile(Icons.star_outline_rounded, 'Calificar la app'),
>   ]),
>
>   Padding(h:16px, v:8px): GSButton(label:'Cerrar sesión', variant:danger, leadingIcon:logout_rounded, onPressed: () async { final messenger = ScaffoldMessenger.of(context); await authService.signOut(); })
>
>   Padding 8px: Text('GoSmart v1.0.0', style:bodySmall textDisabled, center)
>   SizedBox(height:24)
> )
>
> Helper widgets (private, same file):
> _SettingsSection(String title, List<Widget> tiles): Column(crossAxisAxis:start [ Padding(h:16px,v:8px):Text(title, labelSmall textSecondary uppercase letterSpacing:1), GSCard(margin:h:16px, padding:0px, child:Column(tiles)) ])
> _SettingsTile(IconData icon, String label, {Widget? trailing, VoidCallback? onTap, Color? iconColor, Color? textColor}): ListTile(leading:Icon(icon, color:iconColor??textSecondary, size:22), title:Text(label, color:textColor??textPrimary, bodyLarge), trailing: trailing??Icon(chevron_right_rounded, textDisabled, 18), onTap:onTap)
> _StatChip(String label, IconData icon, {Color color=GSColors.accent}): Expanded(child:Column(Icon(icon,color,24), 4px, Text(label, bodyMedium bold, center)))
>
> Keep existing _EditPersonalInfoSheet and _ChangePasswordSheet implementations — restyle with GSTextField, accent colors, xl border radius.
>
> GSBottomNav(currentIndex:3, onTap: standard nav)"

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/profile/profile_screen.dart
git commit -m "feat(profile): rebuild profile screen — gradient SliverAppBar, settings sections, stats row"
```

---

## Chunk 5: Phase 3 — Auth Screens

### Task 12: Rebuild Onboarding Screen

**Files:**
- Modify: `lib/features/auth/onboarding_screen.dart`
- Add: `assets/images/onboarding_illustration.png`

- [ ] **Step 1: Add onboarding illustration**

Place any transport/city illustration PNG (300×400px min) at `assets/images/onboarding_illustration.png`. If unavailable, the screen will gracefully fallback to an icon.

- [ ] **Step 2: Invoke premium-ui-designer agent**

Prompt:
> "Rebuild `lib/features/auth/onboarding_screen.dart` for GoSmart. StatelessWidget. Tokens `../../theme/design_tokens.dart`, widgets `../../widgets/`, router AppRoutes from `../../router/app_router.dart`.
>
> Scaffold(body: Stack):
> 1. Container(decoration: BoxDecoration(gradient: LinearGradient(colors:[Color(0xFF1A1A2E), Color(0xFF0D1117)], begin:topLeft, end:bottomRight))) — fills screen
> 2. Positioned.fill child SafeArea(child: Column(children:[
>    Expanded(flex:5): Center(child: Image.asset('assets/images/onboarding_illustration.png', fit:BoxFit.contain, errorBuilder:(_,__,___):Icon(Icons.directions_transit_rounded, size:120, color:GSColors.accent)))
>    Expanded(flex:4): Container(
>      decoration: BoxDecoration(color:white, borderRadius:BorderRadius.vertical(top:Radius.circular(32))),
>      padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
>      child: Column(crossAxisAxis:center, mainAxisSize:min, children:[
>        Text('GoSmart', style: Inter bold 32px accent),
>        8px,
>        Text('Tu movilidad inteligente', style: bodyLarge textSecondary center),
>        32px,
>        GSButton(label:'Iniciar sesión', onPressed: ()=>context.go(AppRoutes.login)),
>        12px,
>        GSButton(label:'Crear cuenta', variant:outline, onPressed: ()=>context.go(AppRoutes.register)),
>        16px,
>        Text('Al continuar aceptas nuestros Términos y Política de Privacidad', style:bodySmall textDisabled center),
>      ])
>    )
>   ]))
>
> No AppBar."

- [ ] **Step 3: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/onboarding_screen.dart assets/images/onboarding_illustration.png
git commit -m "feat(auth): rebuild onboarding — dark navy hero, white bottom card, Inter branding"
```

---

### Task 13: Rebuild Login Screen

**Files:**
- Modify: `lib/features/auth/login_screen.dart`

- [ ] **Step 1: Invoke premium-ui-designer agent**

Prompt:
> "Rebuild `lib/features/auth/login_screen.dart` for GoSmart. ConsumerStatefulWidget. Tokens `../../theme/design_tokens.dart`, widgets `../../widgets/`, services `../../services/auth_service.dart`, router `../../router/app_router.dart`.
>
> State: `enum _AuthMode { sms, email }`, `_AuthMode _mode = _AuthMode.email`, phone/email/password controllers, `bool _loading = false`, `bool _showPassword = false`.
>
> Scaffold(backgroundColor:white, body: SafeArea(child: SingleChildScrollView(padding:24px all)):
> 1. SizedBox(height:32)
> 2. Text('Bienvenido de nuevo', style:displayMedium bold textPrimary, center)
> 3. 8px
> 4. Text('Inicia sesión en tu cuenta', style:bodyLarge textSecondary, center)
> 5. 32px
> 6. Segmented control (Row, Container height:48 decoration:BoxDecoration(color:GSColors.surfaceDark, radius:full)):
>    2x Expanded GestureDetector: active→AnimatedContainer(color:GSColors.accent, radius:full, child:Text(label, white bold 14px center)); inactive→Container(color:transparent, child:Text(label, textSecondary 14px center))
>    Labels: SMS=>'SMS OTP', Email=>'Correo'
> 7. 24px
> 8. if _mode==sms: GSTextField(hint:'Número de teléfono', prefixIcon:phone_android_rounded, keyboardType:phone)
>    if _mode==email: Column(GSTextField(hint:'Correo electrónico', prefixIcon:email_outlined, keyboardType:emailAddress), 12px, GSTextField(hint:'Contraseña', prefixIcon:lock_outlined, obscureText:!_showPassword, suffixIcon:IconButton(icon:Icon(_showPassword?visibility_off:visibility, textSecondary), onPressed:toggle)))
> 9. 8px
> 10. if _mode==email: Align(right, TextButton('¿Olvidaste tu contraseña?', accent, style:bodySmall))
> 11. 24px
> 12. GSButton(label: _mode==sms?'Enviar código':'Iniciar sesión', isLoading:_loading, onPressed: _handleLogin)
> 13. 24px
> 14. Row[ Expanded(Divider), Padding(h:16px, Text('o', bodySmall textDisabled)), Expanded(Divider) ]
> 15. 16px
> 16. Row(mainAxisAlignment:center, gap:12px): 2x OutlinedButton(style: side accent 1px, borderRadius full, padding sym h:24 v:12): Google (Icon(Icons.g_mobiledata_rounded, size:24)) + Apple (Icon(Icons.apple_rounded, size:24)) — onPressed: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Próximamente')))
> 17. Spacer
> 18. Row(center): Text('¿No tienes cuenta? ', bodyMedium textSecondary) + TextButton('Regístrate', accent, onPressed:context.go(AppRoutes.register))
>
> _handleLogin():
>   if sms: setState loading=true, await authService.sendOtp(phone), context.push(AppRoutes.smsVerify, extra: phone), setState loading=false. Catch: GSToast.showWithMessenger on error.
>   if email: setState loading=true, await authService.signInWithEmail(email, password). Catch GSToast. setState loading=false.
>
> Preserve all existing auth logic — only rebuild UI."

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/login_screen.dart
git commit -m "feat(auth): rebuild login screen — segmented toggle, Inter, accent CTAs"
```

---

### Task 14: Rebuild Register Screen

**Files:**
- Modify: `lib/features/auth/register_screen.dart`

- [ ] **Step 1: Invoke premium-ui-designer agent**

Prompt:
> "Rebuild `lib/features/auth/register_screen.dart` for GoSmart. ConsumerStatefulWidget. Tokens `../../theme/design_tokens.dart`, widgets `../../widgets/`, services `../../services/auth_service.dart`, router `../../router/app_router.dart`.
>
> State: name/phone/email/password controllers, `bool _termsAccepted = false`, `bool _loading = false`, `bool _showPassword = false`.
>
> Scaffold(backgroundColor:white, body: SafeArea(SingleChildScrollView(padding:24)):
> 1. Row[ IconButton(arrow_back_rounded, textPrimary, context.pop if canPop else context.go(AppRoutes.login)) ]
> 2. 16px
> 3. Text('Crear cuenta', displayMedium bold textPrimary)
> 4. 8px
> 5. Text('Únete a GoSmart hoy', bodyLarge textSecondary)
> 6. 32px
> 7. Column(gap 12px): 4x GSTextField: Nombre completo (person_outline_rounded), Teléfono (phone_android_rounded, phone keyboard), Correo (email_outlined, email keyboard), Contraseña (lock_outlined, obscure, suffix toggle icon)
> 8. 16px
> 9. Row[ Checkbox(value:_termsAccepted, onChanged:(v)=>setState, activeColor:GSColors.accent, shape:RoundedRectangleBorder(radius:4)) + Expanded(RichText: TextSpan['Acepto los ', TextSpan('Términos', style:accent underline, recognizer:TapGestureRecognizer onTap:snackbar), ' y la ', TextSpan('Política de Privacidad', style:accent underline, recognizer:TapGestureRecognizer onTap:snackbar)])]
> 10. 24px
> 11. GSButton(label:'Crear cuenta', isLoading:_loading, onPressed: _termsAccepted ? _handleRegister : null)
> 12. 24px
> 13. Row(center): Text('¿Ya tienes cuenta? ', bodyMedium textSecondary) + TextButton('Inicia sesión', accent, context.go(AppRoutes.login))
>
> _handleRegister(): setState loading=true, await authService.signUp(email:email, password:password, fullName:name, consentGeo:false, consentAi:false). Catch GSToast. setState loading=false.
> Preserve all existing signup logic."

- [ ] **Step 2: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/register_screen.dart
git commit -m "feat(auth): rebuild register screen — clean form, accent checkbox, Inter"
```

---

### Task 15: Update remaining auth + feature screens

**Files:**
- Modify: `lib/features/auth/sms_verify_screen.dart`
- Modify: `lib/features/routes/route_planner_screen.dart`
- Modify: `lib/features/routes/route_detail_screen.dart`
- Modify: `lib/features/ai_chat/ai_chat_screen.dart`
- Modify: `lib/features/payment/payment_validation_screen.dart`

- [ ] **Step 1: Read each file**

Read all 5 files to understand current structure.

- [ ] **Step 2: Apply token updates to each file**

For each file, do a targeted search-and-replace:
- `GSColors.primary` used as interactive/foreground color → `GSColors.accent`
- `GSColors.surface2` → `GSColors.surfaceDark`
- `GSColors.primaryLight` → `GSColors.accentLight`
- `GSRadius.lg` as default card radius → `GSRadius.xl` (where it's a card, not a small element)
- Input border focus color: `primary` → `accent`

For `sms_verify_screen.dart`: ensure OTP digit boxes use accent focus border.
For `route_detail_screen.dart`: `GSOptionCard` now uses `accent` border when selected (already updated in gs_card.dart).

- [ ] **Step 3: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/sms_verify_screen.dart lib/features/routes/ lib/features/ai_chat/ lib/features/payment/
git commit -m "feat(screens): apply accent color tokens to auth/routes/ai-chat/payment screens"
```

---

## Chunk 6: Phase 4 — Polish

### Task 16: Add slide+fade transitions to GoRouter

**Files:**
- Modify: `lib/router/app_router.dart`

- [ ] **Step 1: Add GSDuration import**

At the top of `lib/router/app_router.dart`, add:
```dart
import '../theme/design_tokens.dart';
```

- [ ] **Step 2: Create reusable transition builder helper**

Add this private function at the top of the file, after the imports:

```dart
Widget _slideAndFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    ),
  );
}
```

- [ ] **Step 3: Replace all GoRoute builder: with pageBuilder:**

For every `GoRoute` in the router, replace:
```dart
builder: (_, __) => const SomeScreen(),
```
With:
```dart
pageBuilder: (context, state) => CustomTransitionPage(
  key: state.pageKey,
  child: const SomeScreen(),
  transitionDuration: GSDuration.page,
  transitionsBuilder: _slideAndFade,
),
```

For the SmsVerifyScreen route:
```dart
pageBuilder: (context, state) => CustomTransitionPage(
  key: state.pageKey,
  child: SmsVerifyScreen(phone: state.extra as String),
  transitionDuration: GSDuration.page,
  transitionsBuilder: _slideAndFade,
),
```

- [ ] **Step 4: Verify**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add lib/router/app_router.dart
git commit -m "feat(router): add slide+fade CustomTransitionPage to all routes"
```

---

### Task 17: Final responsiveness audit and cleanup

**Files:**
- All screens in `lib/features/`

- [ ] **Step 1: Run full analysis**

```bash
flutter analyze
```
Expected: 0 errors, minimal warnings.

- [ ] **Step 2: Test on 360px-wide device (small phone)**

```bash
flutter run -d <device-id>
```

Check each screen for:
- [ ] No RenderFlex overflows (yellow/black debug stripes)
- [ ] Profile header text fits without overflow
- [ ] Wallet card aspect ratio correct
- [ ] Home bottom sheet scrolls correctly
- [ ] Bottom nav labels visible on active tab

Common fixes:
- Text in rows: wrap in `Flexible` or `Expanded`
- Balance amounts: wrap in `FittedBox(fit: BoxFit.scaleDown)`
- Horizontal overflow: use `SingleChildScrollView(scrollDirection: Axis.horizontal)`

- [ ] **Step 3: Run tests**

```bash
flutter test
```
Expected: all pass (existing tests should still pass since no logic changed).

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: GoSmart UI overhaul complete — professional mobility app redesign"
```

---

## Summary of Files Created / Modified

| File | Action |
|------|--------|
| `lib/theme/design_tokens.dart` | Modified — new palette, GSRadius.xxl=28, GSShadow.card+accent |
| `lib/theme/app_theme.dart` | Modified — Inter font, ColorScheme, CardTheme, SwitchTheme |
| `lib/widgets/gs_button.dart` | Modified — AnimatedScale, accent color, StatefulWidget |
| `lib/widgets/gs_bottom_nav.dart` | Modified — pill-style redesign |
| `lib/widgets/gs_card.dart` | Modified — GSRadius.xl default, accent colors, GSShadow.card |
| `lib/widgets/gs_text_field.dart` | Modified — accent focus, xl radius, GSSearchBar accent icon |
| `lib/widgets/gs_bottom_sheet.dart` | Modified — accent drag handle |
| `lib/widgets/gs_skeleton_loader.dart` | Created |
| `lib/widgets/gs_empty_state.dart` | Created (includes GSErrorCard) |
| `lib/features/auth/*.dart` (4 files) | Moved from screens/ + rebuilt |
| `lib/features/home/home_screen.dart` | Moved + rebuilt |
| `lib/features/wallet/wallet_screen.dart` | Moved + rebuilt |
| `lib/features/history/history_screen.dart` | Moved + rebuilt |
| `lib/features/profile/profile_screen.dart` | Moved + rebuilt |
| `lib/features/routes/*.dart` (2 files) | Moved + restyled |
| `lib/features/ai_chat/ai_chat_screen.dart` | Moved + restyled |
| `lib/features/payment/payment_validation_screen.dart` | Moved + restyled |
| `lib/features/nfc_simulator/*.dart` | Moved |
| `lib/router/app_router.dart` | Modified — new imports + transitions |
| `assets/images/map_placeholder.png` | Added |
| `assets/images/onboarding_illustration.png` | Added |
| `pubspec.yaml` | Modified — register assets |
