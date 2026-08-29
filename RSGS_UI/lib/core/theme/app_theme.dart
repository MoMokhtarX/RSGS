import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import 'typography_extensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light([String? langCode]) => _base(Brightness.light, langCode);
  static ThemeData dark([String? langCode]) => _base(Brightness.dark, langCode);

  static ThemeData _base(Brightness brightness, [String? langCode]) {
    final isDark = brightness == Brightness.dark;
    final isAr = langCode == 'ar';

    final primaryColor = AppColors.primaryTeal;
    final secondaryColor = AppColors.accentGold;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onSurface: textColor,
        onSurfaceVariant: textSecondaryColor,
        error: AppColors.error,
        outline: borderColor,
        surfaceContainerLow: isDark ? AppColors.darkSurfaceLowest : AppColors.lightSurfaceSubtle,
        surfaceContainer: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceContainerHigh: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceElevated,
        surfaceContainerHighest: isDark ? AppColors.darkSurfaceHighest : AppColors.white,
        surfaceTint: isDark ? AppColors.primaryTeal.withValues(alpha: 0.05) : AppColors.transparent,
      ),
      scaffoldBackgroundColor: backgroundColor,
      dividerColor: borderColor,
      textTheme: _textTheme(brightness, langCode),
      extensions: [
        isDark ? AppThemeExtension.dark : AppThemeExtension.light,
      ],
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isDark ? BorderSide(color: AppColors.darkBorderSubtle, width: 1) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: _inputDecoration(brightness, isAr),
      elevatedButtonTheme: _elevatedButtonTheme(isDark, isAr),
      filledButtonTheme: _filledButtonTheme(isDark, isAr),
      outlinedButtonTheme: _outlinedButtonTheme(brightness, isAr),
      textButtonTheme: _textButtonTheme(isAr),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: surfaceColor,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.dialogBorderRadius),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: primaryColor,
        headerForegroundColor: AppColors.white,
        backgroundColor: surfaceColor,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return textColor;
        }),
        todayBorder: BorderSide(color: primaryColor),
        todayForegroundColor: WidgetStateProperty.all(primaryColor),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: textSecondaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.textPrimary,
        contentTextStyle: TextStyle(
          color: AppColors.white,
          fontFamily: isAr ? GoogleFonts.cairo().fontFamily : GoogleFonts.inter().fontFamily,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.transparent,
        foregroundColor: textColor,
        surfaceTintColor: AppColors.transparent,
        titleTextStyle: _textTheme(brightness, langCode).titleLarge?.bold,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: const IconThemeData(color: AppColors.primaryTeal, size: 28),
        unselectedIconTheme: IconThemeData(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, size: 24),
        indicatorColor: AppColors.primaryTeal.withValues(alpha: 0.1),
        labelType: NavigationRailLabelType.none,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: _textTheme(brightness, langCode).labelSmall?.bold,
        backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        secondarySelectedColor: primaryColor,
        selectedColor: primaryColor.withValues(alpha: 0.1),
        side: BorderSide(color: borderColor, width: 1),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness, [String? langCode]) {
    final isAr = langCode == 'ar';
    final isDark = brightness == Brightness.dark;
    
    final baseTextTheme = isAr 
        ? GoogleFonts.cairoTextTheme() 
        : GoogleFonts.interTextTheme();
    
    final color = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: isAr ? 0 : -1.5,
        height: 1.1,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: isAr ? 0 : -1.0,
        height: 1.2,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: isAr ? 0 : -0.5,
        height: 1.2,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: isAr ? 0 : -0.3,
        height: 1.3,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.3,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.4,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.4,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.6,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.2,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: secondary,
        letterSpacing: 0.2,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: secondary,
        letterSpacing: 0.4,
      ),
    );
  }

  static InputDecorationTheme _inputDecoration(Brightness brightness, bool isAr) {
    final isDark = brightness == Brightness.dark;
    final fontFamily = isAr ? GoogleFonts.cairo().fontFamily : GoogleFonts.inter().fontFamily;
    final borderColor = isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder;
    final fillColor = isDark ? AppColors.darkSurfaceLowest : AppColors.white;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: TextStyle(
        color: secondaryColor, 
        fontSize: 14, 
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
      ),
      floatingLabelStyle: TextStyle(
        color: AppColors.primaryTeal, 
        fontWeight: FontWeight.w700, 
        fontSize: 12,
        fontFamily: fontFamily,
      ),
      hintStyle: TextStyle(
        color: mutedColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: fontFamily,
      ),
      prefixIconColor: mutedColor,
      suffixIconColor: mutedColor,
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(bool isDark, bool isAr) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: isDark ? 8 : 0,
        shadowColor: isDark ? AppColors.primaryTeal.withValues(alpha: 0.4) : AppColors.transparent,
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          fontFamily: isAr ? GoogleFonts.cairo().fontFamily : GoogleFonts.inter().fontFamily,
        ),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(bool isDark, bool isAr) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          fontFamily: isAr ? GoogleFonts.cairo().fontFamily : GoogleFonts.inter().fontFamily,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Brightness brightness, bool isAr) {
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          fontFamily: isAr ? GoogleFonts.cairo().fontFamily : GoogleFonts.inter().fontFamily,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(bool isAr) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: isAr ? GoogleFonts.cairo().fontFamily : GoogleFonts.inter().fontFamily,
        ),
      ),
    );
  }
}
