import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/ai_prompts.dart';
import 'package:langchain_core/chat_models.dart';
import 'package:langchain_core/prompts.dart';

class PromptTemplatePayload {
  const PromptTemplatePayload({
    required this.template,
    required this.variables,
    required this.identifier,
  });

  final ChatPromptTemplate template;
  final Map<String, dynamic> variables;
  final AiPrompts identifier;

  List<ChatMessage> buildMessages() {
    try {
      return template.formatPrompt(variables).toChatMessages();
    } catch (e) {
      Prefs().deleteAiPrompt(identifier);
      final prompt = Prefs().getAiPrompt(identifier);
      final normalized = _normalizePrompt(prompt);
      final template = ChatPromptTemplate.fromPromptMessages([
        HumanChatMessagePromptTemplate.fromTemplate(normalized),
      ]);
      return template.formatPrompt(variables).toChatMessages();
    }
  }

  String buildString() {
    return buildMessages().last.contentAsString;
  }
}

PromptTemplatePayload generatePromptTest() {
  final prompt = Prefs().getAiPrompt(AiPrompts.test);
  final normalized = _normalizePrompt(prompt);
  final template = ChatPromptTemplate.fromPromptMessages([
    HumanChatMessagePromptTemplate.fromTemplate(normalized),
  ]);
  final currentLocale = Prefs().locale?.languageCode ?? Platform.localeName;
  return PromptTemplatePayload(
    template: template,
    variables: {'language_locale': currentLocale},
    identifier: AiPrompts.test,
  );
}

PromptTemplatePayload generatePromptSummaryTheChapter() {
  final prompt = Prefs().getAiPrompt(AiPrompts.summaryTheChapter);
  final normalized = _normalizePrompt(prompt);
  final template = ChatPromptTemplate.fromPromptMessages([
    HumanChatMessagePromptTemplate.fromTemplate(normalized),
  ]);
  return PromptTemplatePayload(
    template: template,
    variables: {},
    identifier: AiPrompts.summaryTheChapter,
  );
}

PromptTemplatePayload generatePromptSummaryTheBook() {
  final prompt = Prefs().getAiPrompt(AiPrompts.summaryTheBook);
  final normalized = _normalizePrompt(prompt);
  final template = ChatPromptTemplate.fromPromptMessages([
    HumanChatMessagePromptTemplate.fromTemplate(normalized),
  ]);
  return PromptTemplatePayload(
    template: template,
    variables: {},
    identifier: AiPrompts.summaryTheBook,
  );
}

PromptTemplatePayload generatePromptMindmap() {
  final prompt = Prefs().getAiPrompt(AiPrompts.mindmap);
  final normalized = _normalizePrompt(prompt);
  final template = ChatPromptTemplate.fromPromptMessages([
    HumanChatMessagePromptTemplate.fromTemplate(normalized),
  ]);
  return PromptTemplatePayload(
    template: template,
    variables: {},
    identifier: AiPrompts.mindmap,
  );
}

PromptTemplatePayload generatePromptSummaryThePreviousContent(
    String previousContent) {
  final prompt = Prefs().getAiPrompt(AiPrompts.summaryThePreviousContent);
  final normalized = _normalizePrompt(prompt);
  final template = ChatPromptTemplate.fromPromptMessages([
    HumanChatMessagePromptTemplate.fromTemplate(normalized),
  ]);
  return PromptTemplatePayload(
    template: template,
    variables: {
      'previous_content': previousContent.trim(),
    },
    identifier: AiPrompts.summaryThePreviousContent,
  );
}

PromptTemplatePayload generatePromptTranslate(
    String text, String toLocale, String fromLocale,
    {String? contextText}) {
  final stored = Prefs().getAiPrompt(AiPrompts.translate);
  // Los prompts guardados de versiones anteriores (o personalizados) no
  // conocen el formato inteligente: se les añade el contrato de salida para
  // que la tarjeta de traducción se comporte igual para todos los usuarios.
  final prompt = stored.contains(_smartTranslationMarker)
      ? stored
      : '$stored\n\n$_smartTranslationContract';
  final normalized = _normalizePrompt(prompt);
  final template = ChatPromptTemplate.fromPromptMessages([
    HumanChatMessagePromptTemplate.fromTemplate(normalized),
  ]);
  return PromptTemplatePayload(
    template: template,
    variables: {
      'text': text.trim(),
      'to_locale': toLocale,
      'from_locale': fromLocale,
      'contextText': (contextText ?? '').trim(),
    },
    identifier: AiPrompts.translate,
  );
}

/// Marca que identifica los prompts de traducción ya actualizados.
const String _smartTranslationMarker = 'Explicación';

/// Contrato de salida del traductor inteligente de selecciones.
const String _smartTranslationContract = '''
Formato de salida obligatorio (tiene prioridad sobre cualquier formato anterior):
- Si el fragmento YA está en {{to_locale}}: responde solo con
🧠 Explicación: <explicación breve, clara y directa en el contexto de lectura; si es una palabra o expresión corta, añade su definición y 2-3 sinónimos clave>
- Si el fragmento está en otro idioma: responde solo con
🇪🇸 Traducción: <traducción natural y precisa>
🗣️ Cómo se pronuncia (fonética española): [<pronunciación figurada para un hispanohablante, fácil de leer en voz alta, con las sílabas separadas por guiones>]
💡 Matiz/Uso: <una línea breve sobre el matiz o el uso; omítela solo si no aporta nada>
Mantén los encabezados tal cual, con su emoji. No añadas preámbulos, listas, markdown ni secciones adicionales.''';

PromptTemplatePayload generatePromptFullTextTranslate(
    String text, String toLocale, String fromLocale) {
  final prompt = Prefs().getAiPrompt(AiPrompts.fullTextTranslate);
  final normalized = _normalizePrompt(prompt);
  final template = ChatPromptTemplate.fromPromptMessages([
    HumanChatMessagePromptTemplate.fromTemplate(normalized),
  ]);
  return PromptTemplatePayload(
    template: template,
    variables: {
      'text': text.trim(),
      'to_locale': toLocale,
      'from_locale': fromLocale,
    },
    identifier: AiPrompts.fullTextTranslate,
  );
}

String _normalizePrompt(String template) {
  return template.replaceAll('{{', '{').replaceAll('}}', '}');
}
