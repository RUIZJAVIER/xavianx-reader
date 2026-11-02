import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/models/book_note.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/ai/index.dart';
import 'package:anx_reader/utils/convert_string_to_uint8list.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/utils/save_file_to_download.dart';
import 'package:csv/csv.dart';
import 'package:fsrs/fsrs.dart';
import 'package:langchain_core/chat_models.dart';

const String fallbackLanguageIsland = generalLanguageIsland;

/// Asks the configured LLM for a short "language island" (the thematic
/// scenario where the word lives). Falls back to [fallbackLanguageIsland] when
/// there is no provider or the answer is blank; rethrows provider failures.
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
    rethrow;
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

/// Generates a concise association/mnemonic story with the LLM to remember [word].
Future<String> generateAssociationMnemonic({
  required String word,
  required String definition,
  String? contextSentence,
  String? languageIsland,
}) async {
  final prompt = '''Crea una mnemotecnia vívida, breve y memorable para recordar la palabra "$word".
Definición: ${definition.trim().isNotEmpty ? definition.trim() : '(no especificada)'}
Contexto: ${contextSentence?.trim().isNotEmpty == true ? contextSentence!.trim() : '(ninguno)'}
Isla temática: ${languageIsland?.trim().isNotEmpty == true ? languageIsland!.trim() : '(general)'}

Instrucciones:
- 1 o 2 frases máximo.
- Usa juego de palabras fonético o una imagen mental absurda/emocional que conecte la palabra con su significado.
- Responde únicamente con el texto de la mnemotecnia, sin introducciones ni comillas.''';

  var answer = '';
  await for (final chunk in aiGenerateStream([ChatMessage.humanText(prompt)])) {
    answer = chunk;
  }
  return answer.trim();
}

Future<int> saveVocabulary({
  required String word,
  required String definition,
  String? contextSentence,
  String? languageIsland,
  String? associationMnemonic,
}) async {
  final trimmedIsland = languageIsland?.trim() ?? '';
  final mnemonic = associationMnemonic?.trim();
  // A blank island waits for the LLM so the caller can show its progress.
  final island = trimmedIsland.isEmpty
      ? await inferLanguageIsland(
          word: word,
          definition: definition,
          contextSentence: contextSentence,
        ).timeout(const Duration(seconds: 15))
      : trimmedIsland;

  return vocabularyDao.save(
    Vocabulary(
      id: -1,
      word: word.trim(),
      contextSentence: contextSentence?.trim() ?? '',
      definition: definition.trim(),
      associationMnemonic:
          mnemonic == null || mnemonic.isEmpty ? null : mnemonic,
      languageIsland: island,
      timestamp: DateTime.now(),
      nextReviewDate: DateTime.now().millisecondsSinceEpoch,
    ),
  );
}

typedef FsrsUpdate = ({
  int state,
  int? step,
  double? stability,
  double? difficulty,
  int interval,
  int nextReviewDate,
  int lastReviewDate,
});

/// One FSRS answer (1 again, 2 hard, 3 good, 4 easy) and its next state.
/// Fuzzing is disabled so the interval shown on the buttons is the one saved.
final Scheduler _scheduler = Scheduler(enableFuzzing: false);

FsrsUpdate scheduleFsrs(Vocabulary card, int rating, {DateTime? now}) {
  final reviewedAt = (now ?? DateTime.now()).toUtc();
  final due = card.nextReviewDate > 0
      ? DateTime.fromMillisecondsSinceEpoch(card.nextReviewDate, isUtc: true)
      : reviewedAt;
  final lastReview = card.lastReviewDate == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(card.lastReviewDate!, isUtc: true);
  final result = _scheduler.reviewCard(
    Card(
      cardId: card.id,
      state: State.fromValue(card.fsrsState),
      step: card.fsrsStep,
      stability: card.stability,
      difficulty: card.difficulty,
      due: due,
      lastReview: lastReview,
    ),
    Rating.fromValue(rating),
    reviewDateTime: reviewedAt,
  );

  final next = result.card;
  final interval = next.due.difference(reviewedAt);
  return (
    state: next.state.value,
    step: next.step,
    stability: next.stability,
    difficulty: next.difficulty,
    interval: interval.inDays,
    nextReviewDate: next.due.millisecondsSinceEpoch,
    lastReviewDate: reviewedAt.millisecondsSinceEpoch,
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

/// Generates a unified Markdown export formatted for PKM apps (Obsidian, Notion).
String buildPkmMarkdown({
  required List<Vocabulary> vocabulary,
  required List<BookNote> notes,
}) {
  final buffer = StringBuffer()
    ..writeln('# Mi Cerebro - Vocabulario y Apuntes')
    ..writeln()
    ..writeln('> Exportado el ${DateTime.now().toLocal().toString().split('.').first}')
    ..writeln()
    ..writeln('## 📚 Vocabulario Aprendido')
    ..writeln();

  if (vocabulary.isEmpty) {
    buffer.writeln('_Sin palabras registradas._\n');
  } else {
    final grouped = <String, List<Vocabulary>>{};
    for (final item in vocabulary) {
      final island = (item.languageIsland?.trim().isNotEmpty ?? false)
          ? item.languageIsland!.trim()
          : generalLanguageIsland;
      grouped.putIfAbsent(island, () => []).add(item);
    }

    for (final entry in grouped.entries) {
      buffer.writeln('### Isla: ${entry.key}\n');
      for (final v in entry.value) {
        buffer.writeln('#### ${v.word}');
        if (v.definition.isNotEmpty) {
          buffer.writeln('- **Definición**: ${v.definition}');
        }
        if (v.contextSentence.isNotEmpty) {
          buffer.writeln('- **Contexto**: "${v.contextSentence}"');
        }
        if (v.associationMnemonic?.isNotEmpty ?? false) {
          buffer.writeln('- **Mnemotecnia**: ${v.associationMnemonic}');
        }
        final stateLabel = v.lastReviewDate == null ? 'Nueva' : 'En repaso';
        buffer.writeln('- **Estado SRS**: $stateLabel');
        buffer.writeln();
      }
    }
  }

  buffer.writeln('## 📝 Notas y Apuntes del Lector\n');
  if (notes.isEmpty) {
    buffer.writeln('_Sin notas registradas._\n');
  } else {
    for (final note in notes) {
      if (note.chapter != null && note.chapter!.isNotEmpty) {
        buffer.writeln('### ${note.chapter}');
      }
      if (note.content.isNotEmpty) {
        buffer.writeln('> ${note.content.replaceAll('\n', '\n> ')}');
        buffer.writeln();
      }
      if (note.readerNote != null && note.readerNote!.isNotEmpty) {
        buffer.writeln('**Nota personal:** ${note.readerNote}\n');
      }
      buffer.writeln('*Tipo: ${note.type} | Fecha: ${note.createTime.toLocal().toString().split(' ').first}*\n');
    }
  }

  return buffer.toString();
}

Future<String?> exportPkmMarkdown({
  required List<Vocabulary> vocabulary,
  required List<BookNote> notes,
}) {
  return saveFileToDownload(
    bytes: convertStringToUint8List('\uFEFF${buildPkmMarkdown(vocabulary: vocabulary, notes: notes)}'),
    fileName: 'mi_cerebro_${DateTime.now().millisecondsSinceEpoch}.md',
    mimeType: 'text/markdown',
  );
}
