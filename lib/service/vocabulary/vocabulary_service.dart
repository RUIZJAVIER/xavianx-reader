import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/ai/index.dart';
import 'package:anx_reader/utils/convert_string_to_uint8list.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/utils/save_file_to_download.dart';
import 'package:csv/csv.dart';
import 'package:langchain_core/chat_models.dart';

const String fallbackLanguageIsland = 'General';

/// Asks the configured LLM for a short "language island" (the thematic
/// scenario where the word lives). Falls back to [fallbackLanguageIsland].
Future<String> inferLanguageIsland({
  required String word,
  required String definition,
  String? contextSentence,
}) async {
  final prompt = '''The user is learning the word "$word".
Definition: $definition
Context: ${contextSentence?.trim().isNotEmpty == true ? contextSentence! : '(none)'}

Name the "language island": a short thematic scenario where this word would be used (e.g. "airport check-in", "kitchen basics", "office meetings"). Reply with the island name only, 2-5 words, no quotes, no explanation, in the user's language.''';

  if (Prefs().getAiProviders().isEmpty &&
      Prefs().getAiConfig(Prefs().selectedAiService).isEmpty) {
    return fallbackLanguageIsland;
  }

  try {
    var answer = '';
    await for (final chunk
        in aiGenerateStream([ChatMessage.humanText(prompt)])) {
      answer = chunk;
    }
    final island = _cleanIsland(answer);
    if (island.isEmpty || island.toLowerCase().startsWith('error:')) {
      return fallbackLanguageIsland;
    }
    return island;
  } catch (e) {
    AnxLog.warning('Vocabulary: island inference failed: $e');
    return fallbackLanguageIsland;
  }
}

String _cleanIsland(String raw) {
  final firstLine = raw
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  return firstLine
      .replaceAll(RegExp(r'^[-\s*#`"]+|[-\s*`"]+$'), '')
      .trim();
}

Future<int> saveVocabulary({
  required String word,
  required String definition,
  String? contextSentence,
  String? languageIsland,
}) async {
  final trimmedIsland = languageIsland?.trim() ?? '';
  final island = trimmedIsland.isNotEmpty
      ? trimmedIsland
      : await inferLanguageIsland(
          word: word,
          definition: definition,
          contextSentence: contextSentence,
        );

  return vocabularyDao.save(
    Vocabulary(
      id: -1,
      word: word.trim(),
      contextSentence: contextSentence?.trim() ?? '',
      definition: definition.trim(),
      associationMnemonic: null,
      languageIsland: island,
      timestamp: DateTime.now(),
    ),
  );
}

/// CSV columns requested for Anki: Palabra, Definición, Contexto, Isla,
/// Mnemotecnia.
String buildVocabularyCsv(List<Vocabulary> items) {
  final rows = <List<dynamic>>[
    ['Palabra', 'Definición', 'Contexto', 'Isla', 'Mnemotecnia'],
    for (final item in items)
      [
        item.word,
        item.definition,
        item.contextSentence,
        item.languageIsland ?? '',
        item.associationMnemonic ?? '',
      ],
  ];
  return const ListToCsvConverter().convert(rows);
}

Future<String?> exportVocabularyCsv(List<Vocabulary> items) {
  return saveFileToDownload(
    // UTF-8 BOM so spreadsheet apps keep the accents.
    bytes: convertStringToUint8List('\uFEFF${buildVocabularyCsv(items)}'),
    fileName: 'vocabulary.csv',
    mimeType: 'text/csv',
  );
}
