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
      colorScheme: const ColorScheme(
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
      cardTheme: CardThemeData(
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
