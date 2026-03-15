import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/pages/selected_files_page.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/pages/troubleshoot_page.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/widget/big_button.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/dialogs/add_file_dialog.dart';
import 'package:localsend_app/widget/dialogs/send_mode_help_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/horizontal_clip_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

const _horizontalPadding = 15.0;
const _actionButtonSize = 40.0;
const _actionIconSize = 24.0;
const _actionIconPadding = EdgeInsets.all(8);
const _actionButtonConstraints = BoxConstraints.tightFor(
  width: _actionButtonSize,
  height: _actionButtonSize,
);
final _options = FilePickerOption.getOptionsForPlatform();

class LegacySendTab extends StatelessWidget {
  const LegacySendTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: sendTabVmProvider,
      init: (context) async =>
          context.global.dispatchAsync(SendTabInitAction(context)),
      builder: (context, vm) {
        Translations.of(context);
        final ref = context.ref;
        return ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            const SizedBox(height: 16),
            if (vm.selectedFiles.isEmpty) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                child: Text(
                  t.sendTab.selection.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              HorizontalClipListView(
                outerHorizontalPadding: 15,
                outerVerticalPadding: 10,
                childPadding: 10,
                minChildWidth: BigButton.mobileWidth,
                children: _options.map((option) {
                  return BigButton(
                    icon: option.icon,
                    label: option.label,
                    filled: false,
                    onTap: () async => ref.global.dispatchAsync(PickFileAction(
                      option: option,
                      context: context,
                    )),
                  );
                }).toList(),
              ),
            ] else ...[
              Card(
                margin: const EdgeInsets.only(
                    bottom: 10,
                    left: _horizontalPadding,
                    right: _horizontalPadding),
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.only(start: 15, top: 5, bottom: 15, end: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t.sendTab.selection.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => ref
                                .redux(selectedSendingFilesProvider)
                                .dispatch(ClearSelectionAction()),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(t.sendTab.selection.files(
                          files: vm.selectedFiles.length)),
                      Text(t.sendTab.selection.size(
                          size: vm.selectedFiles
                              .fold<int>(0, (prev, curr) => prev + curr.size)
                              .asReadableFileSize)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: defaultThumbnailSize,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: vm.selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = vm.selectedFiles[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: SmartFileThumbnail.fromCrossFile(file),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await context.push(() => const SelectedFilesPage());
                            },
                            child: Text(t.general.edit),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (_options.length == 1) {
                                await ref.global.dispatchAsync(PickFileAction(
                                  option: _options.first,
                                  context: context,
                                ));
                                return;
                              }
                              await AddFileDialog.open(
                                context: context,
                                options: _options,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: Text(t.general.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: _horizontalPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.sendTab.nearbyDevices,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _ScanButton(ips: vm.localIps),
                  IconButton(
                    tooltip: t.sendTab.manualSending,
                    onPressed: () async => vm.onTapAddress(context),
                    icon: const Icon(Icons.ads_click),
                    iconSize: _actionIconSize,
                    padding: _actionIconPadding,
                    constraints: _actionButtonConstraints,
                  ),
                  IconButton(
                    tooltip: t.dialogs.favoriteDialog.title,
                    onPressed: () async => vm.onTapFavorite(context),
                    icon: const Icon(Icons.favorite),
                    iconSize: _actionIconSize,
                    padding: _actionIconPadding,
                    constraints: _actionButtonConstraints,
                  ),
                  _SendModeButton(
                    onSelect: (mode) async =>
                        vm.onTapSendMode(context, mode),
                  ),
                ],
              ),
            ),
            if (vm.nearbyDevices.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: _horizontalPadding, vertical: 10),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(t.sendTab.help, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ...vm.nearbyDevices.map((device) {
              final favoriteEntry = vm.favoriteDevices.findDevice(device);
              return Padding(
                padding: const EdgeInsets.only(
                    bottom: 10,
                    left: _horizontalPadding,
                    right: _horizontalPadding),
                child: LegacyDeviceTile(
                  device: device,
                  isFavorite: favoriteEntry != null,
                  nameOverride: favoriteEntry?.alias,
                  onFavoriteTap: () async =>
                      await vm.onToggleFavorite(context, device),
                  onTap: () async => vm.sendMode == SendMode.multiple
                      ? await vm.onTapDeviceMultiSend(context, device)
                      : await vm.onTapDevice(context, device),
                ),
              );
            }),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () async {
                  await context.push(() => const TroubleshootPage());
                },
                child: Text(t.troubleshootPage.title),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScanButton extends StatelessWidget {
  final List<String> ips;

  const _ScanButton({required this.ips});

  @override
  Widget build(BuildContext context) {
    if (ips.length <= StartSmartScan.maxInterfaces) {
      return IconButton(
        tooltip: t.sendTab.scan,
        onPressed: () async {
          context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
          await context.global.dispatchAsync(StartSmartScan(forceLegacy: true));
        },
        icon: const Icon(Icons.sync),
        iconSize: _actionIconSize,
        padding: _actionIconPadding,
        constraints: _actionButtonConstraints,
      );
    }

    return SizedBox(
      width: _actionButtonSize,
      height: _actionButtonSize,
      child: PopupMenuButton<String>(
        tooltip: t.sendTab.scan,
        onSelected: (ip) async {
          context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
          await context.global.dispatchAsync(StartLegacySubnetScan(subnets: [ip]));
        },
        itemBuilder: (_) {
          return [
            ...ips.map(
              (ip) => PopupMenuItem(
                value: ip,
                child: Text(ip),
              ),
            ),
          ];
        },
        padding: _actionIconPadding,
        iconSize: _actionIconSize,
        icon: const Icon(Icons.sync),
      ),
    );
  }
}

class _SendModeButton extends StatelessWidget {
  final void Function(SendMode mode) onSelect;

  const _SendModeButton({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _actionButtonSize,
      height: _actionButtonSize,
      child: PopupMenuButton<int>(
        tooltip: t.sendTab.sendMode,
        onSelected: (mode) async {
          switch (mode) {
            case 0:
              onSelect(SendMode.single);
              break;
            case 1:
              onSelect(SendMode.multiple);
              break;
            case 2:
              onSelect(SendMode.link);
              break;
            case -1:
              await showDialog(
                context: context,
                builder: (_) => const SendModeHelpDialog(),
              );
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 0,
            child: Row(
              children: [
                Consumer(
                  builder: (context, ref) {
                    final sendMode = ref.watch(
                      settingsProvider.select((s) => s.sendMode),
                    );
                    return Visibility(
                      visible: sendMode == SendMode.single,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: const Icon(Icons.check_circle),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(t.sendTab.sendModes.single),
              ],
            ),
          ),
          PopupMenuItem(
            value: 1,
            child: Row(
              children: [
                Consumer(
                  builder: (context, ref) {
                    final sendMode = ref.watch(
                      settingsProvider.select((s) => s.sendMode),
                    );
                    return Visibility(
                      visible: sendMode == SendMode.multiple,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: const Icon(Icons.check_circle),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(t.sendTab.sendModes.multiple),
              ],
            ),
          ),
          PopupMenuItem(
            value: 2,
            child: Row(
              children: [
                const Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Icon(Icons.check_circle),
                ),
                const SizedBox(width: 8),
                Text(t.sendTab.sendModes.link),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: -1,
            child: Row(
              children: [
                const Icon(Icons.help),
                const SizedBox(width: 8),
                Text(t.sendTab.sendModeHelp),
              ],
            ),
          ),
        ],
        padding: _actionIconPadding,
        iconSize: _actionIconSize,
        icon: const Icon(Icons.settings),
      ),
    );
  }
}

class LegacyDeviceTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;
  final String? nameOverride;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final String? info;

  const LegacyDeviceTile({
    required this.device,
    this.isFavorite = false,
    this.nameOverride,
    this.onTap,
    this.onFavoriteTap,
    this.info,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.ref
        .watch(sendProvider)
        .values
        .firstWhereOrNull((s) => s.target.ip == device.ip);
    final double? resolvedProgress;
    String? resolvedInfo = info;
    if (session != null) {
      if (session.status == SessionStatus.waiting) {
        resolvedInfo = t.sendPage.waiting;
        resolvedProgress = null;
      } else if (session.status == SessionStatus.sending) {
        final files = session.files.values.where((f) => f.token != null);
        final progressNotifier = context.ref.watch(progressProvider);
        final currBytes = files.fold<int>(
            0,
            (prev, curr) =>
                prev +
                ((progressNotifier.getProgress(
                            sessionId: session.sessionId, fileId: curr.file.id) *
                        curr.file.size)
                    .round()));
        final totalBytes =
            files.fold<int>(0, (prev, curr) => prev + curr.file.size);
        resolvedProgress = totalBytes == 0 ? 0 : currBytes / totalBytes;
      } else {
        resolvedInfo = session.status.humanString ?? t.general.finished;
        resolvedProgress = null;
      }
    } else {
      resolvedProgress = null;
    }

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(nameOverride ?? device.alias),
        subtitle: resolvedProgress != null
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CustomProgressBar(progress: resolvedProgress),
              )
            : resolvedInfo != null
                ? Text(resolvedInfo)
                : Text(
                    '#${device.ip.visualId}${device.deviceModel != null ? ' · ${device.deviceModel}' : ''}',
                  ),
        trailing: onFavoriteTap != null
            ? IconButton(
                icon: Icon(isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border),
                onPressed: onFavoriteTap,
              )
            : null,
      ),
    );
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
