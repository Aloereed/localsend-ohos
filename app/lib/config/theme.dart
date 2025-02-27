import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:yaru/yaru.dart' as yaru;

final _borderRadius = BorderRadius.circular(5);

/// On desktop, we need to add additional padding to achieve the same visual appearance as on mobile
double get desktopPaddingFix => checkPlatformIsDesktop() ? 8 : 0;

ThemeData getTheme(
    ColorMode colorMode, Brightness brightness, DynamicColors? dynamicColors) {
  if (colorMode == ColorMode.yaru) {
    return _getYaruTheme(brightness);
  }

  final colorScheme =
      _determineColorScheme(colorMode, brightness, dynamicColors);

  final inputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
    borderRadius: BorderRadius.circular(12.0), // 鸿蒙风格的圆角设计
  );

  // 鸿蒙风格字体
  final String? fontFamily = checkPlatform([TargetPlatform.windows])
      ? 'HarmonyOS Sans'
      : 'HarmonyOS Sans';

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF2F3F5) // 鸿蒙浅色背景
        : const Color(0xFF000000), // 深色模式背景
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFF2F3F5)
          : const Color(0xFF000000),
      elevation: 0, // 扁平化设计
      iconTheme: IconThemeData(color: colorScheme.onBackground),
      titleTextStyle: TextStyle(
        color: colorScheme.onBackground,
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFF2F3F5) // 鸿蒙浅色背景
          : const Color(0xFF000000), // 深色模式背景
      indicatorColor: colorScheme.primary.withOpacity(0.1),
      labelTextStyle: MaterialStateProperty.all(
        TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: colorScheme.onBackground,
        ),
      ),
      iconTheme: MaterialStateProperty.all(
        IconThemeData(color: colorScheme.primary),
      ),
    ),
    bottomNavigationBarTheme: brightness == Brightness.light
        ? const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFFF2F3F5), // 底部导航栏背景色
            selectedItemColor: Colors.green, // 选中项的颜色
            unselectedItemColor: Color(0xFF919294), // 未选中项的颜色
            elevation: 0, // 去掉分割线
          )
        : const BottomNavigationBarThemeData(
            backgroundColor: Colors.black, // 底部导航栏背景颜色为纯黑
            selectedItemColor: Colors.green, // 选中项的颜色为红色
            unselectedItemColor: Color(0xFF818181), // 未选中项的颜色为灰色
            elevation: 0, // 去掉分割线
          ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface.withOpacity(0.1), // 浅色背景下的输入框填充色
      border: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary),
      ),
      enabledBorder: inputBorder,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: colorScheme.primary, // 主色调按钮
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // 圆角设计
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
        ),
      ),
    ),
    fontFamily: fontFamily,
    iconButtonTheme: brightness == Brightness.light
        ? IconButtonThemeData(
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.all(Color(0xFFE7E8EA)), // 背景色
              shape: MaterialStateProperty.all(
                CircleBorder(), // 圆形
              ),
              iconColor: MaterialStateProperty.all(Colors.black), // 图标颜色
            ),
          )
        : IconButtonThemeData(
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.all(Color(0xFF222222)), // 背景色
              shape: MaterialStateProperty.all(
                CircleBorder(), // 圆形
              ),
              iconColor: MaterialStateProperty.all(Colors.white), // 图标颜色
            ),
          ),
  );
}

ColorScheme _determineColorScheme(
    ColorMode mode, Brightness brightness, DynamicColors? dynamicColors) {
  final defaultColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.green, // 鸿蒙设计的主色调
    brightness: brightness,
  );

  final colorScheme = switch (mode) {
    ColorMode.system => brightness == Brightness.light
        ? dynamicColors?.light
        : dynamicColors?.dark,
    ColorMode.localsend => null,
    ColorMode.oled => (dynamicColors?.dark ?? defaultColorScheme).copyWith(
        background: Colors.black,
        surface: Colors.black,
      ),
    ColorMode.yaru => throw 'Should reach here',
  };

  return colorScheme ?? defaultColorScheme;
}

// ThemeData getTheme(ColorMode colorMode, Brightness brightness, DynamicColors? dynamicColors) {
//   if (colorMode == ColorMode.yaru) {
//     return _getYaruTheme(brightness);
//   }

//   final colorScheme = _determineColorScheme(colorMode, brightness, dynamicColors);

//   final lightInputBorder = OutlineInputBorder(
//     borderSide: BorderSide(color: colorScheme.secondaryContainer),
//     borderRadius: _borderRadius,
//   );

//   final darkInputBorder = OutlineInputBorder(
//     borderSide: BorderSide(color: colorScheme.secondaryContainer),
//     borderRadius: _borderRadius,
//   );

//   // https://github.com/localsend/localsend/issues/52
//   final String? fontFamily;
//   if (checkPlatform([TargetPlatform.windows])) {
//     fontFamily = switch (LocaleSettings.currentLocale) {
//       AppLocale.ja => 'Yu Gothic UI',
//       AppLocale.ko => 'Malgun Gothic',
//       AppLocale.zhCn => 'Microsoft YaHei UI',
//       AppLocale.zhHk || AppLocale.zhTw => 'Microsoft JhengHei UI',
//       _ => 'Segoe UI Variable Display',
//     };
//   } else {
//     fontFamily = null;
//   }

//   return ThemeData(
//     colorScheme: colorScheme,
//     useMaterial3: true,
//     navigationBarTheme: colorScheme.brightness == Brightness.dark
//         ? NavigationBarThemeData(
//             iconTheme: MaterialStateProperty.all(const IconThemeData(color: Colors.white)),
//           )
//         : null,
//     inputDecorationTheme: InputDecorationTheme(
//       filled: true,
//       fillColor: colorScheme.secondaryContainer,
//       border: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
//       focusedBorder: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
//       enabledBorder: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
//       contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
//     ),
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         foregroundColor: colorScheme.brightness == Brightness.dark ? Colors.white : null,
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8 + desktopPaddingFix),
//       ),
//     ),
//     textButtonTheme: TextButtonThemeData(
//       style: TextButton.styleFrom(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8 + desktopPaddingFix),
//       ),
//     ),
//     fontFamily: fontFamily,
//   );
// }

Future<void> updateSystemOverlayStyle(BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  await updateSystemOverlayStyleWithBrightness(brightness);
}

Future<void> updateSystemOverlayStyleWithBrightness(
    Brightness brightness) async {
  if (checkPlatform([TargetPlatform.android])) {
    // See https://github.com/flutter/flutter/issues/90098
    final darkMode = brightness == Brightness.dark;
    final androidSdkInt =
        RefenaScope.defaultRef.read(deviceInfoProvider).androidSdkInt ?? 0;
    final bool edgeToEdge = androidSdkInt >= 29;

    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge); // ignore: unawaited_futures

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: edgeToEdge
          ? Colors.transparent
          : (darkMode ? Colors.black : Colors.white),
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness:
          darkMode ? Brightness.light : Brightness.dark,
    ));
  } else {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: brightness, // iOS
      statusBarColor: Colors.transparent, // Not relevant to this issue
    ));
  }
}

extension ThemeDataExt on ThemeData {
  /// This is the actual [cardColor] being used.
  Color get cardColorWithElevation {
    return ElevationOverlay.applySurfaceTint(
        cardColor, colorScheme.surfaceTint, 1);
  }
}

extension ColorSchemeExt on ColorScheme {
  Color get warning {
    return Colors.orange;
  }

  Color? get secondaryContainerIfDark {
    return brightness == Brightness.dark ? secondaryContainer : null;
  }

  Color? get onSecondaryContainerIfDark {
    return brightness == Brightness.dark ? onSecondaryContainer : null;
  }
}

extension InputDecorationThemeExt on InputDecorationTheme {
  BorderRadius get borderRadius => _borderRadius;
}

// ColorScheme _determineColorScheme(ColorMode mode, Brightness brightness, DynamicColors? dynamicColors) {
//   final defaultColorScheme = ColorScheme.fromSeed(
//     seedColor: Colors.teal,
//     brightness: brightness,
//   );

//   final colorScheme = switch (mode) {
//     ColorMode.system => brightness == Brightness.light ? dynamicColors?.light : dynamicColors?.dark,
//     ColorMode.localsend => null,
//     ColorMode.oled => (dynamicColors?.dark ?? defaultColorScheme).copyWith(
//         background: Colors.black,
//         surface: Colors.black,
//       ),
//     ColorMode.yaru => throw 'Should reach here',
//   };

//   return colorScheme ?? defaultColorScheme;
// }

ThemeData _getYaruTheme(Brightness brightness) {
  final baseTheme =
      brightness == Brightness.light ? yaru.yaruLight : yaru.yaruDark;
  final colorScheme = baseTheme.colorScheme;

  final lightInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: _borderRadius,
  );

  final darkInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: _borderRadius,
  );

  return baseTheme.copyWith(
    navigationBarTheme: colorScheme.brightness == Brightness.dark
        ? NavigationBarThemeData(
            iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
          )
        : null,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.secondaryContainer,
      border: colorScheme.brightness == Brightness.light
          ? lightInputBorder
          : darkInputBorder,
      focusedBorder: colorScheme.brightness == Brightness.light
          ? lightInputBorder
          : darkInputBorder,
      enabledBorder: colorScheme.brightness == Brightness.light
          ? lightInputBorder
          : darkInputBorder,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor:
            colorScheme.brightness == Brightness.dark ? Colors.white : null,
        padding: checkPlatformIsDesktop()
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: checkPlatformIsDesktop()
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
  );
}
