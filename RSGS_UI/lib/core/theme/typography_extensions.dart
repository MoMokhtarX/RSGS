import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;

  TextStyle? get displayLarge => textTheme.displayLarge;
  TextStyle? get displayMedium => textTheme.displayMedium;
  TextStyle? get displaySmall => textTheme.displaySmall;
  
  TextStyle? get headlineLarge => textTheme.headlineLarge;
  TextStyle? get headlineMedium => textTheme.headlineMedium;
  TextStyle? get headlineSmall => textTheme.headlineSmall;
  
  TextStyle? get titleLarge => textTheme.titleLarge;
  TextStyle? get titleMedium => textTheme.titleMedium;
  TextStyle? get titleSmall => textTheme.titleSmall;
  
  TextStyle? get bodyLarge => textTheme.bodyLarge;
  TextStyle? get bodyMedium => textTheme.bodyMedium;
  TextStyle? get bodySmall => textTheme.bodySmall;
  
  TextStyle? get labelLarge => textTheme.labelLarge;
  TextStyle? get labelMedium => textTheme.labelMedium;
  TextStyle? get labelSmall => textTheme.labelSmall;

  Color get primaryColor => colorScheme.primary;
  Color get secondaryColor => colorScheme.secondary;
  Color get surfaceColor => colorScheme.surface;
  Color get onSurfaceColor => colorScheme.onSurface;
  Color get onSurfaceVariant => colorScheme.onSurfaceVariant;
  Color get errorColor => colorScheme.error;
  Color get borderColor => theme.dividerColor;

  AppThemeExtension get appTheme => theme.extension<AppThemeExtension>()!;
}

extension TextStyleHelpers on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get extraBold => copyWith(fontWeight: FontWeight.w800);
  TextStyle get black => copyWith(fontWeight: FontWeight.w900);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle get italic => copyWith(fontStyle: FontStyle.italic);
  
  TextStyle get primary => copyWith(color: AppColors.primaryTeal);
  TextStyle get white => copyWith(color: AppColors.white);
  
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
  TextStyle withWeight(FontWeight weight) => copyWith(fontWeight: weight);
  TextStyle withHeight(double height) => copyWith(height: height);
  TextStyle withLetterSpacing(double spacing) => copyWith(letterSpacing: spacing);

  TextStyle withValues({double? alpha}) => copyWith(
        color: (color ?? AppColors.textPrimary).withValues(alpha: alpha ?? 1.0),
      );
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color surfaceSubtle;
  final Color surfaceElevated;
  final Color textMuted;
  final Color glassBackground;
  final Color glassBorder;
  final List<BoxShadow> primaryShadow;
  final List<BoxShadow> softShadow;

  const AppThemeExtension({
    required this.surfaceSubtle,
    required this.surfaceElevated,
    required this.textMuted,
    required this.glassBackground,
    required this.glassBorder,
    required this.primaryShadow,
    required this.softShadow,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? surfaceSubtle,
    Color? surfaceElevated,
    Color? textMuted,
    Color? glassBackground,
    Color? glassBorder,
    List<BoxShadow>? primaryShadow,
    List<BoxShadow>? softShadow,
  }) {
    return AppThemeExtension(
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textMuted: textMuted ?? this.textMuted,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      primaryShadow: primaryShadow ?? this.primaryShadow,
      softShadow: softShadow ?? this.softShadow,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      primaryShadow: BoxShadow.lerpList(primaryShadow, other.primaryShadow, t)!,
      softShadow: BoxShadow.lerpList(softShadow, other.softShadow, t)!,
    );
  }

  static final light = AppThemeExtension(
    surfaceSubtle: AppColors.lightSurfaceSubtle,
    surfaceElevated: AppColors.lightSurfaceElevated,
    textMuted: AppColors.textMuted,
    glassBackground: AppColors.glassBackground,
    glassBorder: AppColors.glassBorder,
    primaryShadow: [
      BoxShadow(
        color: AppColors.primaryTeal.withValues(alpha: 0.15),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
    softShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  );

  static final dark = AppThemeExtension(
    surfaceSubtle: AppColors.darkSurfaceSubtle,
    surfaceElevated: AppColors.darkSurfaceElevated,
    textMuted: AppColors.darkTextMuted,
    glassBackground: AppColors.glassBackgroundDark,
    glassBorder: AppColors.glassBorderDark,
    primaryShadow: [
      BoxShadow(
        color: AppColors.primaryTeal.withValues(alpha: 0.3),
        blurRadius: 25,
        offset: const Offset(0, 12),
      ),
    ],
    softShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.4),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
