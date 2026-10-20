import 'dart:convert';
import 'dart:typed_data';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/ai_provider.dart';
import 'package:anx_reader/service/ai/ai_key_rotator.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:image/image.dart' as img;

/// Resolved AI settings (URL + API key + model) used for one vision request.
class AiVisionConfig {
  const AiVisionConfig({
    required this.url,
    required this.apiKey,
    required this.model,
    this.providerId,
  });

  final String url;
  final String apiKey;
  final String model;
  final String? providerId;
}

/// Shared helpers for the AI-vision features (OCR and multimodal chat).
///
/// Both features talk to the same OpenAI-compatible endpoint configured in the
/// app's AI settings, so the provider-selection and endpoint-normalization
/// logic lives here once.
class AiVisionSupport {
  AiVisionSupport._();

  /// Vision requests are kept small to avoid gateway 502s and provider rate
  /// limits caused by multi-megapixel base64 payloads.
  static const int maxVisionImageSide = 1280;
  static const int visionJpegQuality = 80;

  /// Resizes [bytes] so its longest side is at most [maxVisionImageSide] and
  /// re-encodes it as JPEG at [visionJpegQuality].
  ///
  /// Images that are already small JPEGs are returned untouched to avoid
  /// recompressing them on every send/regenerate.
  static Uint8List prepareImageForVision(Uint8List bytes) {
    if (bytes.isEmpty) {
      return bytes;
    }

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return bytes;
      }

      final oriented = img.bakeOrientation(decoded);
      final longestSide =
          oriented.width > oriented.height ? oriented.width : oriented.height;
      final alreadyJpeg =
          bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

      if (longestSide <= maxVisionImageSide && alreadyJpeg) {
        return bytes;
      }

      img.Image output = oriented;
      if (longestSide > maxVisionImageSide) {
        final scale = maxVisionImageSide / longestSide;
        output = img.copyResize(
          oriented,
          width: (oriented.width * scale).round(),
          height: (oriented.height * scale).round(),
          interpolation: img.Interpolation.linear,
        );
      }

      return img.encodeJpg(output, quality: visionJpegQuality);
    } catch (e) {
      AnxLog.warning('AiVisionSupport: failed to prepare image: $e');
      return bytes;
    }
  }

  /// Builds the OpenAI-compatible `image_url` data URI after normalizing the
  /// image size and format.
  static String visionDataUrl(Uint8List bytes) {
    final prepared = prepareImageForVision(bytes);
    return 'data:${_mimeType(prepared)};base64,${base64Encode(prepared)}';
  }

  static String _mimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 2 && bytes[0] == 0x47 && bytes[1] == 0x49) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }

  /// Resolves the AI settings from the new provider system, falling back to
  /// the legacy `aiConfig_*` storage when no provider is available.
  ///
  /// [providerId] optionally forces a specific provider; when null, the
  /// currently selected provider (or the first enabled one) is used.
  static AiVisionConfig? resolveConfig([String? providerId]) {
    final provider = _pickProvider(providerId);
    if (provider != null) {
      final key = AiKeyRotator.getNextKey(provider) ?? provider.currentApiKey;
      final url = provider.url.trim();
      final model = provider.model.trim();
      if (url.isNotEmpty &&
          model.isNotEmpty &&
          key != null &&
          key.trim().isNotEmpty) {
        return AiVisionConfig(
          url: url,
          apiKey: key.trim(),
          model: model,
          providerId: provider.id,
        );
      }
    }

    return _resolveLegacyConfig(providerId);
  }

  static AiProvider? _pickProvider(String? providerId) {
    final rawProviders = Prefs().getAiProviders();
    if (rawProviders.isEmpty) {
      return null;
    }

    List<AiProvider> providers;
    try {
      providers = rawProviders
          .map((json) => AiProvider.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AnxLog.warning('AiVisionSupport: failed to parse AI providers: $e');
      return null;
    }

    if (providerId != null && providerId.isNotEmpty) {
      for (final p in providers) {
        if (p.id == providerId) {
          return p;
        }
      }
    }

    final selectedId = Prefs().selectedAiService;
    for (final p in providers) {
      if (p.id == selectedId && p.enabled) {
        return p;
      }
    }

    for (final p in providers) {
      if (p.enabled &&
          AiKeyRotator.hasValidKey(p) &&
          p.model.trim().isNotEmpty) {
        return p;
      }
    }

    return null;
  }

  static AiVisionConfig? _resolveLegacyConfig(String? providerId) {
    final identifier =
        (providerId != null && providerId.isNotEmpty)
            ? providerId
            : Prefs().selectedAiService;
    final legacy = Prefs().getAiConfig(identifier);
    if (legacy.isEmpty) {
      return null;
    }

    final url = (legacy['url'] ?? '').trim();
    final apiKey = (legacy['api_key'] ?? '').trim();
    final model = (legacy['model'] ?? '').trim();

    if (url.isEmpty ||
        model.isEmpty ||
        apiKey.isEmpty ||
        apiKey == 'YOUR_API_KEY') {
      return null;
    }

    return AiVisionConfig(
      url: url,
      apiKey: apiKey,
      model: model,
      providerId: identifier,
    );
  }

  /// Normalizes the stored provider URL into a chat-completions endpoint.
  ///
  /// Many providers store the full endpoint (e.g. `.../v1/chat/completions`),
  /// but some store only the base URL (`.../v1`), so the suffix is appended
  /// when missing.
  static Uri resolveEndpoint(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('AI provider URL is empty');
    }

    final uri = Uri.parse(trimmed);
    final path = uri.path.toLowerCase();

    if (path.endsWith('/chat/completions') ||
        path.endsWith('/completions') ||
        path.endsWith('/messages')) {
      return uri;
    }

    final sanitizedPath = path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;

    final suffix = sanitizedPath.endsWith('/v1')
        ? '/chat/completions'
        : '/v1/chat/completions';
    return uri.replace(path: '$sanitizedPath$suffix');
  }

  static String truncateBody(String body, [int max = 500]) =>
      body.length > max ? body.substring(0, max) : body;
}
