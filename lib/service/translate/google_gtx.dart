import 'dart:convert';

import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/service/translate/index.dart';
import 'package:anx_reader/service/translate/language_tools.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Endpoints públicos de Google Translate (sin clave ni cuota).
///
/// `clients5` con `client=dict-chrome-ex` es el que usa la extensión de Chrome:
/// devuelve traducción, diccionario, definiciones, sinónimos y romanización, y
/// casi nunca responde 429. El endpoint `gtx` clásico se mantiene como
/// alternativa.
const List<List<String>> _gtxEndpoints = [
  [
    'https://clients5.google.com/translate_a/single',
    'dict-chrome-ex',
  ],
  [
    'https://translate.googleapis.com/translate_a/single',
    'gtx',
  ],
];

const String _gtxUserAgent =
    'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile '
    'Safari/537.36';

final Dio _gtxDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 12),
  responseType: ResponseType.plain,
  headers: const {'User-Agent': _gtxUserAgent, 'Accept': '*/*'},
));

/// Una definición de diccionario (`dt=md`).
class GtxDefinition {
  const GtxDefinition({this.partOfSpeech, required this.text});

  final String? partOfSpeech;
  final String text;
}

/// Una entrada de diccionario bilingüe (`dt=bd`).
class GtxDictionaryEntry {
  const GtxDictionaryEntry({
    this.partOfSpeech,
    this.terms = const [],
  });

  final String? partOfSpeech;
  final List<String> terms;
}

/// Resultado normalizado de una consulta a Google Translate.
class GtxTranslation {
  const GtxTranslation({
    required this.sourceText,
    required this.text,
    this.detectedLanguage,
    this.romanization,
    this.entries = const [],
    this.definitions = const [],
    this.synonyms = const [],
  });

  /// Texto original enviado a Google.
  final String sourceText;

  /// Traducción devuelta por Google.
  final String text;

  /// Idioma detectado por Google (`es`, `en`, `fr`...).
  final String? detectedLanguage;

  /// Romanización del original (idiomas con otro alfabeto).
  final String? romanization;

  /// Diccionario bilingüe: equivalentes en el idioma de destino.
  final List<GtxDictionaryEntry> entries;

  /// Definiciones monolingües del término original.
  final List<GtxDefinition> definitions;

  /// Sinónimos del término original.
  final List<String> synonyms;

  bool get isEmpty =>
      text.trim().isEmpty &&
      entries.isEmpty &&
      definitions.isEmpty &&
      synonyms.isEmpty;

  bool get hasDictionary =>
      entries.any((e) => e.terms.isNotEmpty) ||
      definitions.isNotEmpty ||
      synonyms.isNotEmpty;
}

/// Motor gratuito e instantáneo de Google Translate.
///
/// Se usa como traductor de la tarjeta de selección y como respaldo inmediato
/// cuando el proveedor configurado falla (429, 502, RateLimitException, …).
/// Maqueta el resultado según el idioma detectado: explicación/definición si
/// el fragmento ya está en el idioma de destino, traducción con pronunciación
/// figurada si está en otro idioma.
class GoogleGtxTranslateProvider extends TranslateServiceProvider {
  @override
  TranslateService get service => TranslateService.googleGtx;

  @override
  String getLabel(BuildContext context) => 'Google (rápido)';

  @override
  Widget translate(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) {
    return convertStreamToWidget(
      translateStream(text, from, to, isFullText: isFullText),
    );
  }

  @override
  Stream<String> translateStream(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) async* {
    final result = await GoogleGtx.smartTranslate(
      text,
      targetLanguage: mapLanguageCode(to),
      sourceLanguage: from == LangListEnum.auto ? null : mapLanguageCode(from),
      isFullText: isFullText,
    );
    if (result.trim().isNotEmpty) yield result;
  }

  /// Traduce [text] y devuelve solo el texto traducido.
  ///
  /// Con [isFullText] se devuelve la traducción limpia (sin encabezados) para
  /// no romper la traducción de capítulos completos.
  @override
  Future<String> translateTextOnly(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) {
    return GoogleGtx.smartTranslate(
      text,
      targetLanguage: mapLanguageCode(to),
      sourceLanguage: from == LangListEnum.auto ? null : mapLanguageCode(from),
      isFullText: isFullText,
    );
  }
}

/// Cliente de bajo nivel de Google Translate.
class GoogleGtx {
  const GoogleGtx._();

  /// Consulta Google Translate probando los endpoints disponibles.
  ///
  /// [maxLength] recorta el texto enviado (0 = sin límite) para no superar el
  /// tamaño máximo de una URL GET.
  static Future<GtxTranslation?> fetch(
    String text, {
    String? sourceLanguage,
    required String targetLanguage,
    bool withDictionary = true,
    int maxLength = 2000,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final query = (maxLength > 0 && trimmed.length > maxLength)
        ? '${trimmed.substring(0, maxLength)}…'
        : trimmed;

    Object? lastError;
    for (final endpoint in _gtxEndpoints) {
      final url = endpoint[0];
      final client = endpoint[1];
      try {
        final uri = Uri.parse(url).replace(queryParameters: {
          'client': client,
          'sl': (sourceLanguage == null || sourceLanguage.isEmpty)
              ? 'auto'
              : sourceLanguage,
          'tl': targetLanguage,
          'q': query,
        });
        final dt = withDictionary
            ? '&dt=t&dt=bd&dt=md&dt=rm&dt=ss'
            : '&dt=t';
        final response = await _gtxDio.get('${uri.toString()}$dt');

        final body = response.data is String
            ? response.data as String
            : response.data?.toString() ?? '';
        if (response.statusCode != 200 || body.trimLeft().startsWith('<')) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }

        final parsed = parse(
          body,
          sourceText: trimmed,
          withDictionary: withDictionary,
        );
        if (parsed != null) return parsed;
        lastError = 'respuesta vacía';
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Google Translate no respondió ($lastError)');
  }

  /// Traduce de forma inteligente y nunca lanza errores de capacidad.
  ///
  /// * Fragmento ya en [targetLanguage] → explicación / definición.
  /// * Fragmento en otro idioma → traducción + pronunciación figurada + matiz.
  static Future<String> smartTranslate(
    String text, {
    required String targetLanguage,
    String? sourceLanguage,
    bool isFullText = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final result = await fetch(
      trimmed,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      maxLength: isFullText ? 0 : 2000,
    );
    if (result == null) {
      throw Exception('Google Translate no devolvió ninguna traducción');
    }
    if (isFullText) return result.text;

    final detected =
        (result.detectedLanguage ?? detectLanguageCode(trimmed) ?? '')
            .toLowerCase();
    final target = targetLanguage.toLowerCase();
    final sameLanguage =
        detected.isNotEmpty && _sameLanguage(detected, target);

    String? support;
    if (sameLanguage && !result.hasDictionary) {
      // Google no siempre devuelve diccionario para frases largas: se genera
      // un significado de apoyo para que la tarjeta nunca quede vacía.
      support = await _supportMeaning(trimmed, detected, target);
    }

    return format(
      result,
      targetLanguage: targetLanguage,
      supportTranslation: support,
    );
  }

  /// Da formato legible al resultado según el idioma detectado.
  static String format(
    GtxTranslation result, {
    required String targetLanguage,
    String? supportTranslation,
  }) {
    final detected =
        (result.detectedLanguage ?? detectLanguageCode(result.sourceText) ?? '')
            .toLowerCase();
    final target = targetLanguage.toLowerCase();

    if (detected.isNotEmpty && _sameLanguage(detected, target)) {
      return _formatExplanation(result, supportTranslation);
    }
    return _formatTranslation(result, target, detected);
  }

  /// Extrae la información de la respuesta JSON de Google Translate.
  ///
  /// Índices usados:
  /// * `0`: frases traducidas (`dt=t`), la romanización va en `[3]`.
  /// * `1`: diccionario bilingüe (`dt=bd`).
  /// * `2`: idioma detectado.
  /// * `11`: sinónimos por acepción (`dt=ss`).
  /// * `12`: definiciones monolingües (`dt=md`).
  static GtxTranslation? parse(
    String body, {
    required String sourceText,
    bool withDictionary = true,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
    if (decoded is! List || decoded.isEmpty) return null;

    final buffer = StringBuffer();
    String? romanization;
    if (decoded[0] is List) {
      for (final segment in decoded[0] as List) {
        if (segment is! List || segment.isEmpty) continue;
        final text = segment.first;
        if (text is String) buffer.write(text);
        if (romanization == null &&
            segment.length > 3 &&
            segment[3] is String &&
            (segment[3] as String).trim().isNotEmpty) {
          romanization = (segment[3] as String).trim();
        }
      }
    }

    final detected = decoded.length > 2 && decoded[2] is String
        ? (decoded[2] as String).trim()
        : null;

    final entries = <GtxDictionaryEntry>[];
    if (withDictionary &&
        decoded.length > 1 &&
        decoded[1] is List &&
        (decoded[1] as List).isNotEmpty) {
      for (final raw in decoded[1] as List) {
        if (raw is! List || raw.isEmpty) continue;
        final partOfSpeech = raw.first is String ? raw.first as String : null;
        final terms = <String>[];
        if (raw.length > 1 && raw[1] is List) {
          for (final term in raw[1] as List) {
            if (term is String && term.trim().isNotEmpty) {
              terms.add(term.trim());
            }
          }
        }
        if (partOfSpeech != null || terms.isNotEmpty) {
          entries.add(GtxDictionaryEntry(
            partOfSpeech: partOfSpeech,
            terms: terms,
          ));
        }
      }
    }

    final definitions = withDictionary && decoded.length > 12
        ? _parseDefinitions(decoded[12])
        : const <GtxDefinition>[];
    final synonyms = withDictionary && decoded.length > 11
        ? _parseSynonyms(decoded[11])
        : const <String>[];

    final text = buffer.toString().trim();
    if (text.isEmpty &&
        entries.isEmpty &&
        definitions.isEmpty &&
        synonyms.isEmpty) {
      return null;
    }

    return GtxTranslation(
      sourceText: sourceText,
      text: text,
      detectedLanguage: detected,
      romanization: romanization,
      entries: entries,
      definitions: definitions,
      synonyms: synonyms,
    );
  }

  static List<GtxDefinition> _parseDefinitions(Object? raw) {
    final result = <GtxDefinition>[];
    if (raw is! List) return result;

    for (final group in raw) {
      if (group is! List || group.isEmpty) continue;
      final partOfSpeech = group.first is String ? group.first as String : null;
      if (group.length < 2 || group[1] is! List) continue;

      for (final item in group[1] as List) {
        String? value;
        if (item is List && item.isNotEmpty && item.first is String) {
          value = (item.first as String).trim();
        } else if (item is String) {
          value = item.trim();
        }
        if (value != null && value.isNotEmpty) {
          result.add(GtxDefinition(partOfSpeech: partOfSpeech, text: value));
        }
      }
    }
    return result;
  }

  static List<String> _parseSynonyms(Object? raw) {
    final result = <String>[];
    if (raw is! List) return result;

    for (final group in raw) {
      if (group is! List || group.length < 2 || group[1] is! List) continue;
      for (final sense in group[1] as List) {
        if (sense is! List || sense.isEmpty || sense.first is! List) continue;
        for (final synonym in sense.first as List) {
          if (synonym is String && synonym.trim().isNotEmpty) {
            result.add(synonym.trim());
          }
        }
      }
    }
    return result;
  }

  /// Significado de apoyo cuando no hay definición de diccionario (por
  /// ejemplo, una frase larga en el mismo idioma que el destino).
  static Future<String?> _supportMeaning(
    String text,
    String detected,
    String target,
  ) async {
    final supportTarget = target.startsWith('en') ? 'es' : 'en';
    try {
      final result = await fetch(
        text,
        sourceLanguage: detected.isEmpty ? null : detected,
        targetLanguage: supportTarget,
        withDictionary: false,
      );
      final meaning = result?.text.trim() ?? '';
      return meaning.isEmpty ? null : meaning;
    } catch (e) {
      AnxLog.warning('Google GTX support translation failed: $e');
      return null;
    }
  }

  static String _formatExplanation(
    GtxTranslation result,
    String? supportTranslation,
  ) {
    final buffer = StringBuffer('🧠 Explicación / Definición:');
    var hasContent = false;

    if (result.definitions.isNotEmpty) {
      String? lastPos;
      for (final definition in result.definitions.take(3)) {
        final pos = _localizedPartOfSpeech(definition.partOfSpeech);
        final prefix = (pos != null && pos.isNotEmpty && pos != lastPos)
            ? '($pos) '
            : '';
        lastPos = pos;
        buffer.write('\n• $prefix${definition.text}');
      }
      hasContent = true;
    }

    final synonyms = _unique(result.synonyms);
    if (synonyms.isNotEmpty) {
      buffer.write('\n• Sinónimos: ${synonyms.take(8).join(', ')}');
      hasContent = true;
    } else if (!hasContent && result.entries.isNotEmpty) {
      final terms = <String>[];
      for (final entry in result.entries) {
        terms.addAll(entry.terms);
      }
      if (terms.isNotEmpty) {
        buffer.write('\n• ${_unique(terms).take(8).join(', ')}');
        hasContent = true;
      }
    }

    if (!hasContent) {
      final meaning = (supportTranslation ?? '').trim();
      final excerpt = _excerpt(result.sourceText);
      if (meaning.isNotEmpty) {
        buffer.write('\n• «$excerpt» — sentido: $meaning');
      } else {
        buffer.write('\n• «$excerpt» — sin definición de diccionario '
            'disponible para este fragmento.');
      }
    }
    return buffer.toString();
  }

  static String _formatTranslation(
    GtxTranslation result,
    String target,
    String detected,
  ) {
    final targetIsSpanish = target.startsWith('es');
    final lines = <String>[];

    final translation = result.text.trim();
    if (translation.isNotEmpty) {
      lines.add('${targetIsSpanish ? '🇪🇸 ' : ''}Traducción: $translation');
    }

    final phonetic = _phonetic(result, detected);
    if (phonetic.isNotEmpty) {
      final isEnglish = detected.startsWith('en');
      // Google devuelve la transcripción IPA en la romanización: se añade
      // junto a la pronunciación figurada para hispanohablantes.
      final ipa = isEnglish ? (result.romanization?.trim() ?? '') : '';
      final suffix = (ipa.isNotEmpty && ipa != phonetic) ? ' (IPA: $ipa)' : '';
      if (targetIsSpanish) {
        lines.add(isEnglish
            ? '🗣️ Cómo se pronuncia (fonética española): [$phonetic]$suffix'
            : '🗣️ Pronunciación aproximada (romanización): [$phonetic]');
      } else {
        lines.add('🗣️ Pronunciación aproximada: [$phonetic]$suffix');
      }
    }

    final nuance = _nuance(result);
    if (nuance.isNotEmpty) {
      lines.add('💡 Matiz/Uso: $nuance');
    }

    if (lines.isEmpty) {
      return '«${_excerpt(result.sourceText)}»';
    }
    return lines.join('\n');
  }

  /// Pronunciación del texto original (no de la traducción).
  static String _phonetic(GtxTranslation result, String detected) {
    if (detected.startsWith('en')) {
      return englishPronunciationForSpanish(result.sourceText);
    }
    final romanization = result.romanization?.trim() ?? '';
    if (romanization.isNotEmpty) return romanization;
    return '';
  }

  static String _nuance(GtxTranslation result) {
    final parts = <String>[];
    for (final entry in result.entries.take(2)) {
      final pieces = <String>[];
      final pos = _localizedPartOfSpeech(entry.partOfSpeech);
      if (pos != null && pos.isNotEmpty) {
        pieces.add(pos);
      }
      if (entry.terms.isNotEmpty) {
        pieces.add(entry.terms.take(4).join(', '));
      }
      if (pieces.isNotEmpty) parts.add(pieces.join(': '));
    }
    return parts.join(' · ');
  }

  static const Map<String, String> _partOfSpeechEs = {
    'noun': 'sustantivo',
    'verb': 'verbo',
    'adjective': 'adjetivo',
    'adverb': 'adverbio',
    'pronoun': 'pronombre',
    'preposition': 'preposición',
    'conjunction': 'conjunción',
    'interjection': 'interjección',
    'determiner': 'determinante',
    'article': 'artículo',
    'numeral': 'numeral',
    'phrase': 'frase',
    'abbreviation': 'abreviatura',
    'prefix': 'prefijo',
    'suffix': 'sufijo',
    'particle': 'partícula',
  };

  /// Google devuelve la categoría gramatical en inglés (`noun`, `verb`...).
  static String? _localizedPartOfSpeech(String? partOfSpeech) {
    if (partOfSpeech == null) return null;
    final key = partOfSpeech.trim().toLowerCase();
    return _partOfSpeechEs[key] ?? partOfSpeech;
  }

  static List<String> _unique(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      if (seen.add(value.toLowerCase())) result.add(value);
    }
    return result;
  }

  static String _excerpt(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 90) return compact;
    return '${compact.substring(0, 87)}…';
  }

  static bool _sameLanguage(String a, String b) {
    String base(String code) => code.split(RegExp(r'[-_]')).first;
    return base(a) == base(b);
  }
}
