import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/service/ai/prompt_generate.dart';
import 'package:anx_reader/service/ai/index.dart';
import 'package:anx_reader/service/config/config_item.dart';
import 'package:anx_reader/service/translate/index.dart';
import 'package:anx_reader/widgets/ai/ai_stream.dart';
import 'package:flutter/material.dart';

class AiTranslateProvider extends TranslateServiceProvider {
  @override
  TranslateService get service => TranslateService.ai;

  @override
  String getLabel(BuildContext context) => L10n.of(context).navBarAI;

  /// AI translation uses native language names (e.g., "简体中文", "English")
  /// instead of ISO codes for better prompt understanding.
  @override
  String mapLanguageCode(LangListEnum lang) => lang.nativeName;

  @override
  Widget translate(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) {
    final prompt = isFullText
        ? generatePromptFullTextTranslate(
            text,
            mapLanguageCode(to),
            mapLanguageCode(from),
          )
        : generatePromptTranslate(
            text,
            mapLanguageCode(to),
            mapLanguageCode(from),
            contextText: contextText,
          );

    return AiStream(
      prompt: prompt,
      regenerate: true,
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
      final payload = isFullText
          ? generatePromptFullTextTranslate(
              text,
              mapLanguageCode(to),
              mapLanguageCode(from),
            )
          : generatePromptTranslate(
              text,
              mapLanguageCode(to),
              mapLanguageCode(from),
              contextText: contextText,
            );

      final messages = payload.buildMessages();

      await for (final result
          in aiGenerateStream(messages, regenerate: false)) {
        final value = result.trim();
        if (value.isEmpty) continue;
        // El motor de IA devuelve los fallos como texto ("Error: ...",
        // "RateLimitException", "at capacity"...). Para la selección se
        // convierten en excepción para saltar al respaldo instantáneo.
        if (!isFullText && looksLikeTranslationFailure(value)) {
          throw TranslationUnavailableException(value);
        }
        yield result;
      }
    } on TranslationUnavailableException {
      rethrow;
    } catch (e) {
      if (isFullText) {
        final context = navigatorKey.currentContext;
        final label =
            context == null ? 'Error: ' : L10n.of(context).translateError;
        yield '$label$e';
        return;
      }
      throw TranslationUnavailableException('$e');
    }
  }

  @override
  List<ConfigItem> getConfigItems(BuildContext context) {
    return [
      ConfigItem(
        key: 'tip',
        label: 'Tip',
        type: ConfigItemType.tip,
        defaultValue:
            L10n.of(navigatorKey.currentContext!).settingsTranslateAiTip,
      ),
    ];
  }
}
