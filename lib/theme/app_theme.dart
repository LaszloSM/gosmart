import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';

/// Tema de GoSmart, mundo "rótulo de colectivo": shell en ultramar, placas
/// blancas, títulos en letra condensada de rótulo y cuerpo en Barlow.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(GSPalette.light, Brightness.light);

  /// Noche: esquema propio (superficies más claras arriba, marca aclarada).
  static ThemeData get dark => _build(GSPalette.dark, Brightness.dark);

  static ThemeData _build(GSPalette p, Brightness brightness) {
    final ink = p.text;
    final muted = p.textMuted;
    const disp = GSFonts.display;

    // Títulos en Barlow Condensed (rótulo); cuerpo y etiquetas en Barlow.
    final textTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: disp, fontSize: 40, fontWeight: FontWeight.w800, height: 1.05, color: ink),
      displayMedium: TextStyle(fontFamily: disp, fontSize: 34, fontWeight: FontWeight.w800, height: 1.05, color: ink),
      displaySmall: TextStyle(fontFamily: disp, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, color: ink),
      headlineLarge: TextStyle(fontFamily: disp, fontSize: 28, fontWeight: FontWeight.w700, height: 1.1, color: ink),
      headlineMedium: TextStyle(fontFamily: disp, fontSize: 24, fontWeight: FontWeight.w700, height: 1.15, color: ink),
      headlineSmall: TextStyle(fontFamily: disp, fontSize: 22, fontWeight: FontWeight.w700, height: 1.15, color: ink),
      titleLarge: TextStyle(fontFamily: disp, fontSize: 24, fontWeight: FontWeight.w700, height: 1.15, color: ink),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: muted),
      bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45, color: muted),
      bodySmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, color: muted),
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ink),
      labelMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.15, color: muted),
      labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: muted),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GSRadius.md),
    );
    const buttonText = TextStyle(
      fontFamily: GSFonts.sans,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    );
    final inputRadius = BorderRadius.circular(GSRadius.md);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: GSFonts.sans,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.brand,
        onPrimary: p.onBrand,
        primaryContainer: p.brandTint,
        onPrimaryContainer: p.brand,
        secondary: p.brand,
        onSecondary: p.onBrand,
        secondaryContainer: p.brandTint,
        onSecondaryContainer: p.brand,
        tertiary: p.brand,
        onTertiary: p.onBrand,
        tertiaryContainer: p.brandTint,
        onTertiaryContainer: p.brand,
        error: p.roadClosed,
        onError: p.onBrand,
        errorContainer: p.roadClosedTint,
        onErrorContainer: p.roadClosed,
        surface: p.surface,
        onSurface: p.text,
        surfaceContainerLowest: p.surface,
        surfaceContainerLow: p.background,
        surfaceContainer: p.background,
        surfaceContainerHigh: p.surfaceSunken,
        surfaceContainerHighest: p.surfaceSunken,
        onSurfaceVariant: p.textMuted,
        outline: p.textMuted,
        outlineVariant: p.line,
        shadow: p.text,
        scrim: p.text,
        inverseSurface: p.text,
        onInverseSurface: p.surface,
        inversePrimary: p.brandTint,
      ),
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,

      // Shell en ultramar: la barra superior es la carrocería.
      appBarTheme: AppBarTheme(
        backgroundColor: p.shell,
        foregroundColor: p.onShell,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: GSSize.topBar,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: GSFonts.display,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: p.onShell,
        ),
        iconTheme: IconThemeData(color: p.onShell, size: 24),
        actionsIconTheme: IconThemeData(color: p.onShell, size: 24),
      ),

      // DESIGN.md: sin tarjetas por defecto; cuando existen, planas con línea.
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.lg),
          side: BorderSide(color: p.line),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: p.textMuted, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: p.textMuted, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: p.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: p.roadClosed, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: p.roadClosed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4,
          vertical: GSSpacing.s3,
        ),
        hintStyle: TextStyle(color: p.textDisabled, fontSize: 17),
        labelStyle: TextStyle(color: p.textMuted, fontSize: 17),
        errorStyle: TextStyle(color: p.roadClosed, fontSize: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          disabledBackgroundColor: p.brand.withValues(alpha: 0.38),
          disabledForegroundColor: p.onBrand,
          minimumSize: const Size(double.infinity, GSSize.touchTarget),
          shape: buttonShape,
          elevation: 0,
          textStyle: buttonText,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          minimumSize: const Size(double.infinity, GSSize.touchTarget),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(double.infinity, GSSize.touchTarget),
          side: BorderSide(color: p.textMuted, width: 2),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          minimumSize: const Size(GSSize.touchTarget, GSSize.touchTarget),
          textStyle: buttonText,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.brand,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceSunken,
        selectedColor: p.brandTint,
        labelStyle: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.sm),
        ),
        side: BorderSide(color: p.line),
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s3,
          vertical: GSSpacing.s1,
        ),
      ),

      // Selector segmentado nativo: lo elegido en ultramar, sin animación
      // de deslizamiento (acción repetida).
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, GSSize.touchTarget)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GSRadius.md))),
          side: WidgetStatePropertyAll(
              BorderSide(color: p.brand, width: 1.5)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? p.brand
                  : p.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? p.onBrand
                  : p.brand),
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: GSFonts.display,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          )),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.brand : null),
        side: BorderSide(color: p.textMuted, width: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSRadius.sm)),
      ),

      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: 1,
        space: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.onBrand;
          return p.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.brand;
          return p.surfaceSunken;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.brand;
          return p.textMuted;
        }),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: p.textMuted,
        textColor: p.text,
        minVerticalPadding: GSSpacing.s3,
        titleTextStyle: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 15,
          height: 1.35,
          color: p.textMuted,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.text,
        contentTextStyle: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 15,
          color: p.surface,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(GSRadius.lg)),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.line,
      ),

    );

    // ThemeData(fontFamily:) pisa la familia de todo el textTheme; los
    // títulos condensados se reponen aquí, después de construir el tema.
    return base.copyWith(
      textTheme: base.textTheme.merge(textTheme),
    );
  }

}
