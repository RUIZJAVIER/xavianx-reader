import 'dart:convert';

import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/service/translate/index.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

const _urlGoogleGtx = 'https://translate.googleapis.com/translate_a/single';

/// Traducción gratuita e inmediata mediante el endpoint público de Google
/// (GTX). No necesita clave de API ni cuota, por lo que sirve como motor
/// principal de la traducción de selección y como respaldo automático cuando
/// el proveedor configurado falla (429, 502, RateLimitException...).
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
      translateStream(text, from, to, contextText: contextText),
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
    try {
      yield await translateTextOnly(text, from, to);
    } catch (e) {
      AnxLog.warning('Google GTX translation failed: $e');
      yield* Stream.error(Exception(e));
    }
  }

  /// Traduce [text] y devuelve solo el texto traducido.
  @override
  Future<String> translateTextOnly(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) async {
    if (text.trim().isEmpty) return '';

    final params = <String, String>{
      'client': 'gtx',
      'sl': from == LangListEnum.auto ? 'auto' : mapLanguageCode(from),
      'tl': mapLanguageCode(to),
      'dt': 't',
      'q': text,
    };
    final uri = Uri.parse(_urlGoogleGtx).replace(queryParameters: params);

    final response = await Dio().get(
      uri.toString(),
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
        },
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Google GTX error: ${response.statusCode}');
    }

    final body = response.data is String
        ? response.data as String
        : response.data?.toString() ?? '';
    final decoded = _parseGtxResponse(body);
    if (decoded.isEmpty) {
      throw Exception('Google GTX returned an empty translation');
    }
    return decoded;
  }

  /// Extrae el texto traducido de la respuesta JSON de GTX.
  ///
  /// Formato: `[["texto","original",null,null,10]],null,"en",...]`
  static String _parseGtxResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return '';
    }

    if (decoded is! List || decoded.isEmpty) return '';

    final buffer = StringBuffer();
    for (final segment in decoded) {
      if (segment is! List || segment.isEmpty) continue;
      final text = segment.first;
      if (text is String) buffer.write(text);
    }
    return buffer.toString().trim();
  }
}
