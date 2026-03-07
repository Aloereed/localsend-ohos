import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/pages/selected_files_page.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/pages/troubleshoot_page.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/dialogs/add_file_dialog.dart';
import 'package:localsend_app/widget/dialogs/send_mode_help_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:localsend_app/widget/list_tile/device_placeholder_list_tile.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/opacity_slideshow.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

final _options = FilePickerOption.getOptionsForPlatform();

class SendTab extends StatelessWidget {
  const SendTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: sendTabVmProvider,
      init: (context) async => context.global.dispatchAsync(
        SendTabInitAction(context),
      ),
      builder: (context, vm) {
        final visuals = context.visuals;
        final sectionSpacing = context.adaptiveSectionSpacing;
        return ResponsiveListView(
          maxWidth: 920,
          padding: EdgeInsets.fromLTRB(
            context.adaptiveHorizontalPadding,
            context.adaptiveTopPadding,
            context.adaptiveHorizontalPadding,
            context.adaptiveBottomPadding,
          ),
          children: [
            ModernPageHeader(
              title: t.sendTab.title,
              subtitle: vm.selectedFiles.isEmpty
                  ? t.sendTab.selection.title
                  : t.sendTab.selection.files(files: vm.selectedFiles.length),
              chips: [
                StatusChip(
                  label: vm.sendMode.humanName,
                  icon: Icons.send_time_extension_rounded,
                  emphasized: true,
                  color: Theme.of(context).colorScheme.primary,
                ),
                StatusChip(
                  label: vm.nearbyDevices.isEmpty
                      ? t.general.offline
                      : '${vm.nearbyDevices.length} ${t.sendTab.nearbyDevices}',
                  icon: Icons.devices_rounded,
                ),
                if (vm.selectedFiles.isNotEmpty)
                  StatusChip(
                    label: vm.selectedFiles
                        .fold<int>(0, (prev, curr) => prev + curr.size)
                        .asReadableFileSize,
                    icon: Icons.storage_rounded,
                  ),
              ],
            ),
            SizedBox(height: sectionSpacing),
            _SelectionSection(vm: vm),
            SizedBox(height: sectionSpacing),
            _NearbyDevicesSection(vm: vm),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _SelectionSection extends StatelessWidget {
  final SendTabVm vm;

  const _SelectionSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final totalSize =
        vm.selectedFiles.fold<int>(0, (prev, curr) => prev + curr.size);

    return GlassSectionCard(
      title: t.sendTab.selection.title,
      subtitle: vm.selectedFiles.isEmpty
          ? t.sendTab.help
          : t.sendTab.selection.size(size: totalSize.asReadableFileSize),
      strong: true,
      trailing: vm.selectedFiles.isEmpty
          ? null
          : IconButton(
              tooltip: t.general.close,
              onPressed: () => context
                  .redux(selectedSendingFilesProvider)
                  .dispatch(ClearSelectionAction()),
              icon: const Icon(Icons.close_rounded),
            ),
      child: vm.selectedFiles.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 640;
                final tiles = _options.map((option) {
                  return ModernActionTile(
                    icon: option.icon,
                    title: option.label,
                    subtitle: t.sendTab.selection.title,
                    highlighted: option == _options.first,
                    onTap: () async => ref.global.dispatchAsync(
                      PickFileAction(option: option, context: context),
                    ),
                  );
                }).toList();

                if (compact) {
                  return Column(
                    children: [
                      for (var index = 0; index < tiles.length; index++) ...[
                        SizedBox(width: double.infinity, child: tiles[index]),
                        if (index != tiles.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: tiles
                      .map(
                        (tile) => SizedBox(
                          width: 260,
                          child: tile,
                        ),
                      )
                      .toList(),
                );
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StatusChip(
                      label: t.sendTab.selection.files(
                        files: vm.selectedFiles.length,
                      ),
                      icon: Icons.collections_bookmark_rounded,
                    ),
                    StatusChip(
                      label: totalSize.asReadableFileSize,
                      icon: Icons.data_usage_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: defaultThumbnailSize + (context.isPhoneLayout ? 8 : 20),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: vm.selectedFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final file = vm.selectedFiles[index];
                      return GlassSurface(
                        padding: const EdgeInsets.all(10),
                        applyBlur: false,
                        borderRadius: context.visuals.mediumRadius,
                        child: SmartFileThumbnail.fromCrossFile(file),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await context.push(() => const SelectedFilesPage());
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(t.general.edit),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        if (_options.length == 1) {
                          await ref.global.dispatchAsync(
                            PickFileAction(option: _options.first, context: context),
                          );
                          return;
                        }
                        await AddFileDialog.open(
                          context: context,
                          options: _options,
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(t.general.add),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _NearbyDevicesSection extends StatelessWidget {
  final SendTabVm vm;

  const _NearbyDevicesSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return GlassSectionCard(
      title: t.sendTab.nearbyDevices,
      subtitle: t.sendTab.help,
      trailing: Wrap(
        spacing: 8,
        children: [
          _ScanButton(ips: vm.localIps),
          IconButton(
            tooltip: t.sendTab.manualSending,
            onPressed: () async => vm.onTapAddress(context),
            icon: const Icon(Icons.ads_click_rounded),
          ),
          IconButton(
            tooltip: t.dialogs.favoriteDialog.title,
            onPressed: () async => vm.onTapFavorite(context),
            icon: const Icon(Icons.favorite_rounded),
          ),
          _SendModeButton(
            onSelect: (mode) async => vm.onTapSendMode(context, mode),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vm.nearbyDevices.isEmpty)
            const Opacity(
              opacity: 0.42,
              child: DevicePlaceholderListTile(),
            )
          else
            ...vm.nearbyDevices.map((device) {
              final favoriteEntry = vm.favoriteDevices.findDevice(device);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Hero(
                  tag: 'device-${device.ip}',
                  child: vm.sendMode == SendMode.multiple
                      ? _MultiSendDeviceListTile(
                          device: device,
                          isFavorite: favoriteEntry != null,
                          nameOverride: favoriteEntry?.alias,
                          vm: vm,
                        )
                      : DeviceListTile(
                          device: device,
                          isFavorite: favoriteEntry != null,
                          nameOverride: favoriteEntry?.alias,
                          onFavoriteTap: () async =>
                              vm.onToggleFavorite(context, device),
                          onTap: () async => vm.onTapDevice(context, device),
                        ),
                ),
              );
            }),
          SizedBox(height: context.adaptiveSectionSpacing - 2),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await context.push(() => const TroubleshootPage());
                },
                icon: const Icon(Icons.build_circle_rounded),
                label: Text(t.troubleshootPage.title),
              ),
              Consumer(
                builder: (context, ref) {
                  final animations = ref.watch(animationProvider);
                  return SizedBox(
                    width: context.isPhoneLayout ? double.infinity : 320,
                    child: OpacitySlideshow(
                      durationMillis: 6000,
                      running: animations,
                      children: [
                        Text(
                          t.sendTab.help,
                          style: TextStyle(color: visuals.mutedForeground),
                          textAlign: TextAlign.left,
                        ),
                        if (checkPlatformCanReceiveShareIntent())
                          Text(
                            t.sendTab.shareIntentInfo,
                            style: TextStyle(color: visuals.mutedForeground),
                            textAlign: TextAlign.left,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularPopupButton<T> extends StatelessWidget {
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget child;

  const _CircularPopupButton({
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      offset: const Offset(0, 46),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      child: child,
    );
  }
}

class _ScanButton extends StatelessWidget {
  final List<String> ips;

  const _ScanButton({required this.ips});

  @override
  Widget build(BuildContext context) {
    final (scanningFavorites, scanningIps) = context.ref.watch(
      nearbyDevicesProvider.select((s) => (s.runningFavoriteScan, s.runningIps)),
    );
    final animations = context.ref.watch(animationProvider);
    final spinning = (scanningFavorites || scanningIps.isNotEmpty) && animations;
    final iconColor = !animations && scanningIps.isNotEmpty
        ? Theme.of(context).colorScheme.warning
        : null;

    Widget button(VoidCallback onPressed) {
      return Tooltip(
        message: t.sendTab.scan,
        child: RotatingWidget(
          duration: const Duration(seconds: 2),
          spinning: spinning,
          reverse: true,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(Icons.sync_rounded, color: iconColor),
          ),
        ),
      );
    }

    if (ips.length <= StartSmartScan.maxInterfaces) {
      return button(() async {
        context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
        await context.global.dispatchAsync(StartSmartScan(forceLegacy: true));
      });
    }

    return _CircularPopupButton<String>(
      tooltip: t.sendTab.scan,
      onSelected: (ip) async {
        context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
        await context.global.dispatchAsync(StartLegacySubnetScan(subnets: [ip]));
      },
      itemBuilder: (_) {
        return [
          ...ips.map(
            (ip) => PopupMenuItem<String>(
              value: ip,
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RotatingSyncIcon(ip),
                  const SizedBox(width: 10),
                  Text(ip),
                ],
              ),
            ),
          ),
        ];
      },
      child: Tooltip(
        message: t.sendTab.scan,
        child: RotatingWidget(
          duration: const Duration(seconds: 2),
          spinning: spinning,
          reverse: true,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.sync_rounded, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _RotatingSyncIcon extends StatelessWidget {
  final String ip;

  const _RotatingSyncIcon(this.ip);

  @override
  Widget build(BuildContext context) {
    final animations = context.ref.watch(animationProvider);
    final spinning = context.ref.watch(
      nearbyDevicesProvider.select(
        (s) => s.runningIps.contains(ip),
      ),
    );
    final warning = !animations && spinning;

    return RotatingWidget(
      duration: const Duration(seconds: 2),
      spinning: spinning && animations,
      reverse: true,
      child: Icon(
        Icons.sync,
        color: warning ? Theme.of(context).colorScheme.warning : null,
      ),
    );
  }
}

class _SendModeButton extends StatelessWidget {
  final Future<void> Function(SendMode mode) onSelect;

  const _SendModeButton({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _CircularPopupButton<int>(
      tooltip: t.sendTab.sendMode,
      onSelected: (value) async {
        switch (value) {
          case -1:
            await showDialog(
              context: context,
              builder: (_) => const SendModeHelpDialog(),
            );
            return;
          case 0:
            await onSelect(SendMode.single);
            return;
          case 1:
            await onSelect(SendMode.multiple);
            return;
          case 2:
            await onSelect(SendMode.link);
            return;
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<int>>[
        PopupMenuItem<int>(
          value: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode =
                      ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.single,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.single),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode =
                      ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.multiple,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.multiple),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Icon(Icons.check_circle),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.link),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: -1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.help),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModeHelp),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.tune_rounded),
      ),
    );
  }
}

class _MultiSendDeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;
  final String? nameOverride;
  final SendTabVm vm;

  const _MultiSendDeviceListTile({
    required this.device,
    required this.isFavorite,
    required this.nameOverride,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final session =
        ref.watch(sendProvider).values.firstWhereOrNull((s) => s.target.ip == device.ip);
    final double? progress;
    if (session != null) {
      final files = session.files.values.where((f) => f.token != null);
      final progressNotifier = ref.watch(progressProvider);
      final currBytes = files.fold<int>(
        0,
        (prev, curr) =>
            prev +
            ((progressNotifier.getProgress(
                      sessionId: session.sessionId,
                      fileId: curr.file.id,
                    ) *
                    curr.file.size)
                .round()),
      );
      final totalBytes = files.fold<int>(0, (prev, curr) => prev + curr.file.size);
      progress = totalBytes == 0 ? 0 : currBytes / totalBytes;
    } else {
      progress = null;
    }
    return DeviceListTile(
      device: device,
      info: session?.status.humanString,
      progress: progress,
      isFavorite: isFavorite,
      nameOverride: nameOverride,
      onFavoriteTap: () async => vm.onToggleFavorite(context, device),
      onTap: () async => vm.onTapDeviceMultiSend(context, device),
    );
  }
}

extension on SendMode {
  String get humanName {
    switch (this) {
      case SendMode.single:
        return t.sendTab.sendModes.single;
      case SendMode.multiple:
        return t.sendTab.sendModes.multiple;
      case SendMode.link:
        return t.sendTab.sendModes.link;
    }
  }
}

extension on SessionStatus {
  String? get humanString {
    switch (this) {
      case SessionStatus.waiting:
        return t.sendPage.waiting;
      case SessionStatus.recipientBusy:
        return t.sendPage.busy;
      case SessionStatus.declined:
        return t.sendPage.rejected;
      case SessionStatus.tooManyAttempts:
        return t.sendPage.tooManyAttempts;
      case SessionStatus.sending:
        return null;
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.total.title.finishedError;
      case SessionStatus.canceledBySender:
        return t.progressPage.total.title.canceledSender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.total.title.canceledReceiver;
    }
  }
}
