import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/file_type.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/message_history_entry.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/message_history_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class MessageTab extends StatelessWidget {
  const MessageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final selection = context.watch(activeMessageSelectionProvider);
    return selection == null
        ? const _MessageConversationListView()
        : PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (!didPop) {
                context.ref.notifier(activeMessageSelectionProvider).setState((_) => null);
              }
            },
            child: _MessageConversationView(selection: selection),
          );
  }
}

class _MessageConversationListView extends StatelessWidget {
  const _MessageConversationListView();

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(messageHistoryProvider);
    final nearbyState = context.watch(nearbyDevicesProvider);
    final favorites = context.watch(favoritesProvider);
    final summaries = buildConversationSummaries(entries);
    final devices = nearbyState.devices.values.toList()
      ..sort((a, b) {
        final aFav = favorites.findDevice(a) != null;
        final bFav = favorites.findDevice(b) != null;
        if (aFav != bFav) return aFav ? -1 : 1;
        return a.alias.toLowerCase().compareTo(b.alias.toLowerCase());
      });
    final gap = context.adaptiveSectionSpacing;

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
          title: t.messageTab.title,
          subtitle: summaries.isEmpty ? t.messageTab.empty : t.messageTab.recentConversations,
          chips: [
            StatusChip(
              label: summaries.isEmpty ? t.messageTab.empty : '${summaries.length}',
              icon: Icons.chat_bubble_rounded,
              emphasized: summaries.isNotEmpty,
              color: Theme.of(context).colorScheme.primary,
            ),
            StatusChip(
              label: devices.isEmpty ? t.general.offline : '${devices.length} ${t.sendTab.nearbyDevices}',
              icon: Icons.devices_rounded,
            ),
          ],
        ),
        SizedBox(height: gap),
        GlassSectionCard(
          title: t.messageTab.recentConversations,
          subtitle: summaries.isEmpty ? t.messageTab.empty : t.messageTab.selectDevice,
          strong: true,
          child: summaries.isEmpty
              ? SizedBox(
                  height: 140,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.forum_rounded, size: 52),
                        const SizedBox(height: 12),
                        Text(t.messageTab.noMessages),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < summaries.length; i++) ...[
                      ModernActionTile(
                        icon: summaries[i].peer.deviceType?.icon ?? Icons.devices_rounded,
                        title: summaries[i].peer.alias,
                        subtitle: conversationPreview(summaries[i].lastEntry),
                        highlighted: summaries[i].hasActiveTransfer,
                        trailing: Text(
                          _formatConversationTime(summaries[i].lastEntry.updatedAt),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        onTap: () {
                          context.ref.notifier(activeMessageSelectionProvider).setState(
                                (_) => MessageConversationSelection(
                                  conversationId: summaries[i].conversationId,
                                  peer: summaries[i].peer,
                                ),
                              );
                        },
                      ),
                      if (i != summaries.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        SizedBox(height: gap),
        GlassSectionCard(
          title: t.messageTab.startConversation,
          subtitle: devices.isEmpty ? t.sendTab.help : t.messageTab.selectDevice,
          child: devices.isEmpty
              ? SizedBox(
                  height: 100,
                  child: Center(child: Text(t.sendTab.help, textAlign: TextAlign.center)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < devices.length; i++) ...[
                      ModernActionTile(
                        icon: devices[i].deviceType.icon,
                        title: favorites.findDevice(devices[i])?.alias ?? devices[i].alias,
                        subtitle: '#${devices[i].ip}',
                        highlighted: favorites.findDevice(devices[i]) != null,
                        onTap: () {
                          final peer = MessagePeerSnapshot.fromDevice(
                            devices[i],
                            aliasOverride: favorites.findDevice(devices[i])?.alias,
                          );
                          context.ref.notifier(activeMessageSelectionProvider)
                              .setState((_) => MessageConversationSelection.fromPeer(peer));
                        },
                      ),
                      if (i != devices.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MessageConversationView extends StatefulWidget {
  final MessageConversationSelection selection;

  const _MessageConversationView({required this.selection});

  @override
  State<_MessageConversationView> createState() => _MessageConversationViewState();
}

class _MessageConversationViewState extends State<_MessageConversationView> {
  final _textController = TextEditingController();
  List<CrossFile> _attachments = const [];
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments(BuildContext context) async {
    final option = await showDialog<FilePickerOption>(
      context: context,
      builder: (_) => _AttachmentPickerDialog(options: FilePickerOption.getOptionsForPlatform()),
    );
    if (option == null || !context.mounted) return;

    final ref = context.ref;
    final previous = ref.read(selectedSendingFilesProvider);
    ref.redux(selectedSendingFilesProvider).dispatch(ReplaceSelectionAction(const []));
    await context.global.dispatchAsync(PickFileAction(option: option, context: context));
    final picked = ref.read(selectedSendingFilesProvider);
    ref.redux(selectedSendingFilesProvider).dispatch(ReplaceSelectionAction(previous));
    if (!mounted || picked.isEmpty) return;

    final extraText = <String>[];
    final next = <CrossFile>[];
    for (final file in picked) {
      if (file.fileType == FileType.text && file.path == null && file.bytes != null) {
        extraText.add(utf8.decode(file.bytes!));
      } else if (!_attachments.any((existing) => _sameFile(existing, file))) {
        next.add(file);
      }
    }
    if (extraText.isNotEmpty) {
      final prefix = _textController.text.trim().isEmpty ? '' : '${_textController.text.trim()}\n';
      _textController.text = '$prefix${extraText.join('\n')}';
    }
    if (next.isNotEmpty) {
      setState(() => _attachments = [..._attachments, ...next]);
    }
  }

  Future<void> _send(BuildContext context) async {
    final target = _resolveTarget(context);
    final text = _textController.text.trim();
    if (_sending || target == null || (text.isEmpty && _attachments.isEmpty)) return;

    final ref = context.ref;
    final previous = ref.read(selectedSendingFilesProvider);
    setState(() => _sending = true);
    try {
      if (text.isNotEmpty) await _sendText(context, target, text);
      if (_attachments.isNotEmpty && mounted) {
        await _sendFiles(context, target, List<CrossFile>.from(_attachments));
      }
      if (mounted) {
        _textController.clear();
        setState(() => _attachments = const []);
      }
    } finally {
      ref.redux(selectedSendingFilesProvider).dispatch(ReplaceSelectionAction(previous));
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText(BuildContext context, Device target, String text) async {
    final ref = context.ref;
    final entryId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final peer = MessagePeerSnapshot.fromDevice(target, aliasOverride: widget.selection.peer.alias);
    await ref.redux(messageHistoryProvider).dispatchAsync(UpsertMessageHistoryEntryAction(
      MessageHistoryEntry(
        id: entryId,
        conversationId: widget.selection.conversationId,
        peer: peer,
        direction: MessageDirection.outgoing,
        kind: MessageEntryKind.text,
        state: MessageTransferState.sending,
        text: text,
        isLink: guessIsLink(text),
        items: const [],
        sessionId: null,
        createdAt: now,
        updatedAt: now,
      ),
    ));
    String? sessionId;
    await ref.notifier(sendProvider).startSession(
      target: target,
      files: [_buildTextMessageFile(text)],
      background: true,
      onSessionCreated: (id) {
        sessionId = id;
        unawaited(ref.redux(messageHistoryProvider).dispatchAsync(
          UpdateMessageHistoryEntryAction(entryId: entryId, sessionId: id, peer: peer),
        ));
      },
    );
    await _finalizeOutgoingEntry(context, entryId, sessionId);
  }
  Future<void> _sendFiles(BuildContext context, Device target, List<CrossFile> files) async {
    final ref = context.ref;
    final entryId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final peer = MessagePeerSnapshot.fromDevice(target, aliasOverride: widget.selection.peer.alias);
    await ref.redux(messageHistoryProvider).dispatchAsync(UpsertMessageHistoryEntryAction(
      MessageHistoryEntry(
        id: entryId,
        conversationId: widget.selection.conversationId,
        peer: peer,
        direction: MessageDirection.outgoing,
        kind: MessageEntryKind.transferBatch,
        state: MessageTransferState.sending,
        text: null,
        isLink: false,
        items: files.map((e) => MessageTransferItem.fromCrossFile(e, id: _uuid.v4())).toList(growable: false),
        sessionId: null,
        createdAt: now,
        updatedAt: now,
      ),
    ));
    String? sessionId;
    await ref.notifier(sendProvider).startSession(
      target: target,
      files: files,
      background: true,
      onSessionCreated: (id) {
        sessionId = id;
        unawaited(ref.redux(messageHistoryProvider).dispatchAsync(
          UpdateMessageHistoryEntryAction(entryId: entryId, sessionId: id, peer: peer),
        ));
      },
    );
    await _finalizeOutgoingEntry(context, entryId, sessionId);
  }

  Future<void> _finalizeOutgoingEntry(BuildContext context, String entryId, String? sessionId) async {
    final ref = context.ref;
    final session = sessionId == null ? null : ref.read(sendProvider)[sessionId];
    await ref.redux(messageHistoryProvider).dispatchAsync(
      UpdateMessageHistoryEntryAction(entryId: entryId, stateValue: _mapOutgoingState(session)),
    );
    if (sessionId != null && session != null) {
      ref.notifier(sendProvider).closeSession(sessionId);
    }
  }

  Device? _resolveTarget(BuildContext context) {
    return context.read(nearbyDevicesProvider).devices.values.firstWhereOrNull(
          (device) => device.fingerprint == widget.selection.peer.fingerprint,
        );
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = context.watch(messageHistoryProvider);
    final entries = entriesForConversation(allEntries, widget.selection.conversationId);
    final compactHeader = context.isPhoneLayout;
    final target = context.watch(nearbyDevicesProvider.select(
      (state) => state.devices.values.firstWhereOrNull((e) => e.fingerprint == widget.selection.peer.fingerprint),
    ));
    final receiveSession = context.watch(serverProvider.select((state) => state?.session));
    final pending = entries.lastWhereOrNull(
      (e) => e.isIncoming && e.kind == MessageEntryKind.transferBatch && e.state == MessageTransferState.pendingIncoming,
    );
    final canHandlePending = pending != null && receiveSession?.sender.fingerprint == widget.selection.peer.fingerprint;
    final gap = context.adaptiveSectionSpacing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.adaptiveHorizontalPadding,
        context.adaptiveTopPadding,
        context.adaptiveHorizontalPadding,
        context.adaptiveBottomPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              ModernPageHeader(
                title: widget.selection.peer.alias,
                subtitle: target == null ? t.messageTab.offlineSubtitle : '#${target.ip}',
                lowProfile: compactHeader,
                leading: compactHeader
                    ? IconButton(
                        onPressed: () => context.ref.notifier(activeMessageSelectionProvider).setState((_) => null),
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    : null,
                trailing: compactHeader
                    ? null
                    : IconButton(
                        onPressed: () => context.ref.notifier(activeMessageSelectionProvider).setState((_) => null),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
              ),
              SizedBox(height: gap),
              Expanded(
                child: entries.isEmpty
                    ? GlassSectionCard(
                        title: t.messageTab.noMessages,
                        subtitle: t.messageTab.selectDevice,
                        strong: true,
                        child: const SizedBox(height: 120),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final actionable = canHandlePending && pending?.id == entry.id;
                          return _MessageEntryCard(entry: entry, actionable: actionable);
                        },
                      ),
              ),
              SizedBox(height: gap),
              GlassSurface(
                strong: true,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_attachments.isNotEmpty)
                      Row(
                        children: [
                          StatusChip(label: '${_attachments.length} ${t.general.files.toLowerCase()}', icon: Icons.attach_file_rounded),
                          const SizedBox(width: 8),
                          TextButton(onPressed: () => setState(() => _attachments = const []), child: Text(t.general.delete)),
                        ],
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            enabled: !_sending && target != null,
                            minLines: 1,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: target == null ? t.messageTab.offlineSubtitle : t.messageTab.selectDevice,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: !_sending && target != null ? () => _pickAttachments(context) : null,
                          icon: const Icon(Icons.attach_file_rounded),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: !_sending && target != null ? () => _send(context) : null,
                          child: Text(_sending ? t.messageTab.sending : t.general.confirm),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageEntryCard extends StatelessWidget {
  final MessageHistoryEntry entry;
  final bool actionable;

  const _MessageEntryCard({required this.entry, required this.actionable});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: entry.isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: GlassSurface(
          strong: entry.isOutgoing,
          color: entry.isOutgoing ? Theme.of(context).colorScheme.primary.withOpacity(0.18) : null,
          padding: const EdgeInsets.all(16),
          onTap: entry.isText && entry.isLink && entry.text != null
              ? () async {
                  final uri = Uri.tryParse(entry.text!);
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(entry.isOutgoing ? t.sendTab.thisDevice : entry.peer.alias)),
                StatusChip(label: _stateLabel(entry.state), icon: _stateIcon(entry.state)),
              ]),
              const SizedBox(height: 8),
              if (entry.isText)
                SelectableText(entry.text ?? '')
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entry.items
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              FilePathThumbnail(path: item.path, fileType: item.fileType),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${item.fileName}\n${item.size.asReadableFileSize}', maxLines: 2)),
                            ]),
                          ))
                      .toList(growable: false),
                ),
              Text(
                DateFormat.yMd(LocaleSettings.currentLocale.languageTag).add_jm().format(entry.updatedAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.visuals.mutedForeground),
              ),
              if (actionable) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final server = context.ref.notifier(serverProvider);
                        final session = context.read(serverProvider)?.session;
                        if (session == null) return;
                        context.ref.notifier(selectedReceivingFilesProvider).setFiles(
                              session.files.values.map((f) => f.file).toList(growable: false),
                            );
                        server.acceptFileRequest(
                          context.read(selectedReceivingFilesProvider),
                          closeOnFinish: true,
                        );
                      },
                      child: Text(t.general.accept),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.ref.notifier(serverProvider).declineFileRequest(),
                      child: Text(t.general.decline),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPickerDialog extends StatelessWidget {
  final List<FilePickerOption> options;

  const _AttachmentPickerDialog({required this.options});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.sendTab.selection.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map((option) => ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.label),
                  onTap: () => Navigator.of(context).pop(option),
                ))
            .toList(growable: false),
      ),
    );
  }
}

String _formatConversationTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final sameDay = now.year == local.year && now.month == local.month && now.day == local.day;
  return sameDay ? DateFormat.Hm().format(local) : DateFormat.Md().format(local);
}

MessageTransferState _mapOutgoingState(SendSessionState? session) {
  if (session == null) return MessageTransferState.completed;
  return switch (session.status) {
    SessionStatus.waiting || SessionStatus.sending => MessageTransferState.sending,
    SessionStatus.finished => MessageTransferState.completed,
    SessionStatus.canceledByReceiver || SessionStatus.canceledBySender => MessageTransferState.canceled,
    _ => MessageTransferState.failed,
  };
}

String _stateLabel(MessageTransferState state) => switch (state) {
      MessageTransferState.pendingIncoming => t.messageTab.pendingIncoming,
      MessageTransferState.sending => t.messageTab.sending,
      MessageTransferState.receiving => t.messageTab.receiving,
      MessageTransferState.completed => t.messageTab.completed,
      MessageTransferState.declined => t.messageTab.declined,
      MessageTransferState.failed => t.messageTab.failed,
      MessageTransferState.canceled => t.messageTab.canceled,
    };

IconData _stateIcon(MessageTransferState state) => switch (state) {
      MessageTransferState.pendingIncoming => Icons.mark_email_unread_rounded,
      MessageTransferState.sending => Icons.north_east_rounded,
      MessageTransferState.receiving => Icons.south_west_rounded,
      MessageTransferState.completed => Icons.check_circle_rounded,
      MessageTransferState.declined => Icons.block_rounded,
      MessageTransferState.failed => Icons.error_rounded,
      MessageTransferState.canceled => Icons.cancel_rounded,
    };

CrossFile _buildTextMessageFile(String text) {
  final bytes = utf8.encode(text);
  return CrossFile(
    name: '${_uuid.v4()}.txt',
    fileType: FileType.text,
    size: bytes.length,
    thumbnail: null,
    asset: null,
    path: null,
    bytes: bytes,
    lastModified: null,
    lastAccessed: null,
  );
}

bool _sameFile(CrossFile a, CrossFile b) {
  if (a.path != null || b.path != null) return a.path == b.path && a.name == b.name;
  return a.name == b.name && a.size == b.size && const ListEquality<int>().equals(a.bytes, b.bytes);
}
