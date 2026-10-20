import 'dart:convert';
import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/ai/ai_vision_attachments.dart';
import 'package:anx_reader/utils/get_path/get_cache_dir.dart';
import 'package:langchain_core/chat_models.dart';

class AiChatHistoryEntry {
  const AiChatHistoryEntry({
    required this.id,
    required this.serviceId,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    required this.completed,
    this.attachments = const <AiChatAttachment>[],
  });

  final String id;
  final String serviceId;
  final String model;
  final int createdAt;
  final int updatedAt;
  final List<ChatMessage> messages;
  final bool completed;

  /// Images (screenshots) attached to [messages], keyed by message index.
  final List<AiChatAttachment> attachments;

  AiChatHistoryEntry copyWith({
    List<ChatMessage>? messages,
    int? updatedAt,
    bool? completed,
    String? model,
    List<AiChatAttachment>? attachments,
  }) {
    return AiChatHistoryEntry(
      id: id,
      serviceId: serviceId,
      model: model ?? this.model,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      completed: completed ?? this.completed,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceId': serviceId,
      'model': model,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'completed': completed,
      'messages': messages.map((m) => m.toMap()).toList(growable: false),
      'attachments':
          attachments.map((a) => a.toJson()).toList(growable: false),
    };
  }

  factory AiChatHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = <ChatMessage>[];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map<String, dynamic>) {
          messages.add(ChatMessage.fromMap(item));
        } else if (item is Map) {
          messages.add(ChatMessage.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
    }

    final attachments = <AiChatAttachment>[];
    final rawAttachments = json['attachments'];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is Map<String, dynamic>) {
          attachments.add(AiChatAttachment.fromJson(item));
        } else if (item is Map) {
          attachments.add(AiChatAttachment.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
    }

    return AiChatHistoryEntry(
      id: json['id']?.toString() ?? '',
      serviceId: json['serviceId']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      createdAt: json['createdAt'] is int
          ? json['createdAt'] as int
          : DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] is int
          ? json['updatedAt'] as int
          : DateTime.now().millisecondsSinceEpoch,
      completed: json['completed'] == true,
      messages: messages,
      attachments: attachments,
    );
  }
}

/// An image attached to a chat message and persisted with the conversation.
class AiChatAttachment {
  const AiChatAttachment({
    required this.messageIndex,
    required this.path,
    this.mimeType = 'image/png',
  });

  /// Index of the message inside [AiChatHistoryEntry.messages] it belongs to.
  final int messageIndex;

  /// Absolute path of the saved image file.
  final String path;

  final String mimeType;

  bool get isImage => mimeType.startsWith('image/');

  AiChatAttachment copyWith({int? messageIndex, String? path, String? mimeType}) {
    return AiChatAttachment(
      messageIndex: messageIndex ?? this.messageIndex,
      path: path ?? this.path,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, dynamic> toJson() => {
        'messageIndex': messageIndex,
        'path': path,
        'mimeType': mimeType,
      };

  factory AiChatAttachment.fromJson(Map<String, dynamic> json) {
    return AiChatAttachment(
      messageIndex: json['messageIndex'] is int
          ? json['messageIndex'] as int
          : int.tryParse(json['messageIndex']?.toString() ?? '') ?? 0,
      path: json['path']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'image/png',
    );
  }
}

class AiHistoryStore {
  static const String historyFileName = 'ai_history.json';

  static Future<List<AiChatHistoryEntry>> readHistory() async {
    final file = await _resolveFile();
    if (!await file.exists()) {
      return <AiChatHistoryEntry>[];
    }

    try {
      final content = await file.readAsString();
      final decoded = json.decode(content);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.fromEntries(
                  e.entries.map(
                    (entry) => MapEntry(entry.key.toString(), entry.value),
                  ),
                ))
            .map(AiChatHistoryEntry.fromJson)
            .toList(growable: false);
      }
    } catch (_) {
      await file.delete();
    }
    return <AiChatHistoryEntry>[];
  }

  static Future<void> upsertEntry(AiChatHistoryEntry entry) async {
    final file = await _resolveFile();
    final history = List<AiChatHistoryEntry>.from(await readHistory());
    final existingIndex =
        history.indexWhere((element) => element.id == entry.id);

    if (existingIndex >= 0) {
      history[existingIndex] = entry;
    } else {
      history.add(entry);
    }

    history.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final maxCount = Prefs().maxAiCacheCount;
    final limit = maxCount <= 0 ? history.length : maxCount;
    final limited = history.take(limit).toList(growable: false);
    final dropped = history.skip(limit).toList(growable: false);

    await file.writeAsString(
      json.encode(limited.map((e) => e.toJson()).toList(growable: false)),
    );

    await _deleteAttachments(dropped);
  }

  static Future<void> removeEntry(String id) async {
    final file = await _resolveFile();
    final history = List<AiChatHistoryEntry>.from(await readHistory());
    final removed =
        history.where((element) => element.id == id).toList(growable: false);
    final filtered =
        history.where((element) => element.id != id).toList(growable: false);
    await file.writeAsString(
      json.encode(filtered.map((e) => e.toJson()).toList(growable: false)),
    );

    await _deleteAttachments(removed);
  }

  static Future<void> clear() async {
    final file = await _resolveFile();
    if (await file.exists()) {
      await file.delete();
    }
    await AiVisionAttachments.clearAll();
  }

  /// Best-effort removal of the screenshot files owned by [entries].
  static Future<void> _deleteAttachments(
    Iterable<AiChatHistoryEntry> entries,
  ) async {
    for (final entry in entries) {
      for (final attachment in entry.attachments) {
        await AiVisionAttachments.delete(attachment.path);
      }
    }
  }

  static Future<File> _resolveFile() async {
    final cacheDir = await getAnxCacheDir();
    return File('${cacheDir.path}/$historyFileName');
  }
}
