import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:test/test.dart';

void main() {
  group('getThemeWithSettings lightweight backdrop', () {
    for (final brightness in Brightness.values) {
      test('uses lightweight backdrop tokens for $brightness', () {
        final theme = getThemeWithSettings(
          colorMode: ColorMode.localsend,
          brightness: brightness,
          dynamicColors: null,
          lightweightEffects: true,
        );
        final visuals = theme.visuals;

        expect(visuals.showBackdropOrbs, isFalse);
        expect(visuals.backdropPrimaryWash.alpha / 255, lessThan(0.09));
        expect(visuals.backdropPrimaryWash.red, theme.colorScheme.primary.red);
        expect(
          visuals.backdropPrimaryWash.green,
          theme.colorScheme.primary.green,
        );
        expect(visuals.backdropPrimaryWash.blue, theme.colorScheme.primary.blue);

        final expectedDepthBase = brightness == Brightness.dark
            ? Colors.white
            : Colors.black;
        expect(visuals.backdropDepthWash.alpha / 255, lessThan(0.06));
        expect(visuals.backdropDepthWash.red, expectedDepthBase.red);
        expect(visuals.backdropDepthWash.green, expectedDepthBase.green);
        expect(visuals.backdropDepthWash.blue, expectedDepthBase.blue);
      });

      test('keeps backdrop orbs for advanced effects in $brightness', () {
        final theme = getThemeWithSettings(
          colorMode: ColorMode.localsend,
          brightness: brightness,
          dynamicColors: null,
          lightweightEffects: false,
        );

        expect(theme.visuals.showBackdropOrbs, isTrue);
      });
    }
  });
}
