import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:yaru/yaru.dart' as yaru;

final _fallbackBorderRadius = BorderRadius.circular(14);

double get desktopPaddingFix => checkPlatformIsDesktop() ? 8 : 0;

ThemeData getTheme(
  ColorMode colorMode,
  Brightness brightness,
  DynamicColors? dynamicColors,
) {
  if (colorMode == ColorMode.yaru) {
    return _getYaruTheme(brightness);
  }

  final colorScheme =
      _determineColorScheme(colorMode, brightness, dynamicColors);
  final visuals = _buildVisuals(
    colorScheme: colorScheme,
    brightness: brightness,
    useGlass: checkPlatform([TargetPlatform.ohos]),
  );
  final inputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: visuals.glassBorder),
    borderRadius: visuals.mediumRadius,
  );

  return ThemeData(
    colorScheme: colorScheme,
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'HarmonyOS Sans',
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    extensions: [visuals],
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontFamily: 'HarmonyOS Sans',
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: visuals.glassSurfaceStrong,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: visuals.largeRadius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: visuals.glassSurfaceStrong,
      elevation: 0,
      shadowColor: visuals.shadowColor,
      shape: RoundedRectangleBorder(borderRadius: visuals.largeRadius),
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontFamily: 'HarmonyOS Sans',
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontFamily: 'HarmonyOS Sans',
        fontSize: 15,
        height: 1.45,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: visuals.glassSurfaceStrong,
      modalBackgroundColor: visuals.glassSurfaceStrong,
      shadowColor: visuals.shadowColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: visuals.largeRadius),
      showDragHandle: false,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: visuals.glassSurfaceStrong,
      hintStyle: TextStyle(color: visuals.mutedForeground),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.8)),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error.withOpacity(0.8)),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.08),
        disabledForegroundColor: visuals.mutedForeground,
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12 + desktopPaddingFix / 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: visuals.glassSurfaceStrong,
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: colorScheme.primary.withOpacity(0.14),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'HarmonyOS Sans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.primary);
        }
        return IconThemeData(color: visuals.mutedForeground);
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor:
            WidgetStatePropertyAll(visuals.glassSurfaceStrong),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurface;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: visuals.glassBorder)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? colorScheme.primary.withOpacity(0.45)
            : colorScheme.surface.withOpacity(0.65);
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.outline;
      }),
    ),
    dividerTheme: DividerThemeData(
      color: visuals.glassBorder,
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: visuals.glassSurfaceStrong,
      shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
      elevation: 0,
      textStyle: TextStyle(color: colorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: visuals.glassSurfaceStrong,
      contentTextStyle: TextStyle(color: colorScheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.ohos: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

ColorScheme _determineColorScheme(
  ColorMode mode,
  Brightness brightness,
  DynamicColors? dynamicColors,
) {
  final defaultColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF34C759),
    brightness: brightness,
  );

  final colorScheme = switch (mode) {
    ColorMode.system =>
      brightness == Brightness.light ? dynamicColors?.light : dynamicColors?.dark,
    ColorMode.localsend => defaultColorScheme.copyWith(
        primary: const Color(0xFF34C759),
        secondary: brightness == Brightness.light
            ? const Color(0xFF3A7AFE)
            : const Color(0xFF7BA7FF),
        tertiary: brightness == Brightness.light
            ? const Color(0xFF8A5BFF)
            : const Color(0xFFB8A0FF),
      ),
    ColorMode.oled => (dynamicColors?.dark ?? defaultColorScheme).copyWith(
        background: Colors.black,
        surface: Colors.black,
      ),
    ColorMode.yaru => throw StateError('Unreachable'),
  };

  return colorScheme ?? defaultColorScheme;
}

AppVisuals _buildVisuals({
  required ColorScheme colorScheme,
  required Brightness brightness,
  required bool useGlass,
}) {
  final isDark = brightness == Brightness.dark;
  return AppVisuals(
    useGlass: useGlass,
    backgroundTop:
        isDark ? const Color(0xFF08111E) : const Color(0xFFF4F8FF),
    backgroundMiddle:
        isDark ? const Color(0xFF0C1A2B) : const Color(0xFFEFF5F3),
    backgroundBottom:
        isDark ? const Color(0xFF05080F) : const Color(0xFFF8FAFD),
    accentGlow: colorScheme.primary.withOpacity(isDark ? 0.16 : 0.11),
    glassSurface:
        (isDark ? Colors.white : Colors.white).withOpacity(isDark ? 0.08 : 0.55),
    glassSurfaceStrong:
        (isDark ? Colors.white : Colors.white).withOpacity(isDark ? 0.12 : 0.72),
    glassBorder:
        (isDark ? Colors.white : colorScheme.outline).withOpacity(isDark ? 0.12 : 0.18),
    mutedForeground:
        (isDark ? Colors.white : colorScheme.onSurface).withOpacity(0.7),
    shadowColor: Colors.black.withOpacity(isDark ? 0.24 : 0.08),
    glassBlur: useGlass ? 18 : 0,
    dialogBlur: useGlass ? 24 : 0,
    radiusSmall: 14,
    radiusMedium: 20,
    radiusLarge: 28,
    horizontalPadding: 20,
    sectionSpacing: 18,
  );
}

Future<void> updateSystemOverlayStyle(BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  await updateSystemOverlayStyleWithBrightness(brightness);
}

Future<void> updateSystemOverlayStyleWithBrightness(Brightness brightness) async {
  if (checkPlatform([TargetPlatform.android])) {
    final darkMode = brightness == Brightness.dark;
    final androidSdkInt =
        RefenaScope.defaultRef.read(deviceInfoProvider).androidSdkInt ?? 0;
    final edgeToEdge = androidSdkInt >= 29;

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            darkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            edgeToEdge ? Colors.transparent : (darkMode ? Colors.black : Colors.white),
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            darkMode ? Brightness.light : Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: brightness,
        statusBarColor: Colors.transparent,
      ),
    );
  }
}

extension ThemeDataExt on ThemeData {
  Color get cardColorWithElevation {
    return ElevationOverlay.applySurfaceTint(
      cardColor,
      colorScheme.surfaceTint,
      1,
    );
  }
}

extension ColorSchemeExt on ColorScheme {
  Color get warning => Colors.orange;

  Color? get secondaryContainerIfDark {
    return brightness == Brightness.dark ? secondaryContainer : null;
  }

  Color? get onSecondaryContainerIfDark {
    return brightness == Brightness.dark ? onSecondaryContainer : null;
  }
}

BorderRadius _resolveInputBorderRadius(InputDecorationThemeData theme) {
  final border = switch (theme.border ??
      theme.enabledBorder ??
      theme.focusedBorder ??
      theme.disabledBorder ??
      theme.errorBorder ??
      theme.focusedErrorBorder) {
    final WidgetStateInputBorder border =>
      border.resolve(const <WidgetState>{}),
    final InputBorder border => border,
    null => null,
  };

  if (border case final OutlineInputBorder outlineBorder) {
    return outlineBorder.borderRadius;
  }

  return _fallbackBorderRadius;
}

extension InputDecorationThemeDataExt on InputDecorationThemeData {
  BorderRadius get borderRadius => _resolveInputBorderRadius(this);
}

extension InputDecorationThemeExt on InputDecorationTheme {
  BorderRadius get borderRadius => _resolveInputBorderRadius(data);
}

ThemeData _getYaruTheme(Brightness brightness) {
  final baseTheme = brightness == Brightness.light ? yaru.yaruLight : yaru.yaruDark;
  final colorScheme = baseTheme.colorScheme;
  final visuals = _buildVisuals(
    colorScheme: colorScheme,
    brightness: brightness,
    useGlass: false,
  );

  final inputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: visuals.mediumRadius,
  );

  return baseTheme.copyWith(
    extensions: [visuals],
    scaffoldBackgroundColor: Colors.transparent,
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.secondaryContainer,
      border: inputBorder,
      focusedBorder: inputBorder,
      enabledBorder: inputBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor:
            colorScheme.brightness == Brightness.dark ? Colors.white : null,
        padding: checkPlatformIsDesktop()
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: checkPlatformIsDesktop()
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: visuals.mediumRadius),
      ),
    ),
  );
}
