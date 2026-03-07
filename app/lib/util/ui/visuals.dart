import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppVisuals extends ThemeExtension<AppVisuals> {
  final bool useGlass;
  final Color backgroundTop;
  final Color backgroundMiddle;
  final Color backgroundBottom;
  final Color accentGlow;
  final Color glassSurface;
  final Color glassSurfaceStrong;
  final Color glassBorder;
  final Color mutedForeground;
  final Color shadowColor;
  final double glassBlur;
  final double dialogBlur;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double horizontalPadding;
  final double sectionSpacing;

  const AppVisuals({
    required this.useGlass,
    required this.backgroundTop,
    required this.backgroundMiddle,
    required this.backgroundBottom,
    required this.accentGlow,
    required this.glassSurface,
    required this.glassSurfaceStrong,
    required this.glassBorder,
    required this.mutedForeground,
    required this.shadowColor,
    required this.glassBlur,
    required this.dialogBlur,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.horizontalPadding,
    required this.sectionSpacing,
  });

  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [backgroundTop, backgroundMiddle, backgroundBottom],
        stops: const [0.0, 0.42, 1.0],
      );

  BorderRadius get smallRadius => BorderRadius.circular(radiusSmall);

  BorderRadius get mediumRadius => BorderRadius.circular(radiusMedium);

  BorderRadius get largeRadius => BorderRadius.circular(radiusLarge);

  @override
  AppVisuals copyWith({
    bool? useGlass,
    Color? backgroundTop,
    Color? backgroundMiddle,
    Color? backgroundBottom,
    Color? accentGlow,
    Color? glassSurface,
    Color? glassSurfaceStrong,
    Color? glassBorder,
    Color? mutedForeground,
    Color? shadowColor,
    double? glassBlur,
    double? dialogBlur,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? horizontalPadding,
    double? sectionSpacing,
  }) {
    return AppVisuals(
      useGlass: useGlass ?? this.useGlass,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundMiddle: backgroundMiddle ?? this.backgroundMiddle,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      accentGlow: accentGlow ?? this.accentGlow,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceStrong: glassSurfaceStrong ?? this.glassSurfaceStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      shadowColor: shadowColor ?? this.shadowColor,
      glassBlur: glassBlur ?? this.glassBlur,
      dialogBlur: dialogBlur ?? this.dialogBlur,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
    );
  }

  @override
  AppVisuals lerp(covariant ThemeExtension<AppVisuals>? other, double t) {
    if (other is! AppVisuals) {
      return this;
    }

    return AppVisuals(
      useGlass: t < 0.5 ? useGlass : other.useGlass,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundMiddle: Color.lerp(backgroundMiddle, other.backgroundMiddle, t)!,
      backgroundBottom: Color.lerp(backgroundBottom, other.backgroundBottom, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassSurfaceStrong: Color.lerp(glassSurfaceStrong, other.glassSurfaceStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t)!,
      dialogBlur: lerpDouble(dialogBlur, other.dialogBlur, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t)!,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
      horizontalPadding:
          lerpDouble(horizontalPadding, other.horizontalPadding, t)!,
      sectionSpacing: lerpDouble(sectionSpacing, other.sectionSpacing, t)!,
    );
  }
}

extension AppVisualsThemeDataExt on ThemeData {
  AppVisuals get visuals => extension<AppVisuals>()!;
}

extension AppVisualsBuildContextExt on BuildContext {
  AppVisuals get visuals => Theme.of(this).visuals;

  Size get screenSize => MediaQuery.sizeOf(this);

  bool get isCompactWidth => screenSize.width < 390;

  bool get isNarrowWidth => screenSize.width < 560;

  bool get isPhoneLayout => screenSize.width < 700;

  bool get isShortHeight => screenSize.height < 760;

  double get adaptiveHorizontalPadding {
    final width = screenSize.width;
    if (width < 360) {
      return 14;
    }
    if (width < 430) {
      return 16;
    }
    if (width < 700) {
      return 18;
    }
    return visuals.horizontalPadding;
  }

  double get adaptiveTopPadding => isPhoneLayout ? 18 : 24;

  double get adaptiveBottomPadding => isPhoneLayout ? 20 : 28;

  double get adaptiveSectionSpacing {
    if (!isPhoneLayout) {
      return visuals.sectionSpacing;
    }
    return visuals.sectionSpacing > 14 ? visuals.sectionSpacing - 4 : visuals.sectionSpacing;
  }
}
