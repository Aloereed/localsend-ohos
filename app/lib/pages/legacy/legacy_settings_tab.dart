import 'dart:io';
import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/about/about_page.dart';
import 'package:localsend_app/pages/privacy_policy.dart';
import 'package:localsend_app/pages/settings/network_interfaces_page.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/util/alias_generator.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:localsend_app/widget/dialogs/encryption_disabled_notice.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/dialogs/text_field_tv.dart';
import 'package:localsend_app/widget/dialogs/text_field_with_actions.dart';
import 'package:localsend_app/widget/labeled_checkbox.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class LegacySettingsTab extends StatelessWidget {
  const LegacySettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: settingsTabControllerProvider,
      builder: (context, vm) {
        Translations.of(context);
        final ref = context.ref;
        final openMessageTabOnIncomingFiles =
            ref.watch(openMessageTabOnIncomingFilesProvider);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t.settingsTab.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t.settingsTab.general.title,
              children: [
                _EntryRow(
                  label: t.settingsTab.general.brightness,
                  child: CustomDropdownButton<ThemeMode>(
                    value: vm.settings.theme,
                    items: vm.themeModes.map((theme) {
                      return DropdownMenuItem(
                        value: theme,
                        alignment: Alignment.center,
                        child: Text(theme.humanName),
                      );
                    }).toList(),
                    onChanged: (theme) => vm.onChangeTheme(context, theme),
                  ),
                ),
                _EntryRow(
                  label: t.settingsTab.general.color,
                  child: CustomDropdownButton<ColorMode>(
                    value: vm.settings.colorMode,
                    items: vm.colorModes.map((colorMode) {
                      return DropdownMenuItem(
                        value: colorMode,
                        alignment: Alignment.center,
                        child: Text(colorMode.humanName),
                      );
                    }).toList(),
                    onChanged: vm.onChangeColorMode,
                  ),
                ),
                if (checkPlatformIsDesktop()) ...[
                  if (vm.advanced && checkPlatformIsNotWaylandDesktop())
                    _SwitchRow(
                      label: defaultTargetPlatform == TargetPlatform.windows
                          ? t.settingsTab.general.saveWindowPlacementWindows
                          : t.settingsTab.general.saveWindowPlacement,
                      value: vm.settings.saveWindowPlacement,
                      onChanged: (b) async {
                        await ref
                            .notifier(settingsProvider)
                            .setSaveWindowPlacement(b);
                      },
                    ),
                  if (checkPlatformHasTray())
                    _SwitchRow(
                      label: t.settingsTab.general.minimizeToTray,
                      value: vm.settings.minimizeToTray,
                      onChanged: (b) async {
                        await ref
                            .notifier(settingsProvider)
                            .setMinimizeToTray(b);
                      },
                    ),
                  if (checkPlatformIsDesktop()) ...[
                    _SwitchRow(
                      label: t.settingsTab.general.launchAtStartup,
                      value: vm.autoStart,
                      onChanged: (_) => vm.onToggleAutoStart(context),
                    ),
                    if (vm.autoStart)
                      _SwitchRow(
                        label: t.settingsTab.general.launchMinimized,
                        value: vm.autoStartLaunchHidden,
                        onChanged: (_) =>
                            vm.onToggleAutoStartLaunchHidden(context),
                      ),
                  ],
                  if (vm.advanced &&
                      checkPlatform([TargetPlatform.windows]))
                    _SwitchRow(
                      label: t.settingsTab.general.showInContextMenu,
                      value: vm.showInContextMenu,
                      onChanged: (_) =>
                          vm.onToggleShowInContextMenu(context),
                    ),
                ],
                _SwitchRow(
                  label: t.settingsTab.general.animations,
                  value: vm.settings.enableAnimations,
                  onChanged: (b) async {
                    await ref
                        .notifier(settingsProvider)
                        .setEnableAnimations(b);
                  },
                ),
                _SwitchRow(
                  label: t.settingsTab.general.lightweightEffects,
                  value: vm.settings.lightweightEffects,
                  onChanged: (b) async {
                    await ref
                        .notifier(settingsProvider)
                        .setLightweightEffects(b);
                  },
                ),
                _SwitchRow(
                  label: t.settingsTab.general.legacyUiMode,
                  value: vm.settings.legacyUiMode,
                  onChanged: (b) async {
                    await ref
                        .notifier(settingsProvider)
                        .setLegacyUiMode(b);
                  },
                ),
              ],
            ),
            _SectionCard(
              title: t.settingsTab.receive.title,
              children: [
                _SwitchRow(
                  label: t.settingsTab.receive.quickSave,
                  value: vm.settings.quickSave,
                  onChanged: (b) async {
                    final old = vm.settings.quickSave;
                    await ref.notifier(settingsProvider).setQuickSave(b);
                    if (!old && b && context.mounted) {
                      await QuickSaveNotice.open(context);
                    }
                  },
                ),
                _SwitchRow(
                  label: t.settingsTab.receive.quickSaveFromFavorites,
                  value: vm.settings.quickSaveFromFavorites,
                  onChanged: (b) async {
                    final old = vm.settings.quickSaveFromFavorites;
                    await ref
                        .notifier(settingsProvider)
                        .setQuickSaveFromFavorites(b);
                    if (!old && b && context.mounted) {
                      await QuickSaveFromFavoritesNotice.open(context);
                    }
                  },
                ),
                _SwitchRow(
                  label: t.settingsTab.receive.requirePin,
                  value: vm.settings.receivePin != null,
                  onChanged: (b) async {
                    final currentPIN = vm.settings.receivePin;
                    if (currentPIN != null) {
                      await ref.notifier(settingsProvider).setReceivePin(null);
                    } else {
                      final String? newPin = await showDialog<String>(
                        context: context,
                        builder: (_) => const PinDialog(
                          obscureText: false,
                          generateRandom: false,
                        ),
                      );

                      if (newPin != null && newPin.isNotEmpty) {
                        await ref
                            .notifier(settingsProvider)
                            .setReceivePin(newPin);
                      }
                    }
                  },
                ),
                if (checkPlatformWithFileSystem())
                  _EntryRow(
                    label: t.settingsTab.receive.destination,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).inputDecorationTheme.fillColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: Theme.of(context)
                                .inputDecorationTheme
                                .borderRadius),
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () async {
                        if (vm.settings.destination != null) {
                          await ref
                              .notifier(settingsProvider)
                              .setDestination(null);
                          if (defaultTargetPlatform ==
                              TargetPlatform.macOS) {
                            await removeExistingDestinationAccess();
                          }
                          return;
                        }

                        final directory =
                            await pickDirectoryPath(context);
                        if (directory != null) {
                          if (defaultTargetPlatform ==
                              TargetPlatform.macOS) {
                            await persistDestinationFolderAccess(directory);
                          }
                          await ref
                              .notifier(settingsProvider)
                              .setDestination(directory);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          vm.settings.destination ??
                              t.settingsTab.receive.downloads,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                if (checkPlatformWithGallery())
                  _SwitchRow(
                    label: t.settingsTab.receive.saveToGallery,
                    value: vm.settings.saveToGallery,
                    onChanged: (b) async {
                      await ref
                          .notifier(settingsProvider)
                          .setSaveToGallery(b);
                    },
                  ),
                _SwitchRow(
                  label: t.settingsTab.receive.autoFinish,
                  value: vm.settings.autoFinish,
                  onChanged: (b) async {
                    await ref
                        .notifier(settingsProvider)
                        .setAutoFinish(b);
                  },
                ),
                _SwitchRow(
                  label: t.settingsTab.receive.openMessageTabOnIncomingFiles,
                  value: openMessageTabOnIncomingFiles,
                  onChanged: (b) async {
                    await ref
                        .notifier(openMessageTabOnIncomingFilesProvider)
                        .setEnabled(b);
                  },
                ),
                _SwitchRow(
                  label: t.settingsTab.receive.saveToHistory,
                  value: vm.settings.saveToHistory,
                  onChanged: (b) async {
                    await ref
                        .notifier(settingsProvider)
                        .setSaveToHistory(b);
                  },
                ),
              ],
            ),
            if (vm.advanced)
              _SectionCard(
                title: t.settingsTab.send.title,
                children: [
                  _SwitchRow(
                    label: t.settingsTab.send.shareViaLinkAutoAccept,
                    value: vm.settings.shareViaLinkAutoAccept,
                    onChanged: (b) async {
                      await ref
                          .notifier(settingsProvider)
                          .setShareViaLinkAutoAccept(b);
                    },
                  ),
                ],
              ),
            _SectionCard(
              title: t.settingsTab.network.title,
              children: [
                if (vm.serverState != null &&
                    (vm.serverState!.alias != vm.settings.alias ||
                        vm.serverState!.port != vm.settings.port ||
                        vm.serverState!.https != vm.settings.https))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      t.settingsTab.network.needRestart,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.warning,
                      ),
                    ),
                  ),
                _EntryRow(
                  label:
                      '${t.settingsTab.network.server}${vm.serverState == null ? ' (${t.general.offline})' : ''}',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (vm.serverState == null)
                        IconButton(
                          tooltip: t.general.start,
                          onPressed: () => vm.onTapStartServer(context),
                          icon: const Icon(Icons.play_arrow),
                        )
                      else
                        IconButton(
                          tooltip: t.general.restart,
                          onPressed: () => vm.onTapRestartServer(context),
                          icon: const Icon(Icons.refresh),
                        ),
                      IconButton(
                        tooltip: t.general.stop,
                        onPressed:
                            vm.serverState == null ? null : vm.onTapStopServer,
                        icon: const Icon(Icons.stop),
                      ),
                    ],
                  ),
                ),
                _EntryRow(
                  label: t.settingsTab.network.alias,
                  child: TextFieldWithActions(
                    name: t.settingsTab.network.alias,
                    controller: vm.aliasController,
                    onChanged: (s) async {
                      await ref.notifier(settingsProvider).setAlias(s);
                    },
                    actions: [
                      Tooltip(
                        message: t.settingsTab.network.generateRandomAlias,
                        child: IconButton(
                          onPressed: () async {
                            final newAlias = generateRandomAlias();
                            vm.aliasController.text = newAlias;
                            await ref
                                .notifier(settingsProvider)
                                .setAlias(newAlias);
                          },
                          icon: const Icon(Icons.casino),
                        ),
                      ),
                      Tooltip(
                        message: t.settingsTab.network.useSystemName,
                        child: IconButton(
                          onPressed: () async {
                            final newAlias = Platform.localHostname;
                            vm.aliasController.text = newAlias;
                            await ref
                                .notifier(settingsProvider)
                                .setAlias(newAlias);
                          },
                          icon: const Icon(Icons.desktop_windows_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vm.advanced)
                  _EntryRow(
                    label: t.settingsTab.network.deviceType,
                    child: CustomDropdownButton<DeviceType>(
                      value: vm.deviceInfo.deviceType,
                      items: DeviceType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          alignment: Alignment.center,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type.icon, size: 20),
                                const SizedBox(width: 8),
                                Text(type.displayName),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (type) async {
                        await ref.notifier(settingsProvider).setDeviceType(type);
                      },
                    ),
                  ),
                if (vm.advanced)
                  _EntryRow(
                    label: t.settingsTab.network.deviceModel,
                    child: TextFieldTv(
                      name: t.settingsTab.network.deviceModel,
                      controller: vm.deviceModelController,
                      onChanged: (s) async {
                        await ref.notifier(settingsProvider).setDeviceModel(s);
                      },
                    ),
                  ),
                if (vm.advanced)
                  _EntryRow(
                    label: t.settingsTab.network.port,
                    child: TextFieldTv(
                      name: t.settingsTab.network.port,
                      controller: vm.portController,
                      onChanged: (s) async {
                        final port = int.tryParse(s);
                        if (port != null) {
                          await ref
                              .notifier(settingsProvider)
                              .setPort(port);
                        }
                      },
                    ),
                  ),
                if (vm.advanced)
                  _EntryRow(
                    label: t.settingsTab.network.network,
                    child: FilledButton(
                      onPressed: () async {
                        await context
                            .push(() => const NetworkInterfacesPage());
                      },
                      child: Text(
                        switch (vm.settings.networkWhitelist != null ||
                                vm.settings.networkBlacklist != null) {
                          true => t.settingsTab.network.networkOptions.filtered,
                          false => t.settingsTab.network.networkOptions.all,
                        },
                      ),
                    ),
                  ),
                if (vm.advanced)
                  _EntryRow(
                    label: t.settingsTab.network.discoveryTimeout,
                    child: TextFieldTv(
                      name: t.settingsTab.network.discoveryTimeout,
                      controller: vm.timeoutController,
                      onChanged: (s) async {
                        final timeout = int.tryParse(s);
                        if (timeout != null) {
                          await ref
                              .notifier(settingsProvider)
                              .setDiscoveryTimeout(timeout);
                        }
                      },
                    ),
                  ),
                if (vm.advanced)
                  _SwitchRow(
                    label: t.settingsTab.network.encryption,
                    value: vm.settings.https,
                    onChanged: (b) async {
                      final old = vm.settings.https;
                      await ref.notifier(settingsProvider).setHttps(b);
                      if (old && !b && context.mounted) {
                        await EncryptionDisabledNotice.open(context);
                      }
                    },
                  ),
                if (vm.advanced)
                  _EntryRow(
                    label: t.settingsTab.network.multicastGroup,
                    child: TextFieldTv(
                      name: t.settingsTab.network.multicastGroup,
                      controller: vm.multicastController,
                      onChanged: (s) async {
                        await ref
                            .notifier(settingsProvider)
                            .setMulticastGroup(s);
                      },
                    ),
                  ),
              ],
            ),
            _SectionCard(
              title: t.settingsTab.other.title,
              children: [
                _EntryRow(
                  label: t.aboutPage.title,
                  child: FilledButton(
                    onPressed: () async {
                      await context.push(() => const AboutPage());
                    },
                    child: Text(t.general.open),
                  ),
                ),
                _EntryRow(
                  label: t.settingsTab.other.privacyPolicy,
                  child: FilledButton(
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (dialogContext) {
                          return PrivacyPolicyDialog(
                            onAccept: () {
                              Navigator.of(dialogContext).pop();
                            },
                            onDecline: () {
                              Navigator.of(dialogContext).pop();
                            },
                          );
                        },
                      );
                    },
                    child: Text(t.general.open),
                  ),
                ),
                if (checkPlatform([TargetPlatform.iOS, TargetPlatform.macOS]))
                  _EntryRow(
                    label: t.settingsTab.other.termsOfUse,
                    child: FilledButton(
                      onPressed: () async {
                        await launchUrl(
                          Uri.parse(
                              'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Text(t.general.open),
                    ),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LabeledCheckbox(
                  label: t.settingsTab.advancedSettings,
                  value: vm.advanced,
                  labelFirst: true,
                  onChanged: (b) async {
                    vm.onTapAdvanced(b == true);
                    await ref
                        .notifier(settingsProvider)
                        .setAdvancedSettingsEnabled(b == true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            ref.watch(versionProvider).maybeWhen(
                  data: (version) => Text(
                    'Version: $version',
                    textAlign: TextAlign.center,
                  ),
                  orElse: () => Container(),
                ),
            Text(
              '© ${DateTime.now().year} AloeSend',
              textAlign: TextAlign.center,
            ),
            Text(
              '基于LocalSend移植开发',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _EntryRow({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          SizedBox(width: 170, child: child),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

extension on ThemeMode {
  String get humanName {
    switch (this) {
      case ThemeMode.system:
        return t.settingsTab.general.brightnessOptions.system;
      case ThemeMode.light:
        return t.settingsTab.general.brightnessOptions.light;
      case ThemeMode.dark:
        return t.settingsTab.general.brightnessOptions.dark;
    }
  }
}

extension on ColorMode {
  String get humanName {
    return switch (this) {
      ColorMode.system => t.settingsTab.general.colorOptions.system,
      ColorMode.localsend => 'AloeSend',
      ColorMode.oled => t.settingsTab.general.colorOptions.oled,
      ColorMode.yaru => 'Yaru',
    };
  }
}
