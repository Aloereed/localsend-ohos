import 'package:common/model/device.dart';
import 'package:flutter/material.dart';

extension DeviceTypeExt on DeviceType {
  IconData get icon {
    return switch (this) {
      DeviceType.mobile => Icons.smartphone,
      DeviceType.tablet => Icons.tablet_mac,
      DeviceType.desktop => Icons.computer,
      DeviceType.web => Icons.language,
      DeviceType.headless => Icons.terminal,
      DeviceType.server => Icons.dns,
    };
  }

  String get displayName {
    return switch (this) {
      DeviceType.mobile => 'Phone',
      DeviceType.tablet => 'Tablet',
      DeviceType.desktop => 'Desktop',
      DeviceType.web => 'Web',
      DeviceType.headless => 'Headless',
      DeviceType.server => 'Server',
    };
  }
}
