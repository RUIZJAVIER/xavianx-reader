import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anx_reader/service/ai/ai_vision_support.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:http/http.dart' as http;

/// One turn of a multimodal conversation.
///
/// [role] is either `user` or `assistant`. [images] are only honored for
/// `user` turns and are embedded as base64 `image_url` data URIs.
class AiVisionTurn {
  const AiVisionTurn({
    required this.role,
    required this.text,
    this.images = const <Uint8List>[],
  });

  final String role;
  final String text;
  final List<Uint8List> images;
}

/// Raised when a multimodal request cannot be performed.
class AiVisionChatException implements Exception {
  const AiVisionChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Multimodal chat against the user's configured OpenAI-compatible provider
/// (e.g. Token Harbor / DeepSeek).
///
/// This is the path used when the chat or the reader sends a screenshot: the
/// image is embedded as a base64 `image_url` data URI, which the vision-capable
/// model analyzes. It reuses the same provider URL, API key rotation and model
/// as the rest of the app's AI features.
class AiVisionChatService {
  const AiVisionChatService();

  static const String defaultSystemPrompt = '''
You are "Anx Reader AI", an intelligent reading assistant that can see images.
The user attaches screenshots of book pages, notes, highlights or scanned
pages (books, PDFs, handwritten notes).

Rules:
- Look carefully at every attached image before answering.
- Ground your answer in what is actually visible in the images and in the
  conversation context. Never invent text that is not in the images.
- When the user asks to extract, transcribe or read text, return the clean text
  in its natural reading order, ignoring stains, shadows, fingers, page numbers
  and scan noise.
- Answer in the same language the user writes in.
''';

  /// Streams the assistant answer, yielding the accumulated text so far.
  Stream<String> stream({
    required List<AiVisionTurn> turns,
    String? providerId,
    String systemPrompt = defaultSystemPrompt,
    Duration timeout = const Duration(seconds: 180),
  }) async* {
    final AiVisionConfig? config = AiVisionSupport.resolveConfig(providerId);
    if (config == null) {
      throw const AiVisionChatException(
          'No AI provider configured for visual analysis.');
    }

    final Uri endpoint;
    try {
      endpoint = AiVisionSupport.resolveEndpoint(config.url);
    } catch (e) {
      throw AiVisionChatException('Invalid AI provider URL: $e');
    }

    final payload = <String, dynamic>{
      'model': config.model,
      'temperature': 0.3,
      'stream': true,
      'messages': _buildMessages(turns, systemPrompt),
    };

    final request = http.Request('POST', endpoint)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${config.apiKey}'
      ..body = jsonEncode(payload);

    final client = http.Client();
    try {
      final response = await client.send(request).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        AnxLog.severe('Vision chat HTTP ${response.statusCode} for $endpoint: '
            '${AiVisionSupport.truncateBody(body)}');
        throw AiVisionChatException(
            'AI vision request failed (${response.statusCode})');
      }

      final contentType =
          (response.headers['content-type'] ?? '').toLowerCase();
      if (contentType.contains('text/event-stream')) {
        yield* _streamSse(response);
      } else {
        final body = await response.stream.bytesToString();
        final text = _extractContentText(body);
        if (text.isNotEmpty) {
          yield text;
        }
      }
    } on TimeoutException {
      throw const AiVisionChatException('AI vision request timed out');
    } finally {
      client.close();
    }
  }

  Stream<String> _streamSse(http.StreamedResponse response) async* {
    final buffer = StringBuffer();
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data:')) {
        continue;
      }
      final data = line.substring(5).trim();
      if (data.isEmpty) {
        continue;
      }
      if (data == '[DONE]') {
        break;
      }
      try {
        final delta = _extractChoiceContent(jsonDecode(data));
        if (delta != null && delta.isNotEmpty) {
          buffer.write(delta);
          yield buffer.toString();
        }
      } catch (_) {
        // Ignore keep-alive or malformed chunks.
      }
    }
  }

  List<Map<String, dynamic>> _buildMessages(
    List<AiVisionTurn> turns,
    String systemPrompt,
  ) {
    final messages = <Map<String, dynamic>>[];
    if (systemPrompt.trim().isNotEmpty) {
      messages.add(<String, dynamic>{
        'role': 'system',
        'content': systemPrompt,
      });
    }

    for (final turn in turns) {
      final role = turn.role == 'assistant' ? 'assistant' : 'user';
      if (role == 'user' && turn.images.isNotEmpty) {
        final parts = <Map<String, dynamic>>[];
        if (turn.text.trim().isNotEmpty) {
          parts.add(<String, dynamic>{
            'type': 'text',
            'text': turn.text,
          });
        }
        for (final bytes in turn.images) {
          parts.add(<String, dynamic>{
            'type': 'image_url',
            'image_url': <String, dynamic>{
              'url': 'data:image/png;base64,${base64Encode(bytes)}',
            },
          });
        }
        messages.add(<String, dynamic>{'role': role, 'content': parts});
      } else if (turn.text.trim().isNotEmpty || turn.images.isEmpty) {
        messages.add(<String, dynamic>{'role': role, 'content': turn.text});
      }
    }

    return messages;
  }

  String _extractContentText(String body) {
    try {
      return _extractChoiceContent(jsonDecode(body)) ?? '';
    } catch (e) {
      AnxLog.warning('Vision chat: failed to parse response: $e');
      return '';
    }
  }

  /// Reads `choices[0].delta.content`, `choices[0].message.content` or the
  /// legacy `choices[0].text`.
  String? _extractChoiceContent(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }
    final first = choices.first;
    if (first is! Map) {
      return null;
    }

    final delta = first['delta'];
    if (delta is Map) {
      final text = _contentToText(delta['content']);
      if (text != null) {
        return text;
      }
    }

    final message = first['message'];
    if (message is Map) {
      final text = _contentToText(message['content']);
      if (text != null) {
        return text;
      }
    }

    return _contentToText(first['text']);
  }

  String? _contentToText(dynamic content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text']);
        }
      }
      return buffer.toString();
    }
    return null;
  }
}
