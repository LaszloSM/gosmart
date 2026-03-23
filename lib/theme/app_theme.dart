import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    // Display & headlines use Plus Jakarta Sans (editorial, premium).
    // Body & labels use Inter (legible at small sizes).
    final displayStyle = GoogleFonts.plusJakartaSans(
      color: GSColors.textPrimary,
      fontWeight: FontWeight.w700,
    );
    final headlineStyle = GoogleFonts.plusJakartaSans(
      color: GSColors.textPrimary,
      fontWeight: FontWeight.w700,
    );

    final textTheme = ThemeData.dark().textTheme.copyWith(
      displayLarge: displayStyle.copyWith(fontSize: 32, height: 1.2),
      displayMedium: displayStyle.copyWith(fontSize: 28, height: 1.2),
      displaySmall: displayStyle.copyWith(fontSize: 24, height: 1.3),
      headlineLarge: headlineStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
      headlineMedium: headlineStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      headlineSmall: headlineStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
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
        color: GSColors.textPrimary,
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
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: GSColors.accent,
        onPrimary: Color(0xFF003711),
        primaryContainer: GSColors.accentContainer,
        onPrimaryContainer: GSColors.textPrimary,
        secondary: GSColors.accentAlt,
        onSecondary: Color(0xFF003D2E),
        secondaryContainer: GSColors.accentAltLight,
        onSecondaryContainer: GSColors.textPrimary,
        tertiary: GSColors.tertiary,
        onTertiary: GSColors.tertiaryLight,
        tertiaryContainer: GSColors.tertiaryLight,
        onTertiaryContainer: GSColors.textPrimary,
        error: GSColors.error,
        onError: Color(0xFF3D1500),
        errorContainer: GSColors.errorLight,
        onErrorContainer: GSColors.error,
        surface: GSColors.surface,
        onSurface: GSColors.textPrimary,
        surfaceContainerHighest: GSColors.surfaceContainerHighest,
        onSurfaceVariant: GSColors.textSecondary,
        outline: GSColors.border,
        outlineVariant: GSColors.surfaceBright,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: GSColors.textPrimary,
        onInverseSurface: GSColors.primary,
        inversePrimary: GSColors.accentLight,
      ),
      scaffoldBackgroundColor: GSColors.bg,
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: GSColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17, fontWeight: FontWeight.w700,
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

      // Input — dark fields with ghost border
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GSColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: BorderSide(
            color: GSColors.border.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          borderSide: BorderSide(
            color: GSColors.accent.withValues(alpha: 0.40),
            width: 1.5,
          ),
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
        hintStyle: GoogleFonts.inter(
          color: GSColors.textDisabled, fontSize: 15,
        ),
        labelStyle: GoogleFonts.inter(
          color: GSColors.textSecondary, fontSize: 15,
        ),
      ),

      // ElevatedButton — note: GSButton overrides this with gradients
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GSColors.accent,
          foregroundColor: GSColors.primary,
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
          side: BorderSide(
            color: GSColors.accent.withValues(alpha: 0.40),
            width: 1.5,
          ),
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

      // Chip — dark base, kinetic green selected
      chipTheme: ChipThemeData(
        backgroundColor: GSColors.surfaceContainerHigh,
        selectedColor: GSColors.accentLight,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: GSColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.sm),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s3, vertical: GSSpacing.s1,
        ),
      ),

      // Divider — subtle, no hard lines
      dividerTheme: DividerThemeData(
        color: GSColors.border.withValues(alpha: 0.20),
        thickness: 1,
        space: 0,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return GSColors.accent;
          return GSColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return GSColors.accentLight;
          return GSColors.surfaceContainerHigh;
        }),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: GSColors.textSecondary,
        textColor: GSColors.textPrimary,
      ),
    );
  }

  // Keep the old getter name so main.dart doesn't break
  static ThemeData get light => dark;
}
