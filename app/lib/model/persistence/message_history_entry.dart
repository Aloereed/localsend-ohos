import 'dart:convert';

import 'package:common/model/device.dart';
import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/cross_file.dart';

enum MessageDirection {
  incoming,
  outgoing,
}

enum MessageEntryKind {
  text,
  transferBatch,
}

enum MessageTransferState {
  pendingIncoming,
  sending,
  receiving,
  completed,
  declined,
  failed,
  canceled,
}

class MessagePeerSnapshot {
  final String conversationId;
  final String fingerprint;
  final String alias;
  final String? ip;
  final int? port;
  final DeviceType? deviceType;

  const MessagePeerSnapshot({
    required this.conversationId,
    required this.fingerprint,
    required this.alias,
    required this.ip,
    required this.port,
    required this.deviceType,
  });

  factory MessagePeerSnapshot.fromDevice(Device device, {String? aliasOverride}) {
    return MessagePeerSnapshot(
      conversationId: conversationIdForFingerprint(device.fingerprint),
      fingerprint: device.fingerprint,
      alias: aliasOverride ?? device.alias,
      ip: device.ip,
      port: device.port,
      deviceType: device.deviceType,
    );
  }

  factory MessagePeerSnapshot.fromJson(Map<String, dynamic> json) {
    return MessagePeerSnapshot(
      conversationId: json['conversationId'] as String,
      fingerprint: json['fingerprint'] as String,
      alias: json['alias'] as String,
      ip: json['ip'] as String?,
      port: json['port'] as int?,
      deviceType: (json['deviceType'] as String?) == null
          ? null
          : DeviceType.values.where((entry) => entry.name == json['deviceType']).firstOrNull,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'fingerprint': fingerprint,
      'alias': alias,
      'ip': ip,
      'port': port,
      'deviceType': deviceType?.name,
    };
  }

  MessagePeerSnapshot copyWith({
    String? conversationId,
    String? fingerprint,
    String? alias,
    String? ip,
    int? port,
    DeviceType? deviceType,
  }) {
    return MessagePeerSnapshot(
      conversationId: conversationId ?? this.conversationId,
      fingerprint: fingerprint ?? this.fingerprint,
      alias: alias ?? this.alias,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
    );
  }
}

class MessageTransferItem {
  final String id;
  final String fileName;
  final FileType fileType;
  final int size;
  final String? path;
  final bool savedToGallery;
  final String? errorMessage;

  const MessageTransferItem({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.size,
    required this.path,
    required this.savedToGallery,
    required this.errorMessage,
  });

  factory MessageTransferItem.fromCrossFile(CrossFile file, {required String id}) {
    return MessageTransferItem(
      id: id,
      fileName: file.name,
      fileType: file.fileType,
      size: file.size,
      path: file.path,
      savedToGallery: false,
      errorMessage: null,
    );
  }

  factory MessageTransferItem.fromJson(Map<String, dynamic> json) {
    return MessageTransferItem(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileType: FileType.values.where((entry) => entry.name == json['fileType']).firstOrNull ?? FileType.other,
      size: json['size'] as int,
      path: json['path'] as String?,
      savedToGallery: json['savedToGallery'] == true,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType.name,
      'size': size,
      'path': path,
      'savedToGallery': savedToGallery,
      'errorMessage': errorMessage,
    };
  }

  MessageTransferItem copyWith({
    String? id,
    String? fileName,
    FileType? fileType,
    int? size,
    String? path,
    bool? savedToGallery,
    String? errorMessage,
  }) {
    return MessageTransferItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      size: size ?? this.size,
      path: path ?? this.path,
      savedToGallery: savedToGallery ?? this.savedToGallery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class MessageHistoryEntry {
  final String id;
  final String conversationId;
  final MessagePeerSnapshot peer;
  final MessageDirection direction;
  final MessageEntryKind kind;
  final MessageTransferState state;
  final String? text;
  final bool isLink;
  final List<MessageTransferItem> items;
  final String? sessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MessageHistoryEntry({
    required this.id,
    required this.conversationId,
    required this.peer,
    required this.direction,
    required this.kind,
    required this.state,
    required this.text,
    required this.isLink,
    required this.items,
    required this.sessionId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncoming => direction == MessageDirection.incoming;

  bool get isOutgoing => direction == MessageDirection.outgoing;

  bool get isPendingIncoming => state == MessageTransferState.pendingIncoming;

  bool get isTransfer => kind == MessageEntryKind.transferBatch;

  bool get isText => kind == MessageEntryKind.text;

  int get totalSize => items.fold<int>(0, (previous, item) => previous + item.size);

  factory MessageHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MessageHistoryEntry(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      peer: MessagePeerSnapshot.fromJson(json['peer'] as Map<String, dynamic>),
      direction: MessageDirection.values.where((entry) => entry.name == json['direction']).firstOrNull ?? MessageDirection.incoming,
      kind: MessageEntryKind.values.where((entry) => entry.name == json['kind']).firstOrNull ?? MessageEntryKind.text,
      state: MessageTransferState.values.where((entry) => entry.name == json['state']).firstOrNull ?? MessageTransferState.completed,
      text: json['text'] as String?,
      isLink: json['isLink'] == true,
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MessageTransferItem.fromJson)
          .toList(),
      sessionId: json['sessionId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'peer': peer.toJson(),
      'direction': direction.name,
      'kind': kind.name,
      'state': state.name,
      'text': text,
      'isLink': isLink,
      'items': items.map((item) => item.toJson()).toList(),
      'sessionId': sessionId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  MessageHistoryEntry copyWith({
    String? id,
    String? conversationId,
    MessagePeerSnapshot? peer,
    MessageDirection? direction,
    MessageEntryKind? kind,
    MessageTransferState? state,
    String? text,
    bool? isLink,
    List<MessageTransferItem>? items,
    String? sessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MessageHistoryEntry(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      peer: peer ?? this.peer,
      direction: direction ?? this.direction,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      text: text ?? this.text,
      isLink: isLink ?? this.isLink,
      items: items ?? this.items,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MessageConversationSummary {
  final String conversationId;
  final MessagePeerSnapshot peer;
  final MessageHistoryEntry lastEntry;
  final bool hasActiveTransfer;

  const MessageConversationSummary({
    required this.conversationId,
    required this.peer,
    required this.lastEntry,
    required this.hasActiveTransfer,
  });
}

String conversationIdForFingerprint(String fingerprint, {String? legacyAlias}) {
  if (fingerprint.trim().isNotEmpty) {
    return fingerprint.trim();
  }

  final fallback = (legacyAlias == null || legacyAlias.trim().isEmpty) ? 'unknown' : legacyAlias.trim();
  return 'legacy:$fallback';
}

bool guessIsLink(String? text) {
  if (text == null) {
    return false;
  }
  return Uri.tryParse(text)?.isAbsolute ?? false;
}

String normalizeMessagePreview(String? text) {
  if (text == null) {
    return '';
  }
  return text.replaceAll('\n', ' ').trim();
}

int encodedMessageSize(String text) => utf8.encode(text).length;

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
