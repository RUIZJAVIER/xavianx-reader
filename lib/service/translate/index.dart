import 'dart:core';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/config/config_item.dart';
import 'package:anx_reader/service/translate/ai.dart';
import 'package:anx_reader/service/translate/deepl.dart';
import 'package:anx_reader/service/translate/google_api.dart';
import 'package:anx_reader/service/translate/google_gtx.dart';
import 'package:anx_reader/service/translate/microsoft_api.dart';
import 'package:anx_reader/service/translate/web_view.dart';
import 'package:anx_reader/utils/env_var.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum TranslateService {
  bingWeb,
  googleWeb,
  microsoftApi,
  googleApi,
  googleGtx,
  deepl,
  ai;

  TranslateServiceProvider get provider {
    switch (this) {
      case TranslateService.bingWeb:
        return BingWebTranslateProvider();
      case TranslateService.googleWeb:
        return GoogleWebTranslateProvider();
      case TranslateService.microsoftApi:
        return MicrosoftApiTranslateProvider();
      case TranslateService.googleApi:
        return GoogleApiTranslateProvider();
      case TranslateService.googleGtx:
        return GoogleGtxTranslateProvider();
      case TranslateService.deepl:
        return DeepLTranslateProvider();
      case TranslateService.ai:
        return AiTranslateProvider();
    }
  }

  /// Get the display label from the provider.
  String getLabel(BuildContext context) => provider.getLabel(context);

  /// Check if the service is a WebView provider.
  bool get isWebView => provider is WebViewTranslateProvider;

  static List<TranslateService> get activeValues => values
      .where((e) => e != TranslateService.ai || EnvVar.enableAIFeature)
      .toList();
}

TranslateService getTranslateService(String name) {
  if (name == 'microsoft') {
    return TranslateService.microsoftApi;
  }

  try {
    return TranslateService.values.firstWhere((e) => e.name == name);
  } catch (e) {
    return TranslateService.bingWeb;
  }
}

/// Base class for all translation service providers.
/// Subclasses must implement [service], [label], [translate], and [translateStream].
abstract class TranslateServiceProvider {
  /// The service enum value this provider corresponds to.
  TranslateService get service;

  /// The display label for this service.
  String getLabel(BuildContext context);

  /// Override this method if the service uses a different code format.
  /// Default implementation returns [lang.code].
  String mapLanguageCode(LangListEnum lang) => lang.code;

  /// Get the configuration items for this service.
  List<ConfigItem> getConfigItems(BuildContext context) {
    return [];
  }

  /// Returns the widget for displaying the translation result.
  Widget translate(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
  });

  /// Returns a stream of translation results.
  Stream<String> translateStream(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  });

  /// Translate text only (no widget), with retry logic.
  Future<String> translateTextOnly(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) async {
    const int maxRetries = 2;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        String? lastResult;
        await for (String result in translateStream(
          text,
          from,
          to,
          contextText: contextText,
          isFullText: isFullText,
        )) {
          lastResult = result;
        }

        if (lastResult != null &&
            lastResult.trim().isNotEmpty &&
            lastResult != '...') {
          return lastResult;
        }

        throw Exception(
            'Translation returned no valid result: ${lastResult ?? 'No result'}');
      } catch (e) {
        if (attempt < maxRetries) {
          AnxLog.warning(
              'Translation attempt ${attempt + 1} failed with exception: $e. Retrying...');
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          continue;
        } else {
          throw Exception(
              'Translation failed after ${maxRetries + 1} attempts: $e');
        }
      }
    }

    throw Exception('Translation failed after all retry attempts');
  }

  /// Returns the current configuration.
  Map<String, dynamic> getConfig() => {};

  /// Saves the configuration.
  void saveConfig(Map<String, dynamic> config) {}

  /// Helper to convert a stream to a widget with copy button.
  Widget convertStreamToWidget(Stream<String> stream) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snapshot) {
        Widget content() {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('...');
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (snapshot.hasData) {
            return Text(snapshot.data!);
          } else {
            return const Text('');
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            content(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: snapshot.data!)),
                    child: Text(L10n.of(context).commonCopy))
              ],
            )
          ],
        );
      },
    );
  }
}

// ============================================================================
// Helper functions (use service.provider instead of TranslateFactory)
// ============================================================================

Widget translateText(String text,
    {TranslateService? service, String? contextText}) {
  service ??= Prefs().translateService;
  final from = Prefs().translateFrom;
  final to = Prefs().translateTo;

  return service.provider.translate(
    text,
    from,
    to,
    contextText: contextText,
  );
}

List<ConfigItem> getTranslateServiceConfigItems(
    BuildContext context, TranslateService service) {
  return service.provider.getConfigItems(context);
}

Map<String, dynamic> getTranslateServiceConfig(TranslateService service) {
  return service.provider.getConfig();
}

void saveTranslateServiceConfig(
    TranslateService service, Map<String, dynamic> config) {
  return service.provider.saveConfig(config);
}

Future<String> translateTextOnly(String text,
    {TranslateService? service, String? contextText}) async {
  service ??= Prefs().translateService;
  final from = Prefs().translateFrom;
  final to = Prefs().translateTo;

  return await service.provider.translateTextOnly(
    text,
    from,
    to,
    contextText: contextText,
  );
}

// ============================================================================
// Traducción inteligente de selecciones
// ============================================================================

/// El proveedor configurado no puede responder (capacidad, cuota, red, …).
///
/// Es una señal interna: nunca debe mostrarse al lector, solo provoca el
/// cambio inmediato al respaldo de Google GTX.
class TranslationUnavailableException implements Exception {
  TranslationUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'TranslationUnavailableException: $message';
}

const List<String> _translationFailureMarkers = [
  'ratelimitexception',
  'rate limit',
  'rate_limit',
  'ratelimit',
  'too many requests',
  'at capacity',
  'quota',
  'resource_exhausted',
  'resource exhausted',
  'overloaded',
  'timed out',
  'timeout',
  'connection error',
  'network error',
  'socketexception',
  'bad gateway',
  'service unavailable',
  'gateway timeout',
  'internal server error',
];

/// ¿El texto es un error/capacidad en lugar de una traducción válida?
bool looksLikeTranslationFailure(String? value) {
  if (value == null) return true;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '...') return true;

  final lower = trimmed.toLowerCase();
  if (lower.startsWith('error') || lower.startsWith('exception')) return true;

  // Las respuestas con el formato esperado ya son contenido real: aunque
  // mencionen palabras como «timeout» no deben descartarse.
  if (trimmed.contains('Explicación:') || trimmed.contains('Traducción:')) {
    return false;
  }

  if (_translationFailureMarkers.any(lower.contains)) return true;

  // Códigos HTTP de capacidad solo cuando el texto parece un mensaje de error.
  final hasHttpCode = RegExp(r'\b(429|502|503|504)\b').hasMatch(lower);
  if (hasHttpCode &&
      (lower.contains('error') ||
          lower.contains('http') ||
          lower.contains('status') ||
          lower.contains('code') ||
          lower.contains('server') ||
          lower.contains('rate'))) {
    return true;
  }
  return false;
}

/// Traduce una selección de forma inteligente y a prueba de errores.
///
/// 1. Se lanza el proveedor configurado con un vigilante de [timeout]: si
///    responde con un error de capacidad (`429`, `502`,
///    `RateLimitException`, `at capacity`, …) o no emite texto a tiempo, se
///    cambia en ese mismo instante a [GoogleGtxTranslateProvider].
/// 2. Google GTX maqueta el resultado según el idioma detectado:
///    - texto ya en el idioma de destino → explicación / definición;
///    - texto en otro idioma → traducción + pronunciación figurada en español.
/// 3. Nunca se emite un mensaje de error en pantalla.
///
/// Los proveedores basados en WebView no exponen stream: en ese caso no se
/// emite nada y la tarjeta muestra directamente su widget.
Stream<String> smartTranslateSelectionStream(
  String text, {
  LangListEnum? from,
  LangListEnum? to,
  String? contextText,
  Duration timeout = const Duration(seconds: 4),
}) async* {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;

  final fromLang = from ?? Prefs().translateFrom;
  final toLang = to ?? Prefs().translateTo;
  final service = Prefs().translateService;

  // Los proveedores WebView se dibujan con su propio widget.
  if (service.isWebView) return;

  var emitted = false;
  var lastEmitted = '';
  try {
    final chunks = service.provider
        .translateStream(
          trimmed,
          fromLang,
          toLang,
          contextText: contextText,
        )
        .timeout(timeout, onTimeout: (sink) {
      sink.addError(TranslationUnavailableException(
          'El proveedor no respondió en ${timeout.inSeconds}s'));
      sink.close();
    });

    await for (final chunk in chunks) {
      final value = chunk.trim();
      // Marcadores de progreso de algunos proveedores.
      if (value.isEmpty || value == '...') continue;
      if (looksLikeTranslationFailure(value)) {
        throw TranslationUnavailableException(value);
      }
      emitted = true;
      lastEmitted = chunk;
      yield chunk;
    }
  } catch (e) {
    AnxLog.warning('Traducción inteligente: cambio a Google GTX ($e)');
  }

  // Si el proveedor falló pero ya había escrito una respuesta completa, se
  // conserva; si era un fragmento corto, GTX la sustituye por una completa.
  if (emitted && lastEmitted.trim().length >= 120) return;

  // Respaldo instantáneo: Google GTX, sin errores de capacidad.
  try {
    final result = await GoogleGtx.smartTranslate(
      trimmed,
      targetLanguage: GoogleGtxTranslateProvider().mapLanguageCode(toLang),
      sourceLanguage: fromLang == LangListEnum.auto
          ? null
          : GoogleGtxTranslateProvider().mapLanguageCode(fromLang),
    );
    if (result.trim().isNotEmpty) {
      yield result;
      return;
    }
  } catch (e) {
    AnxLog.warning('Traducción inteligente: Google GTX también falló ($e)');
  }

  yield 'No se pudo obtener la traducción. Revisa tu conexión e inténtalo '
      'de nuevo.';
}
