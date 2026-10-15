import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';

/// Tema de GoSmart: familiar e intuitivo, al nivel de InDrive, Google Maps,
/// Nequi y Uber/DiDi. Barras blancas, un azul de marca, Figtree, botones en
/// píldora, tarjetas de 16 y hojas de 24.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(GSPalette.light, Brightness.light);

  /// Noche: esquema propio (superficies más claras arriba, marca aclarada).
  static ThemeData get dark => _build(GSPalette.dark, Brightness.dark);

  static ThemeData _build(GSPalette p, Brightness brightness) {
    final ink = p.text;
    final muted = p.textMuted;
    const f = GSFonts.sans;
    final isDark = brightness == Brightness.dark;

    // Una escala: 32 / 26 / 22 / 20 / 17 / 15 / 13. Títulos en caja normal,
    // peso 700–800; cuerpo 400; etiquetas 600.
    final textTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: f, fontSize: 34, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.8, color: ink),
      displayMedium: TextStyle(fontFamily: f, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.6, color: ink),
      displaySmall: TextStyle(fontFamily: f, fontSize: 26, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5, color: ink),
      headlineLarge: TextStyle(fontFamily: f, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.4, color: ink),
      headlineMedium: TextStyle(fontFamily: f, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3, color: ink),
      headlineSmall: TextStyle(fontFamily: f, fontSize: 20, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.2, color: ink),
      titleLarge: TextStyle(fontFamily: f, fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.1, color: ink),
      titleMedium: TextStyle(fontFamily: f, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      titleSmall: TextStyle(fontFamily: f, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: muted),
      bodyLarge: TextStyle(fontFamily: f, fontSize: 16, fontWeight: FontWeight.w400, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontFamily: f, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: muted),
      bodySmall: TextStyle(fontFamily: f, fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: muted),
      labelLarge: TextStyle(fontFamily: f, fontSize: 15, fontWeight: FontWeight.w600, color: ink),
      labelMedium: TextStyle(fontFamily: f, fontSize: 13, fontWeight: FontWeight.w600, color: muted),
      labelSmall: TextStyle(fontFamily: f, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: muted),
    );

    const pill = StadiumBorder();
    const buttonText = TextStyle(
      fontFamily: f,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final inputRadius = BorderRadius.circular(GSRadius.md);
    OutlineInputBorder field(Color c, double w) => OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: f,
      splashFactory: InkSparkle.splashFactory,
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
        tertiary: p.cardGold,
        onTertiary: p.text,
        tertiaryContainer: p.brandTint,
        onTertiaryContainer: p.brand,
        error: p.roadClosed,
        onError: isDark ? p.background : p.onBrand,
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
        shadow: p.shadowInk,
        scrim: Colors.black,
        inverseSurface: p.text,
        onInverseSurface: p.surface,
        inversePrimary: p.brandTint,
      ),
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,

      // Barra superior blanca, título grande a la izquierda (Material 3).
      appBarTheme: AppBarTheme(
        backgroundColor: p.shell,
        foregroundColor: p.onShell,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: p.shadowInk.withValues(alpha: 0.2),
        centerTitle: false,
        toolbarHeight: GSSize.topBar + 8,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: f,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: p.onShell,
        ),
        iconTheme: IconThemeData(color: p.onShell, size: 24),
        actionsIconTheme: IconThemeData(color: p.onShell, size: 24),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),

      // Campos rellenos en gris, sin borde en reposo; borde azul al enfocar.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceSunken,
        border: field(p.line, 0),
        enabledBorder: field(p.line, 0),
        focusedBorder: field(p.brand, 2),
        errorBorder: field(p.roadClosed, 2),
        focusedErrorBorder: field(p.roadClosed, 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4,
          vertical: GSSpacing.s4,
        ),
        hintStyle: TextStyle(color: p.textMuted, fontSize: 16),
        labelStyle: TextStyle(color: p.textMuted, fontSize: 16),
        floatingLabelStyle: TextStyle(color: p.brand, fontWeight: FontWeight.w600),
        errorStyle: TextStyle(color: p.roadClosed, fontSize: 13),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          disabledBackgroundColor: p.surfaceSunken,
          disabledForegroundColor: p.textDisabled,
          minimumSize: const Size(double.infinity, GSSize.button),
          shape: pill,
          elevation: 0,
          textStyle: buttonText,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          disabledBackgroundColor: p.surfaceSunken,
          disabledForegroundColor: p.textDisabled,
          minimumSize: const Size(double.infinity, GSSize.button),
          shape: pill,
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(double.infinity, GSSize.button),
          side: BorderSide(color: p.line, width: 1.5),
          shape: pill,
          textStyle: buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          minimumSize: const Size(GSSize.touchTarget, GSSize.touchTarget),
          shape: pill,
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(GSSize.touchTarget, GSSize.touchTarget),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 3,
        shape: const CircleBorder(),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.shell,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brandTint,
        elevation: 0,
        height: GSSize.bottomNav,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: f,
              fontSize: 12.5,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? p.text : p.textMuted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? p.brand : p.textMuted,
            )),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.brandTint,
        labelStyle: TextStyle(
          fontFamily: f,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: p.line),
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s3,
          vertical: GSSpacing.s2,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, GSSize.touchTarget)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: p.line, width: 1.5)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? p.brandTint : p.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? p.brand : p.text),
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: f,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          )),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.brand : null),
        side: BorderSide(color: p.textMuted, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.brand : p.textMuted),
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
          fontFamily: f,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: f,
          fontSize: 14,
          height: 1.35,
          color: p.textMuted,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? p.surfaceSunken : p.text,
        contentTextStyle: TextStyle(
          fontFamily: f,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? p.text : p.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GSRadius.md)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(GSRadius.xl)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GSRadius.xl)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: muted),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.brandTint,
        circularTrackColor: Colors.transparent,
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.brand,
        selectionColor: p.brand.withValues(alpha: 0.25),
        selectionHandleColor: p.brand,
      ),
    );

    // ThemeData(fontFamily:) pisa la familia del textTheme; se repone la escala.
    return base.copyWith(
      textTheme: base.textTheme.merge(textTheme),
    );
  }
}
