import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anx_reader/service/ai/ai_vision_support.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:http/http.dart' as http;

/// Result of an AI-vision OCR request.
class AiVisionOcrResult {
  const AiVisionOcrResult({
    required this.success,
    this.text = '',
    this.error,
  });

  final bool success;
  final String text;
  final String? error;

  const AiVisionOcrResult.failure(String message)
      : success = false,
        text = '',
        error = message;

  @override
  String toString() => 'AiVisionOcrResult(success: $success, '
      'length: ${text.length}, error: $error)';
}

/// Extracts text from a screenshot image using the AI provider configured in
/// the app's AI settings (URL, API key and model).
///
/// The request is an OpenAI-compatible multimodal chat completion: the image
/// is embedded as a base64 `image_url` data URI, which is accepted by OpenAI
/// and most compatible gateways (e.g. DashScope compatible-mode, DeepSeek,
/// OpenRouter, ...).
class AiVisionOcrService {
  const AiVisionOcrService();

  /// System prompt: extract only the clean page text, in natural reading
  /// order, ignoring stains / scan noise.
  static const String defaultSystemPrompt = '''
You are a precise OCR engine. The user sends you a screenshot of a scanned or
photocopied book page (a page that has no selectable text layer).

Your task:
- Extract ONLY the clean, readable text of the page.
- Follow the page's natural reading order (top to bottom, left to right; for
  vertical script follow its natural order).
- Reconstruct words, hyphenated line breaks and paragraphs correctly.
- Ignore everything that is not body text: stains, smudges, ink blots, scan
  noise, shadows, fingers, page numbers, running headers/footers, decorative
  rules and images.
- Do NOT describe the image. Do NOT add titles, comments, markdown, code
  fences, quotes, translations or explanations of your own.
- Preserve paragraph breaks as single line breaks.

If the image contains no readable text at all, return an empty string.
''';

  /// Human-facing instruction that accompanies the image.
  static const String _userInstruction =
      'Extract the clean text of this page in its natural reading order. '
      'Output only the text.';

  /// Runs OCR on [imageBytes] using the user's configured AI provider.
  ///
  /// [providerId] optionally forces a specific provider; when null, the
  /// currently selected provider (or the first enabled one) is used.
  Future<AiVisionOcrResult> extractText(
    Uint8List imageBytes, {
    String? providerId,
    String systemPrompt = defaultSystemPrompt,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (imageBytes.isEmpty) {
      return const AiVisionOcrResult.failure('Empty screenshot');
    }

    final AiVisionConfig? config = AiVisionSupport.resolveConfig(providerId);
    if (config == null) {
      return const AiVisionOcrResult.failure(
          'No AI provider configured for vision OCR');
    }

    final Uri endpoint;
    try {
      endpoint = AiVisionSupport.resolveEndpoint(config.url);
    } catch (e) {
      return AiVisionOcrResult.failure('Invalid AI provider URL: $e');
    }

    final String dataUrl = AiVisionSupport.visionDataUrl(imageBytes);

    final Map<String, dynamic> payload = <String, dynamic>{
      'model': config.model,
      'temperature': 0,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'system',
          'content': systemPrompt,
        },
        <String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'text',
              'text': _userInstruction,
            },
            <String, dynamic>{
              'type': 'image_url',
              'image_url': <String, dynamic>{'url': dataUrl},
            },
          ],
        },
      ],
    };

    try {
      final http.Response response = await http
          .post(
            endpoint,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = _safeBody(response.body);
        AnxLog.severe(
            'Vision OCR HTTP ${response.statusCode} for $endpoint: $body');
        return AiVisionOcrResult.failure(
            'AI vision request failed (${response.statusCode})');
      }

      final String text = _parseContent(response.body);
      if (text.isEmpty) {
        AnxLog.warning('Vision OCR returned no text for $endpoint');
      }
      return AiVisionOcrResult(success: true, text: text);
    } on TimeoutException {
      return const AiVisionOcrResult.failure('AI vision request timed out');
    } catch (e) {
      AnxLog.severe('Vision OCR request failed: $e');
      return AiVisionOcrResult.failure('AI vision request failed: $e');
    }
  }

  String _parseContent(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return '';
      }

      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String) {
              return content.trim();
            }
            if (content is List) {
              // Some gateways return content blocks instead of a string.
              final buffer = StringBuffer();
              for (final block in content) {
                if (block is Map && block['text'] is String) {
                  buffer.write(block['text']);
                }
              }
              return buffer.toString().trim();
            }
          }
          // Legacy/completion style responses.
          final text = first['text'];
          if (text is String) {
            return text.trim();
          }
        }
      }
    } catch (e) {
      AnxLog.warning('Vision OCR: failed to parse response: $e');
    }
    return '';
  }

  String _safeBody(String body) =>
      body.length > 500 ? body.substring(0, 500) : body;
}
