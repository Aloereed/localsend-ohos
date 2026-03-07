import 'dart:async';

import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SendPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const SendPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
    super.key,
  });

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> with Refena {
  Device? _myDevice;
  Device? _targetDevice;

  @override
  void initState() {
    super.initState();
    unawaited(_startContinuousTask());
  }

  @override
  void dispose() {
    super.dispose();
    unawaited(TaskbarHelper.clearProgressBar());
  }

  Future<void> _startContinuousTask() async {
    const platform = MethodChannel('samples.flutter.dev/downloadplugin');
    await platform.invokeMethod<String>('startContinuousTask');
  }

  Future<void> _stopContinuousTask() async {
    const platform = MethodChannel('samples.flutter.dev/downloadplugin');
    await platform.invokeMethod<String>('stopContinuousTask');
  }

  void _cancel() {
    final myDevice = ref.read(deviceFullInfoProvider);
    final sendState = ref.read(sendProvider)[widget.sessionId];
    if (sendState == null) {
      return;
    }

    setState(() {
      _myDevice = myDevice;
      _targetDevice = sendState.target;
    });
    ref.notifier(sendProvider).cancelSession(widget.sessionId);
  }

  Future<void> _cancelWithStopBgTask() async {
    final myDevice = ref.read(deviceFullInfoProvider);
    final sendState = ref.read(sendProvider)[widget.sessionId];
    if (sendState == null) {
      return;
    }

    setState(() {
      _myDevice = myDevice;
      _targetDevice = sendState.target;
    });
    ref.notifier(sendProvider).cancelSession(widget.sessionId);
    await _stopContinuousTask();
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(
      sendProvider.select((state) => state[widget.sessionId]),
      listener: (prev, next) {
        final prevStatus = prev[widget.sessionId]?.status;
        final nextStatus = next[widget.sessionId]?.status;
        if (prevStatus != nextStatus) {
          TaskbarHelper.visualizeStatus(nextStatus);
        }
      },
    );

    if (sendState == null && _myDevice == null && _targetDevice == null) {
      return const Scaffold(backgroundColor: Colors.transparent, body: SizedBox());
    }

    final myDevice = ref.watch(deviceFullInfoProvider);
    final targetDevice = sendState?.target ?? _targetDevice!;
    final targetFavoriteEntry = ref.watch(
      favoritesProvider.select((state) => state.findDevice(targetDevice)),
    );
    final waiting = sendState?.status == SessionStatus.waiting;
    final sectionSpacing = context.adaptiveSectionSpacing;

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop && widget.closeSessionOnClose) {
          _cancel();
        }
      },
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.showAppBar
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
              )
            : null,
        body: AppBackdrop(
          child: SafeArea(
            top: !widget.showAppBar,
            child: ResponsiveListView(
              maxWidth: 860,
              padding: EdgeInsets.fromLTRB(
                context.adaptiveHorizontalPadding,
                context.adaptiveTopPadding,
                context.adaptiveHorizontalPadding,
                context.adaptiveBottomPadding,
              ),
              children: [
                ModernPageHeader(
                  title: waiting ? t.sendPage.waiting : t.sendTab.title,
                  subtitle: targetFavoriteEntry?.alias ?? targetDevice.alias,
                  trailing: widget.showAppBar
                      ? null
                      : IconButton(
                          tooltip: waiting ? t.general.cancel : t.general.close,
                          onPressed: () async {
                            await _cancelWithStopBgTask();
                            if (context.mounted) {
                              context.pop();
                            }
                          },
                          icon: Icon(
                            waiting ? Icons.close_rounded : Icons.check_circle_rounded,
                          ),
                        ),
                  chips: [
                    StatusChip(
                      label: _statusLabel(sendState?.status),
                      icon: _statusIcon(sendState?.status),
                      emphasized: true,
                      color: _statusColor(context, sendState?.status),
                    ),
                  ],
                ),
                SizedBox(height: sectionSpacing),
                GlassSectionCard(
                  title: t.sendPage.route.title,
                  subtitle: t.sendPage.route.subtitle,
                  strong: true,
                  child: Column(
                    children: [
                      DeviceListTile(device: myDevice),
                      SizedBox(height: context.isPhoneLayout ? 16 : 22),
                      Container(
                        width: context.isPhoneLayout ? 48 : 56,
                        height: context.isPhoneLayout ? 48 : 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          size: context.isPhoneLayout ? 22 : 24,
                        ),
                      ),
                      SizedBox(height: context.isPhoneLayout ? 16 : 22),
                      Hero(
                        tag: 'device-${targetDevice.ip}',
                        child: DeviceListTile(
                          device: targetDevice,
                          nameOverride: targetFavoriteEntry?.alias,
                        ),
                      ),
                    ],
                  ),
                ),
                if (sendState != null) ...[
                  SizedBox(height: sectionSpacing),
                  GlassSectionCard(
                    title: t.sendPage.status.title,
                    subtitle: _statusDescription(sendState.status),
                    child: Column(
                      children: [
                        if (sendState.status == SessionStatus.finishedWithErrors &&
                            sendState.errorMessage != null)
                          TextButton.icon(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (_) => ErrorDialog(
                                  error: sendState.errorMessage!,
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline_rounded),
                            label: Text(t.general.error),
                          ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            await _cancelWithStopBgTask();
                            if (context.mounted) {
                              context.pop();
                            }
                          },
                          icon: Icon(
                            waiting ? Icons.close_rounded : Icons.check_circle_rounded,
                          ),
                          label: Text(waiting ? t.general.cancel : t.general.close),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(SessionStatus? status) {
    switch (status) {
      case SessionStatus.waiting:
        return t.sendPage.waiting;
      case SessionStatus.declined:
        return t.sendPage.rejected;
      case SessionStatus.tooManyAttempts:
        return t.sendPage.tooManyAttempts;
      case SessionStatus.recipientBusy:
        return t.sendPage.busy;
      case SessionStatus.finishedWithErrors:
        return t.general.error;
      case SessionStatus.sending:
        return t.progressPage.titleSending;
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        return t.sendPage.status.canceled;
      case null:
        return t.sendTab.title;
    }
  }

  String _statusDescription(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return t.sendPage.status.waiting;
      case SessionStatus.declined:
        return t.sendPage.status.declined;
      case SessionStatus.tooManyAttempts:
        return t.sendPage.status.tooManyAttempts;
      case SessionStatus.recipientBusy:
        return t.sendPage.status.busy;
      case SessionStatus.finishedWithErrors:
        return t.sendPage.status.finishedWithErrors;
      case SessionStatus.sending:
        return t.sendPage.status.sending;
      case SessionStatus.finished:
        return t.sendPage.status.finished;
      case SessionStatus.canceledBySender:
        return t.sendPage.status.canceledBySender;
      case SessionStatus.canceledByReceiver:
        return t.sendPage.status.canceledByReceiver;
    }
  }

  IconData _statusIcon(SessionStatus? status) {
    switch (status) {
      case SessionStatus.waiting:
        return Icons.hourglass_top_rounded;
      case SessionStatus.declined:
      case SessionStatus.tooManyAttempts:
      case SessionStatus.recipientBusy:
      case SessionStatus.finishedWithErrors:
        return Icons.error_outline_rounded;
      case SessionStatus.finished:
        return Icons.check_circle_rounded;
      case SessionStatus.sending:
        return Icons.sync_rounded;
      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        return Icons.cancel_rounded;
      case null:
        return Icons.send_rounded;
    }
  }

  Color _statusColor(BuildContext context, SessionStatus? status) {
    switch (status) {
      case SessionStatus.declined:
      case SessionStatus.tooManyAttempts:
      case SessionStatus.recipientBusy:
      case SessionStatus.finishedWithErrors:
      case SessionStatus.canceledBySender:
      case SessionStatus.canceledByReceiver:
        return Theme.of(context).colorScheme.warning;
      case SessionStatus.finished:
        return Theme.of(context).colorScheme.primary;
      case SessionStatus.waiting:
      case SessionStatus.sending:
      case null:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
