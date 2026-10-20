import 'dart:typed_data';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/providers/ai_history.dart';
import 'package:anx_reader/service/ai/ai_history.dart';
import 'package:anx_reader/service/ai/ai_vision_attachments.dart';
import 'package:anx_reader/service/ai/ai_vision_chat_service.dart';
import 'package:anx_reader/service/ai/index.dart';
import 'package:anx_reader/utils/ai_reasoning_parser.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:langchain_core/chat_models.dart';

part 'ai_chat.g.dart';

@Riverpod(keepAlive: true)
class AiChat extends _$AiChat {
  String? _currentSessionId;
  List<AiChatAttachment> _attachments = const <AiChatAttachment>[];

  /// Images (screenshots) attached to the current conversation, by message
  /// index. Exposed to the chat UI so pending/sent screenshots can be rendered.
  List<AiChatAttachment> get currentAttachments => _attachments;

  @override
  FutureOr<List<ChatMessage>> build() async {
    _currentSessionId = null;
    return List<ChatMessage>.empty();
  }

  Future<void> sendMessage(String message) async {
    state = AsyncData([
      ...state.whenOrNull(data: (data) => data) ?? [],
      ChatMessage.humanText(message),
    ]);
  }

  void restore(
    List<ChatMessage> history, {
    String? sessionId,
    List<AiChatAttachment>? attachments,
  }) {
    if (sessionId != null) {
      _currentSessionId = sessionId;
    }
    _attachments = (attachments ?? _attachments)
        .where((a) => a.messageIndex <= history.length)
        .toList(growable: false);
    state = AsyncData(history);
  }

  /// Loads the persisted screenshots attached to [messageIndex].
  ///
  /// Used when regenerating an answer: the original human turn is removed from
  /// the conversation before the new request is built, so the image bytes must
  /// be recovered from the attachment store and sent again.
  Future<List<Uint8List>> imagesForMessage(int messageIndex) async {
    final images = <Uint8List>[];
    for (final attachment in _attachments) {
      if (attachment.messageIndex != messageIndex) {
        continue;
      }
      final bytes = await AiVisionAttachments.read(attachment.path);
      if (bytes != null && bytes.isNotEmpty) {
        images.add(bytes);
      }
    }
    return images;
  }

  Stream<List<ChatMessage>> sendMessageStream(
    String message,
    WidgetRef widgetRef,
    bool isRegenerate, {
    List<Uint8List> images = const <Uint8List>[],
  }) async* {
    final sessionId = _ensureSessionId();
    final serviceId = Prefs().selectedAiService;
    final config = Prefs().getAiConfig(serviceId);
    final model = (config['model'])?.trim() ?? '';
    final historyNotifier = widgetRef.read(aiHistoryProvider.notifier);
    final initialHistoryState = widgetRef
        .read(aiHistoryProvider)
        .maybeWhen(data: (value) => value, orElse: () => const []);
    AiChatHistoryEntry? entry;
    for (final item in initialHistoryState) {
      if (item.id == sessionId) {
        entry = item;
        break;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;

    final baseMessages = state.whenOrNull(data: (data) => data) ?? const [];
    final humanIndex = baseMessages.length;

    // On regeneration the human turn is rebuilt from history, so recover its
    // images from the attachment store instead of relying on the UI handing
    // them over again.
    var effectiveImages = images;
    if (isRegenerate && effectiveImages.isEmpty) {
      effectiveImages = await imagesForMessage(humanIndex);
    }

    // Persist attached screenshots and bind them to the human message that is
    // about to be appended, so they survive history reloads. When regenerating,
    // the attachments already exist and must not be duplicated.
    if (effectiveImages.isNotEmpty && !isRegenerate) {
      final saved = <AiChatAttachment>[];
      for (final bytes in effectiveImages) {
        try {
          final path = await AiVisionAttachments.save(bytes);
          saved.add(AiChatAttachment(messageIndex: humanIndex, path: path));
        } catch (e) {
          AnxLog.warning('AiChat: failed to save screenshot attachment: $e');
        }
      }
      _attachments = <AiChatAttachment>[..._attachments, ...saved];
    }

    List<ChatMessage> messages = [
      ...baseMessages,
      ChatMessage.humanText(message),
    ];

    state = AsyncData(messages);

    List<ChatMessage> updatedMessages = [
      ...messages,
      ChatMessage.ai(''),
    ];

    final draftEntry = (entry ??
            AiChatHistoryEntry(
              id: sessionId,
              serviceId: serviceId,
              model: model,
              createdAt: entry?.createdAt ?? now,
              updatedAt: now,
              messages: List<ChatMessage>.from(updatedMessages),
              completed: false,
              attachments: List<AiChatAttachment>.from(_attachments),
            ))
        .copyWith(
      messages: List<ChatMessage>.from(updatedMessages),
      updatedAt: now,
      completed: false,
      model: model,
      attachments: List<AiChatAttachment>.from(_attachments),
    );

    await historyNotifier.upsert(draftEntry);

    yield updatedMessages;

    String assistantResponse = "";
    try {
      // Screenshots are sent through the multimodal path; text-only messages
      // keep using the agent pipeline.
      final Stream<String> responseStream = effectiveImages.isNotEmpty
          ? _imageResponseStream(messages, effectiveImages)
          : aiGenerateStream(
              messages,
              regenerate: isRegenerate,
              useAgent: true,
              ref: widgetRef,
            );

      await for (final chunk in responseStream) {
        assistantResponse = chunk;

        final updatedMessagesWithResponse =
            List<ChatMessage>.from(updatedMessages);
        updatedMessagesWithResponse[updatedMessagesWithResponse.length - 1] =
            assistantMessageFromDisplayContent(assistantResponse);

        yield updatedMessagesWithResponse;

        state = AsyncData(updatedMessagesWithResponse);
      }
      final completedEntry = draftEntry.copyWith(
        messages: List<ChatMessage>.from(state.value ?? updatedMessages),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        completed: true,
        model: model,
        attachments: List<AiChatAttachment>.from(_attachments),
      );
      await historyNotifier.upsert(completedEntry);
    } catch (_) {
      final failedEntry = draftEntry.copyWith(
        messages: List<ChatMessage>.from(state.value ?? updatedMessages),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        completed: false,
        model: model,
        attachments: List<AiChatAttachment>.from(_attachments),
      );
      await historyNotifier.upsert(failedEntry);
      rethrow;
    }
  }

  /// Builds the multimodal request for a message that carries screenshots.
  ///
  /// The whole conversation is sent as text turns (so the model keeps context)
  /// while the newly attached images ride along with the last user turn.
  Stream<String> _imageResponseStream(
    List<ChatMessage> messages,
    List<Uint8List> images,
  ) async* {
    final lastHumanIndex = messages.lastIndexWhere((m) => m is HumanChatMessage);

    final turns = <AiVisionTurn>[];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final isHuman = message is HumanChatMessage;
      final text = _messageText(message).trim();
      final attached =
          i == lastHumanIndex ? images : const <Uint8List>[];
      if (text.isEmpty && attached.isEmpty) {
        continue;
      }
      turns.add(
        AiVisionTurn(
          role: isHuman ? 'user' : 'assistant',
          text: text,
          images: attached,
        ),
      );
    }

    var last = '';
    try {
      await for (final chunk
          in const AiVisionChatService().stream(turns: turns)) {
        last = chunk;
        yield last;
      }
      if (last.isEmpty) {
        yield 'El modelo no devolvió respuesta para la imagen adjunta.';
      }
    } catch (e) {
      AnxLog.severe('Vision chat failed: $e');
      yield 'Error: $e';
    }
  }

  String _messageText(ChatMessage message) {
    if (message is AIChatMessage) {
      return message.content;
    }
    return message.contentAsString;
  }

  void clear() {
    state = AsyncData(List<ChatMessage>.empty());
    _currentSessionId = null;
    _attachments = const <AiChatAttachment>[];
  }

  void loadHistoryEntry(AiChatHistoryEntry entry) {
    _currentSessionId = entry.id;
    _attachments = List<AiChatAttachment>.from(entry.attachments);
    state = AsyncData(List<ChatMessage>.from(entry.messages));
  }

  String? get currentSessionId => _currentSessionId;

  String _ensureSessionId() {
    return _currentSessionId ??= _generateSessionId();
  }

  String _generateSessionId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
