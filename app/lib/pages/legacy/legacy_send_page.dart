import 'dart:async';

import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class LegacySendPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const LegacySendPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
    super.key,
  });

  @override
  State<LegacySendPage> createState() => _LegacySendPageState();
}

class _LegacySendPageState extends State<LegacySendPage> with Refena {
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
    Translations.of(context);
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
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: const SizedBox(),
      );
    }

    final myDevice = ref.watch(deviceFullInfoProvider);
    final targetDevice = sendState?.target ?? _targetDevice!;
    final targetFavoriteEntry = ref.watch(
      favoritesProvider.select((state) => state.findDevice(targetDevice)),
    );
    final waiting = sendState?.status == SessionStatus.waiting;

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop && widget.closeSessionOnClose) {
          _cancel();
        }
      },
      canPop: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: widget.showAppBar ? AppBar() : null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LegacyDeviceTile(device: myDevice),
                const SizedBox(height: 10),
                const Icon(Icons.arrow_downward),
                const SizedBox(height: 10),
                LegacyDeviceTile(
                  device: targetDevice,
                  nameOverride: targetFavoriteEntry?.alias,
                ),
                const Spacer(),
                if (sendState != null)
                  Column(
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
                      if (sendState.status == SessionStatus.waiting)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(t.sendPage.waiting),
                        ),
                      FilledButton.icon(
                        onPressed: () async {
                          await _cancelWithStopBgTask();
                          if (context.mounted) {
                            context.pop();
                          }
                        },
                        icon: Icon(waiting ? Icons.close : Icons.check_circle),
                        label: Text(waiting ? t.general.cancel : t.general.close),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LegacyDeviceTile extends StatelessWidget {
  final Device device;
  final String? nameOverride;

  const LegacyDeviceTile({
    required this.device,
    this.nameOverride,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(device.deviceType.icon),
        title: Text(nameOverride ?? device.alias),
        subtitle: Text('#${device.ip.visualId}'),
      ),
    );
  }
}
