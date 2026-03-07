import 'package:common/util/sleep.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/state/send/web/web_send_session.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/qr_dialog.dart';
import 'package:localsend_app/widget/dialogs/zoom_dialog.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _ServerState { initializing, running, error, stopping }

class WebSendPage extends StatefulWidget {
  final List<CrossFile> files;

  const WebSendPage(this.files);

  @override
  State<WebSendPage> createState() => _WebSendPageState();
}

class _WebSendPageState extends State<WebSendPage> with Refena {
  _ServerState _stateEnum = _ServerState.initializing;
  bool _encrypted = false;
  String? _initializedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init(encrypted: false);
    });
  }

  void _init({required bool encrypted}) async {
    final settings = ref.read(settingsProvider);
    final (beforeAutoAccept, beforePin) = ref.read(
      serverProvider.select(
        (state) => (state?.webSendState?.autoAccept, state?.webSendState?.pin),
      ),
    );
    setState(() {
      _stateEnum = _ServerState.initializing;
      _encrypted = encrypted;
      _initializedError = null;
    });
    await sleepAsync(500);
    try {
      await ref.notifier(serverProvider).restartServer(
            alias: settings.alias,
            port: settings.port,
            https: _encrypted,
          );
      await ref.notifier(serverProvider).initializeWebSend(widget.files);
      if (beforeAutoAccept != null) {
        ref.notifier(serverProvider).setWebSendAutoAccept(beforeAutoAccept);
      }
      ref.notifier(serverProvider).setWebSendPin(beforePin);
      setState(() {
        _stateEnum = _ServerState.running;
      });
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _stateEnum = _ServerState.error;
          _initializedError = e.toString();
        });
      }
    }
  }

  Future<void> _revertServerState() async {
    await ref.notifier(serverProvider).restartServerFromSettings();
  }

  Future<void> _handleClose(BuildContext context) async {
    if (_stateEnum == _ServerState.initializing ||
        _stateEnum == _ServerState.stopping) {
      return;
    }

    if (_stateEnum == _ServerState.running) {
      setState(() {
        _stateEnum = _ServerState.stopping;
      });
      await sleepAsync(250);
      await _revertServerState();
      await sleepAsync(250);
    }

    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (_) async {
        await _handleClose(context);
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          child: SafeArea(
            child: Builder(
              builder: (context) {
                if (_stateEnum != _ServerState.running) {
                  return _StateView(
                    state: _stateEnum,
                    encrypted: _encrypted,
                    initializedError: _initializedError,
                    onClose: () async => _handleClose(context),
                    onRetry: () => _init(encrypted: _encrypted),
                    fileCount: widget.files.length,
                  );
                }

                final serverState = context.watch(serverProvider)!;
                final webSendState = serverState.webSendState!;
                final networkState = context.watch(localIpProvider);
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
                      title: t.webSharePage.title,
                      subtitle: t.webSharePage.openLink(
                        n: networkState.localIps.length,
                      ),
                      trailing: IconButton(
                        tooltip: t.general.close,
                        onPressed: () async => _handleClose(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      chips: [
                        StatusChip(
                          label: _encrypted
                              ? t.webSharePage.protocol.https
                              : t.webSharePage.protocol.http,
                          icon: _encrypted
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          emphasized: true,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        StatusChip(
                          label: t.webSharePage.filesCount(
                            n: widget.files.length,
                          ),
                          icon: Icons.folder_zip_rounded,
                        ),
                        StatusChip(
                          label: '${webSendState.sessions.length} ${t.webSharePage.requests}',
                          icon: Icons.devices_rounded,
                        ),
                      ],
                    ),
                    SizedBox(height: sectionSpacing),
                    GlassSectionCard(
                      title: t.webSharePage.shareLinks.title,
                      subtitle: t.webSharePage.shareLinks.subtitle,
                      strong: true,
                      child: Column(
                        children: [
                          for (var index = 0;
                              index < networkState.localIps.length;
                              index++) ...[
                            _WebLinkCard(
                              ip: networkState.localIps[index],
                              port: serverState.port,
                              encrypted: _encrypted,
                              pin: webSendState.pin,
                            ),
                            if (index != networkState.localIps.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: sectionSpacing),
                    GlassSectionCard(
                      title: t.webSharePage.requests,
                      subtitle: webSendState.sessions.isEmpty
                          ? t.webSharePage.noRequests
                          : t.webSharePage.activeRequests(
                              n: webSendState.sessions.length,
                            ),
                      child: webSendState.sessions.isEmpty
                          ? const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.hourglass_empty_rounded, size: 48),
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final entries = webSendState.sessions.entries.toList();
                                return Column(
                                  children: [
                                    for (var index = 0; index < entries.length; index++) ...[
                                      _WebRequestCard(session: entries[index].value),
                                      if (index != entries.length - 1)
                                        const SizedBox(height: 12),
                                    ],
                                  ],
                                );
                              },
                            ),
                    ),
                    SizedBox(height: sectionSpacing),
                    GlassSectionCard(
                      title: t.webSharePage.optionsCard.title,
                      subtitle: t.webSharePage.optionsCard.subtitle,
                      child: Column(
                        children: [
                          _OptionRow(
                            label: t.webSharePage.encryption,
                            value: _encrypted,
                            onChanged: (value) {
                              _init(encrypted: value == true);
                            },
                          ),
                          if (_encrypted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  t.webSharePage.encryptionHint,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .warning,
                                      ),
                                ),
                              ),
                            ),
                          _OptionRow(
                            label: t.webSharePage.autoAccept,
                            value: webSendState.autoAccept,
                            onChanged: (value) {
                              ref.notifier(serverProvider).setWebSendAutoAccept(
                                    value == true,
                                  );
                            },
                          ),
                          _OptionRow(
                            label: t.webSharePage.requirePin,
                            value: webSendState.pin != null,
                            onChanged: (value) async {
                              final currentPIN = webSendState.pin;
                              if (currentPIN != null) {
                                ref.notifier(serverProvider).setWebSendPin(null);
                              } else {
                                final String? newPin =
                                    await showDialog<String>(
                                  context: context,
                                  builder: (_) => const PinDialog(
                                    obscureText: false,
                                    generateRandom: true,
                                  ),
                                );

                                if (newPin != null && newPin.isNotEmpty) {
                                  ref.notifier(serverProvider).setWebSendPin(
                                        newPin,
                                      );
                                }
                              }
                            },
                          ),
                          if (webSendState.pin != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t.webSharePage.pinHint(pin: webSendState.pin!),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .warning,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final _ServerState state;
  final bool encrypted;
  final String? initializedError;
  final VoidCallback onRetry;
  final Future<void> Function() onClose;
  final int fileCount;

  const _StateView({
    required this.state,
    required this.encrypted,
    required this.initializedError,
    required this.onRetry,
    required this.onClose,
    required this.fileCount,
  });

  @override
  Widget build(BuildContext context) {
    final loading =
        state == _ServerState.initializing || state == _ServerState.stopping;

    return ResponsiveListView(
      maxWidth: 760,
      padding: EdgeInsets.fromLTRB(
        context.adaptiveHorizontalPadding,
        context.adaptiveTopPadding,
        context.adaptiveHorizontalPadding,
        context.adaptiveBottomPadding,
      ),
      children: [
        ModernPageHeader(
          title: t.webSharePage.title,
          subtitle: loading
              ? (state == _ServerState.initializing
                  ? t.webSharePage.loading
                  : t.webSharePage.stopping)
              : t.webSharePage.error,
          trailing: state == _ServerState.error
              ? IconButton(
                  tooltip: t.general.close,
                  onPressed: () async => onClose(),
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          chips: [
            StatusChip(
              label: encrypted
                  ? t.webSharePage.protocol.https
                  : t.webSharePage.protocol.http,
              icon: encrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
              emphasized: true,
              color: Theme.of(context).colorScheme.primary,
            ),
            StatusChip(
              label: t.webSharePage.filesCount(n: fileCount),
              icon: Icons.folder_zip_rounded,
            ),
          ],
        ),
        SizedBox(height: context.adaptiveSectionSpacing),
        GlassSectionCard(
          title: loading
              ? t.webSharePage.stateCard.preparingTitle
              : t.webSharePage.error,
          subtitle: loading
              ? t.webSharePage.stateCard.preparingSubtitle
              : t.webSharePage.stateCard.errorSubtitle,
          strong: true,
          child: Column(
            children: [
              if (loading) ...[
                const SizedBox(height: 8),
                const CircularProgressIndicator(),
              ] else ...[
                Icon(
                  Icons.error_outline_rounded,
                  size: 52,
                  color: Theme.of(context).colorScheme.warning,
                ),
                if (initializedError != null) ...[
                  const SizedBox(height: 16),
                  GlassSurface(
                    applyBlur: false,
                    borderRadius: BorderRadius.circular(18),
                    child: SelectableText(initializedError!),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(t.webSharePage.stateCard.tryAgain),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WebLinkCard extends StatelessWidget {
  final String ip;
  final int port;
  final bool encrypted;
  final String? pin;

  const _WebLinkCard({
    required this.ip,
    required this.port,
    required this.encrypted,
    required this.pin,
  });

  @override
  Widget build(BuildContext context) {
    final compact = context.isNarrowWidth;
    final url = '${encrypted ? 'https' : 'http'}://$ip:$port';
    final urlWithPin = switch (pin) {
      String() => '$url/?pin=${Uri.encodeQueryComponent(pin!)}',
      null => url,
    };

    final actionButtons = Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        IconButton(
          tooltip: t.general.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted && checkPlatformIsDesktop()) {
              context.showSnackBar(t.general.copiedToClipboard);
            }
          },
          icon: const Icon(Icons.content_copy_rounded),
        ),
        IconButton(
          tooltip: t.webSharePage.linkActions.qr,
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (_) => QrDialog(
                data: urlWithPin,
                label: url,
                listenIncomingWebSendRequests: true,
                pin: pin,
              ),
            );
          },
          icon: const Icon(Icons.qr_code_rounded),
        ),
        IconButton(
          tooltip: t.webSharePage.linkActions.tv,
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (_) => ZoomDialog(
                label: url,
                pin: pin,
                listenIncomingWebSendRequests: true,
              ),
            );
          },
          icon: const Icon(Icons.tv_rounded),
        ),
      ],
    );

    return GlassSurface(
      applyBlur: false,
      strong: true,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actionButtons),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SelectableText(
                    url,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                actionButtons,
              ],
            ),
    );
  }
}

class _WebRequestCard extends StatelessWidget {
  final WebSendSession session;

  const _WebRequestCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final compact = context.isNarrowWidth;
    final waiting = session.responseHandler != null;

    final actionButtons = waiting
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  ref.notifier(serverProvider).declineWebSendRequest(session.sessionId);
                },
                icon: const Icon(Icons.close_rounded),
                label: Text(t.general.decline),
              ),
              FilledButton.icon(
                onPressed: () {
                  ref.notifier(serverProvider).acceptWebSendRequest(session.sessionId);
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(t.general.accept),
              ),
            ],
          )
        : StatusChip(
            label: t.general.accepted,
            icon: Icons.check_circle_rounded,
            emphasized: true,
            color: Theme.of(context).colorScheme.primary,
          );

    return GlassSurface(
      applyBlur: false,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.deviceInfo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: waiting
                            ? Theme.of(context).colorScheme.warning
                            : null,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  session.ip,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.visuals.mutedForeground,
                      ),
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actionButtons),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.deviceInfo,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: waiting
                                  ? Theme.of(context).colorScheme.warning
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.ip,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.visuals.mutedForeground,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                actionButtons,
              ],
            ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _OptionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassSurface(
        applyBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: context.visuals.mediumRadius,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
