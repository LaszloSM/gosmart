import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';

/// Tema de GoSmart, mundo "rótulo de colectivo": shell en ultramar, placas
/// blancas, títulos en letra condensada de rótulo y cuerpo en Barlow.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const ink = GSColors.text;
    const muted = GSColors.textMuted;
    const disp = GSFonts.display;

    // Títulos en Barlow Condensed (rótulo); cuerpo y etiquetas en Barlow.
    const textTheme = TextTheme(
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
      brightness: Brightness.light,
      fontFamily: GSFonts.sans,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: GSColors.brand,
        onPrimary: GSColors.onBrand,
        primaryContainer: GSColors.brandTint,
        onPrimaryContainer: GSColors.brand,
        secondary: GSColors.brand,
        onSecondary: GSColors.onBrand,
        secondaryContainer: GSColors.brandTint,
        onSecondaryContainer: GSColors.brand,
        tertiary: GSColors.brand,
        onTertiary: GSColors.onBrand,
        tertiaryContainer: GSColors.brandTint,
        onTertiaryContainer: GSColors.brand,
        error: GSColors.roadClosed,
        onError: GSColors.onBrand,
        errorContainer: GSColors.roadClosedTint,
        onErrorContainer: GSColors.roadClosed,
        surface: GSColors.surface,
        onSurface: GSColors.text,
        surfaceContainerLowest: GSColors.surface,
        surfaceContainerLow: GSColors.background,
        surfaceContainer: GSColors.background,
        surfaceContainerHigh: GSColors.surfaceSunken,
        surfaceContainerHighest: GSColors.surfaceSunken,
        onSurfaceVariant: GSColors.textMuted,
        outline: GSColors.textMuted,
        outlineVariant: GSColors.line,
        shadow: GSColors.text,
        scrim: GSColors.text,
        inverseSurface: GSColors.text,
        onInverseSurface: GSColors.surface,
        inversePrimary: GSColors.brandTint,
      ),
      scaffoldBackgroundColor: GSColors.background,
      textTheme: textTheme,

      // Shell en ultramar: la barra superior es la carrocería.
      appBarTheme: const AppBarTheme(
        backgroundColor: GSColors.brand,
        foregroundColor: GSColors.onBrand,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: GSSize.topBar,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: GSFonts.display,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: GSColors.onBrand,
        ),
        iconTheme: IconThemeData(color: GSColors.onBrand, size: 24),
        actionsIconTheme: IconThemeData(color: GSColors.onBrand, size: 24),
      ),

      // DESIGN.md: sin tarjetas por defecto; cuando existen, planas con línea.
      cardTheme: CardThemeData(
        color: GSColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.lg),
          side: const BorderSide(color: GSColors.line),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GSColors.surface,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: GSColors.textMuted, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: GSColors.textMuted, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: GSColors.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: GSColors.roadClosed, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: GSColors.roadClosed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4,
          vertical: GSSpacing.s3,
        ),
        hintStyle: const TextStyle(color: GSColors.textDisabled, fontSize: 17),
        labelStyle: const TextStyle(color: GSColors.textMuted, fontSize: 17),
        errorStyle: const TextStyle(color: GSColors.roadClosed, fontSize: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GSColors.brand,
          foregroundColor: GSColors.onBrand,
          disabledBackgroundColor: GSColors.brand.withValues(alpha: 0.38),
          disabledForegroundColor: GSColors.onBrand,
          minimumSize: const Size(double.infinity, GSSize.touchTarget),
          shape: buttonShape,
          elevation: 0,
          textStyle: buttonText,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GSColors.brand,
          foregroundColor: GSColors.onBrand,
          minimumSize: const Size(double.infinity, GSSize.touchTarget),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GSColors.text,
          minimumSize: const Size(double.infinity, GSSize.touchTarget),
          side: const BorderSide(color: GSColors.textMuted, width: 2),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GSColors.brand,
          minimumSize: const Size(GSSize.touchTarget, GSSize.touchTarget),
          textStyle: buttonText,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GSColors.surface,
        selectedItemColor: GSColors.brand,
        unselectedItemColor: GSColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: GSColors.surfaceSunken,
        selectedColor: GSColors.brandTint,
        labelStyle: const TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: GSColors.text,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.sm),
        ),
        side: const BorderSide(color: GSColors.line),
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
          side: const WidgetStatePropertyAll(
              BorderSide(color: GSColors.brand, width: 1.5)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? GSColors.brand
                  : GSColors.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? GSColors.onBrand
                  : GSColors.brand),
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: GSFonts.display,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          )),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? GSColors.brand : null),
        side: const BorderSide(color: GSColors.textMuted, width: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSRadius.sm)),
      ),

      dividerTheme: const DividerThemeData(
        color: GSColors.line,
        thickness: 1,
        space: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return GSColors.onBrand;
          return GSColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return GSColors.brand;
          return GSColors.surfaceSunken;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return GSColors.brand;
          return GSColors.textMuted;
        }),
      ),

      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: GSColors.textMuted,
        textColor: GSColors.text,
        minVerticalPadding: GSSpacing.s3,
        titleTextStyle: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: GSColors.text,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 15,
          height: 1.35,
          color: GSColors.textMuted,
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: GSColors.text,
        contentTextStyle: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 15,
          color: GSColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GSColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(GSRadius.lg)),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GSColors.brand,
        linearTrackColor: GSColors.line,
      ),

    );

    // ThemeData(fontFamily:) pisa la familia de todo el textTheme; los
    // títulos condensados se reponen aquí, después de construir el tema.
    return base.copyWith(
      textTheme: base.textTheme.merge(textTheme),
    );
  }

  /// Nombre anterior. La app es clara primero; el tema nocturno llega después.
  static ThemeData get dark => light;
}
