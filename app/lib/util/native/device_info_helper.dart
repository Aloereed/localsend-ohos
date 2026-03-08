import 'dart:ui' as ui;

import 'package:common/model/device.dart';
import 'package:common/model/device_info_result.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:slang/src/builder/model/enums.dart';

// ignore: implementation_imports
import 'package:slang/src/builder/utils/string_extensions.dart';

Future<DeviceInfoResult> getDeviceInfo() async {
  final plugin = DeviceInfoPlugin();
  final DeviceType deviceType;
  final String? deviceModel;
  int? androidSdkInt;

  if (kIsWeb) {
    deviceType = DeviceType.web;
    final deviceInfo = await plugin.webBrowserInfo;
    deviceModel = deviceInfo.browserName.humanName;
  } else {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final deviceInfo = await plugin.androidInfo;
        deviceType = _detectMobileDeviceType();
        deviceModel = deviceInfo.brand.toCase(CaseStyle.pascal);
        androidSdkInt = deviceInfo.version.sdkInt;
        break;
      case TargetPlatform.iOS:
        final deviceInfo = await plugin.iosInfo;
        deviceType = _detectMobileDeviceType();
        deviceModel = deviceInfo.localizedModel;
        break;
      case TargetPlatform.ohos:
        final deviceInfo = await plugin.ohosInfo;
        deviceType = _parseOhosDeviceType(deviceInfo.deviceType) ?? _detectMobileDeviceType();
        deviceModel = deviceInfo.marketName;
        break;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        deviceType = DeviceType.desktop;
        deviceModel = switch (defaultTargetPlatform) {
          TargetPlatform.linux => 'Linux',
          TargetPlatform.macOS => 'macOS',
          TargetPlatform.windows => 'Windows',
          TargetPlatform.fuchsia => 'Fuchsia',
          _ => null,
        };
        break;
    }
  }

  return DeviceInfoResult(
    deviceType: deviceType,
    deviceModel: deviceModel,
    androidSdkInt: androidSdkInt,
  );
}

DeviceType _detectMobileDeviceType() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) {
    return DeviceType.mobile;
  }

  final view = views.first;
  if (view.devicePixelRatio == 0) {
    return DeviceType.mobile;
  }

  final shortestLogicalSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  return shortestLogicalSide >= 600 ? DeviceType.tablet : DeviceType.mobile;
}

DeviceType? _parseOhosDeviceType(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  if (normalized.contains('tablet') || normalized.contains('pad')) {
    return DeviceType.tablet;
  }

  if (normalized.contains('phone') || normalized.contains('mobile')) {
    return DeviceType.mobile;
  }

  return null;
}

extension on BrowserName {
  String? get humanName {
    switch (this) {
      case BrowserName.firefox:
        return 'Firefox';
      case BrowserName.samsungInternet:
        return 'Samsung Internet';
      case BrowserName.opera:
        return 'Opera';
      case BrowserName.msie:
        return 'Internet Explorer';
      case BrowserName.edge:
        return 'Microsoft Edge';
      case BrowserName.chrome:
        return 'Google Chrome';
      case BrowserName.safari:
        return 'Safari';
      case BrowserName.unknown:
        return null;
    }
  }
}
