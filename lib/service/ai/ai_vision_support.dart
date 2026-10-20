import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/ai_provider.dart';
import 'package:anx_reader/service/ai/ai_key_rotator.dart';
import 'package:anx_reader/utils/log/common.dart';

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
