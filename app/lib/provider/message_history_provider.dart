import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/persistence/message_history_entry.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final activeMessageSelectionProvider = StateProvider<MessageConversationSelection?>(
  (ref) => null,
  debugLabel: 'activeMessageSelectionProvider',
);

final messageHistoryProvider = ReduxProvider<MessageHistoryService, List<MessageHistoryEntry>>((ref) {
  return MessageHistoryService(ref.read(persistenceProvider));
});

class MessageConversationSelection {
  final String conversationId;
  final MessagePeerSnapshot peer;

  const MessageConversationSelection({
    required this.conversationId,
    required this.peer,
  });

  factory MessageConversationSelection.fromPeer(MessagePeerSnapshot peer) {
    return MessageConversationSelection(
      conversationId: peer.conversationId,
      peer: peer,
    );
  }
}

class MessageHistoryCompatibilityEntry {
  final String sourceEntryId;
  final String? sourceItemId;
  final String conversationId;
  final MessagePeerSnapshot peer;
  final ReceiveHistoryEntry entry;

  const MessageHistoryCompatibilityEntry({
    required this.sourceEntryId,
    required this.sourceItemId,
    required this.conversationId,
    required this.peer,
    required this.entry,
  });
}

class MessageHistoryService extends ReduxNotifier<List<MessageHistoryEntry>> {
  final PersistenceService _persistence;

  MessageHistoryService(this._persistence);

  @override
  List<MessageHistoryEntry> init() {
    final existing = _persistence.getMessageHistory();
    if (existing.isNotEmpty) {
      return existing;
    }

    final migrated = migrateReceiveHistory(_persistence.getReceiveHistory());
    if (migrated.isNotEmpty) {
      unawaited(_persistence.setMessageHistory(migrated));
    }
    return migrated;
  }
}

class UpsertMessageHistoryEntryAction extends AsyncReduxAction<MessageHistoryService, List<MessageHistoryEntry>> {
  final MessageHistoryEntry entry;

  UpsertMessageHistoryEntryAction(this.entry);

  @override
  Future<List<MessageHistoryEntry>> reduce() async {
    final index = state.indexWhere((item) => item.id == entry.id);
    final updated = [...state];
    if (index == -1) {
      updated.insert(0, entry);
    } else {
      updated[index] = entry;
    }
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await notifier._persistence.setMessageHistory(updated);
    return List.unmodifiable(updated);
  }
}

class UpdateMessageHistoryEntryAction extends AsyncReduxAction<MessageHistoryService, List<MessageHistoryEntry>> {
  final String entryId;
  final MessagePeerSnapshot? peer;
  final MessageTransferState? stateValue;
  final String? text;
  final bool? isLink;
  final List<MessageTransferItem>? items;
  final String? sessionId;
  final DateTime? updatedAt;

  UpdateMessageHistoryEntryAction({
    required this.entryId,
    this.peer,
    this.stateValue,
    this.text,
    this.isLink,
    this.items,
    this.sessionId,
    this.updatedAt,
  });

  @override
  Future<List<MessageHistoryEntry>> reduce() async {
    final index = state.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return state;
    }

    final current = state[index];
    final updatedEntry = current.copyWith(
      peer: peer ?? current.peer,
      state: stateValue ?? current.state,
      text: text ?? current.text,
      isLink: isLink ?? current.isLink,
      items: items ?? current.items,
      sessionId: sessionId ?? current.sessionId,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );

    final updated = [...state];
    updated[index] = updatedEntry;
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await notifier._persistence.setMessageHistory(updated);
    return List.unmodifiable(updated);
  }
}

class RemoveMessageHistoryEntryAction extends AsyncReduxAction<MessageHistoryService, List<MessageHistoryEntry>> {
  final String entryId;

  RemoveMessageHistoryEntryAction(this.entryId);

  @override
  Future<List<MessageHistoryEntry>> reduce() async {
    final updated = state.where((entry) => entry.id != entryId).toList(growable: false);
    await notifier._persistence.setMessageHistory(updated);
    return updated;
  }
}

class RemoveCompatibilityMessageHistoryEntryAction
    extends AsyncReduxAction<MessageHistoryService, List<MessageHistoryEntry>> {
  final String sourceEntryId;
  final String? sourceItemId;

  RemoveCompatibilityMessageHistoryEntryAction({
    required this.sourceEntryId,
    required this.sourceItemId,
  });

  @override
  Future<List<MessageHistoryEntry>> reduce() async {
    final index = state.indexWhere((entry) => entry.id == sourceEntryId);
    if (index == -1) {
      return state;
    }

    final current = state[index];
    final updated = [...state];
    if (sourceItemId == null || current.kind == MessageEntryKind.text || current.items.length <= 1) {
      updated.removeAt(index);
    } else {
      final nextItems = current.items.where((item) => item.id != sourceItemId).toList(growable: false);
      if (nextItems.isEmpty) {
        updated.removeAt(index);
      } else {
        updated[index] = current.copyWith(
          items: nextItems,
          updatedAt: DateTime.now().toUtc(),
        );
      }
    }

    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await notifier._persistence.setMessageHistory(updated);
    return List.unmodifiable(updated);
  }
}

class ClearReceiveCompatibilityHistoryAction
    extends AsyncReduxAction<MessageHistoryService, List<MessageHistoryEntry>> {
  @override
  Future<List<MessageHistoryEntry>> reduce() async {
    final updated = state.where((entry) {
      return !(entry.isIncoming && entry.state == MessageTransferState.completed);
    }).toList(growable: false);
    await notifier._persistence.setMessageHistory(updated);
    return updated;
  }
}

List<MessageHistoryEntry> migrateReceiveHistory(List<ReceiveHistoryEntry> entries) {
  return entries.map((entry) {
    final conversationId = conversationIdForFingerprint('', legacyAlias: entry.senderAlias);
    final peer = MessagePeerSnapshot(
      conversationId: conversationId,
      fingerprint: '',
      alias: entry.senderAlias,
      ip: null,
      port: null,
      deviceType: null,
    );

    if (entry.isMessage) {
      return MessageHistoryEntry(
        id: entry.id,
        conversationId: conversationId,
        peer: peer,
        direction: MessageDirection.incoming,
        kind: MessageEntryKind.text,
        state: MessageTransferState.completed,
        text: entry.fileName,
        isLink: guessIsLink(entry.fileName),
        items: const [],
        sessionId: null,
        createdAt: entry.timestamp.toUtc(),
        updatedAt: entry.timestamp.toUtc(),
      );
    }

    return MessageHistoryEntry(
      id: entry.id,
      conversationId: conversationId,
      peer: peer,
      direction: MessageDirection.incoming,
      kind: MessageEntryKind.transferBatch,
      state: MessageTransferState.completed,
      text: null,
      isLink: false,
      items: [
        MessageTransferItem(
          id: entry.id,
          fileName: entry.fileName,
          fileType: entry.fileType,
          size: entry.fileSize,
          path: entry.path,
          savedToGallery: entry.savedToGallery,
          errorMessage: null,
        ),
      ],
      sessionId: null,
      createdAt: entry.timestamp.toUtc(),
      updatedAt: entry.timestamp.toUtc(),
    );
  }).toList(growable: false)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

List<MessageConversationSummary> buildConversationSummaries(List<MessageHistoryEntry> entries) {
  final groups = groupBy(entries, (MessageHistoryEntry entry) => entry.conversationId);
  final summaries = groups.entries.map((group) {
    final sorted = [...group.value]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final lastEntry = sorted.first;
    return MessageConversationSummary(
      conversationId: group.key,
      peer: lastEntry.peer,
      lastEntry: lastEntry,
      hasActiveTransfer: sorted.any((entry) {
        return switch (entry.state) {
          MessageTransferState.pendingIncoming || MessageTransferState.receiving || MessageTransferState.sending => true,
          _ => false,
        };
      }),
    );
  }).toList(growable: false);

  summaries.sort((a, b) => b.lastEntry.updatedAt.compareTo(a.lastEntry.updatedAt));
  return summaries;
}

List<MessageHistoryEntry> entriesForConversation(List<MessageHistoryEntry> entries, String conversationId) {
  return entries
      .where((entry) => entry.conversationId == conversationId)
      .sorted((a, b) => a.createdAt.compareTo(b.createdAt));
}

List<MessageHistoryCompatibilityEntry> buildCompatibilityHistory(List<MessageHistoryEntry> entries) {
  final result = <MessageHistoryCompatibilityEntry>[];

  for (final entry in entries.sorted((a, b) => b.updatedAt.compareTo(a.updatedAt))) {
    if (!entry.isIncoming || entry.state != MessageTransferState.completed) {
      continue;
    }

    if (entry.kind == MessageEntryKind.text) {
      final text = entry.text ?? '';
      result.add(
        MessageHistoryCompatibilityEntry(
          sourceEntryId: entry.id,
          sourceItemId: null,
          conversationId: entry.conversationId,
          peer: entry.peer,
          entry: ReceiveHistoryEntry(
            id: entry.id,
            fileName: text,
            fileType: FileType.text,
            path: null,
            savedToGallery: false,
            isMessage: true,
            fileSize: encodedMessageSize(text),
            senderAlias: entry.peer.alias,
            timestamp: entry.createdAt,
          ),
        ),
      );
      continue;
    }

    for (final item in entry.items) {
      result.add(
        MessageHistoryCompatibilityEntry(
          sourceEntryId: entry.id,
          sourceItemId: item.id,
          conversationId: entry.conversationId,
          peer: entry.peer,
          entry: ReceiveHistoryEntry(
            id: '${entry.id}:${item.id}',
            fileName: item.fileName,
            fileType: item.fileType,
            path: item.path,
            savedToGallery: item.savedToGallery,
            isMessage: false,
            fileSize: item.size,
            senderAlias: entry.peer.alias,
            timestamp: entry.createdAt,
          ),
        ),
      );
    }
  }

  return result;
}

String conversationPreview(MessageHistoryEntry entry) {
  if (entry.kind == MessageEntryKind.text) {
    return normalizeMessagePreview(entry.text);
  }

  if (entry.items.isEmpty) {
    return '';
  }

  if (entry.items.length == 1) {
    return entry.items.first.fileName;
  }

  return '${entry.items.length} files';
}
