import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GSColors.primary,
        primary: GSColors.primary,
        secondary: GSColors.eco,
        background: GSColors.bg,
        surface: GSColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: GSColors.textPrimary,
        onSurface: GSColors.textPrimary,
        error: GSColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: GSColors.bg,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: GSColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: GSColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: GSColors.textPrimary, size: 24),
      ),

      // Card
      cardTheme: CardThemeData(
        color: GSColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GSColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.md),
          borderSide: const BorderSide(color: GSColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.md),
          borderSide: const BorderSide(color: GSColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GSRadius.md),
          borderSide: const BorderSide(color: GSColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4,
          vertical: GSSpacing.s4,
        ),
        hintStyle: const TextStyle(
          color: GSColors.textDisabled,
          fontSize: 15,
        ),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GSColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GSColors.primary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: GSColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          textStyle: const TextStyle(
            
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GSColors.primary,
          textStyle: const TextStyle(
            
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GSColors.surface,
        selectedItemColor: GSColors.primary,
        unselectedItemColor: GSColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          
          fontSize: 11,
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: GSColors.surface2,
        selectedColor: GSColors.primaryLight,
        labelStyle: const TextStyle(
          
          fontSize: 13,
          color: GSColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.full),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s3,
          vertical: GSSpacing.s1,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: GSColors.border,
        thickness: 1,
        space: 0,
      ),

      // Text styles
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: GSColors.textPrimary,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: GSColors.textPrimary,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: GSColors.textPrimary,
          height: 1.3,
        ),
        headlineLarge: TextStyle(
          
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: GSColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: GSColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: GSColors.textPrimary,
        ),
        titleLarge: TextStyle(
          
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: GSColors.textPrimary,
        ),
        titleMedium: TextStyle(
          
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: GSColors.textPrimary,
        ),
        titleSmall: TextStyle(
          
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: GSColors.textSecondary,
        ),
        bodyLarge: TextStyle(
          
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: GSColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: GSColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: GSColors.textDisabled,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: GSColors.primary,
        ),
        labelMedium: TextStyle(
          
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: GSColors.textSecondary,
        ),
        labelSmall: TextStyle(
          
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: GSColors.textDisabled,
        ),
      ),
    );
  }
}
