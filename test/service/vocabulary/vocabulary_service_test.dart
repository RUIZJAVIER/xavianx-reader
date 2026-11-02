import 'package:anx_reader/models/book_note.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildVocabularyCsv uses the Anki column order and escapes commas', () {
    final csv = buildVocabularyCsv([
      Vocabulary(
        id: 1,
        word: 'química',
        contextSentence: 'La química, hoy',
        definition: 'science',
        associationMnemonic: 'Qui-mica',
        languageIsland: 'lab',
        timestamp: DateTime(2026, 1, 1),
      ),
    ]);

    expect(csv.split('\r\n').first,
        'Palabra,Definición,Contexto,Isla,Mnemotecnia');
    expect(csv, contains('química,science,"La química, hoy",lab,Qui-mica'));
  });

  test('buildVocabularyCsv keeps the rich text tags Anki understands', () {
    final csv = buildVocabularyCsv([
      Vocabulary(
        id: 2,
        word: 'intrépido',
        contextSentence: '',
        definition: '<b>sin miedo</b>',
        associationMnemonic: '<font color="#e53935">in-trepid</font>',
        languageIsland: 'aventura',
        timestamp: DateTime(2026, 1, 1),
      ),
    ]);

    expect(csv, contains('<b>sin miedo</b>'));
    expect(csv, contains('<font color=""#e53935"">in-trepid</font>'));
  });

  test('scheduleFsrs records the review and advances a new card', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final card = Vocabulary(
      id: 1,
      word: 'química',
      contextSentence: '',
      definition: 'science',
      associationMnemonic: null,
      languageIsland: 'lab',
      timestamp: now,
    );

    final good = scheduleFsrs(card, 3, now: now);
    expect(good.lastReviewDate, now.millisecondsSinceEpoch);
    expect(good.nextReviewDate, greaterThan(now.millisecondsSinceEpoch));

    final again = scheduleFsrs(card, 1, now: now);
    expect(again.state, 1);
    expect(again.step, 0);
    expect(again.nextReviewDate,
        now.add(const Duration(minutes: 1)).millisecondsSinceEpoch);

    final easy = scheduleFsrs(card, 4, now: now);
    expect(easy.state, 2);
    expect(easy.stability, isNotNull);
    expect(easy.difficulty, isNotNull);
    expect(easy.nextReviewDate,
        greaterThanOrEqualTo(now.add(const Duration(days: 1)).millisecondsSinceEpoch));
  });

  test('scheduleFsrs sends a forgotten review card to relearning', () {
    final now = DateTime.utc(2026, 1, 11, 12);
    final card = Vocabulary(
      id: 2,
      word: 'intrépido',
      contextSentence: '',
      definition: 'fearless',
      associationMnemonic: null,
      languageIsland: 'aventura',
      timestamp: now.subtract(const Duration(days: 10)),
      fsrsState: 2,
      stability: 10,
      difficulty: 5,
      lastReviewDate:
          now.subtract(const Duration(days: 10)).millisecondsSinceEpoch,
      nextReviewDate: now.millisecondsSinceEpoch,
    );

    final forgot = scheduleFsrs(card, 1, now: now);
    expect(forgot.state, 3);
    expect(forgot.step, 0);
    expect(forgot.nextReviewDate,
        now.add(const Duration(minutes: 10)).millisecondsSinceEpoch);
  });

  test('buildPkmMarkdown exports vocabulary and notes formatted for PKM apps', () {
    final md = buildPkmMarkdown(
      vocabulary: [
        Vocabulary(
          id: 1,
          word: 'epifanía',
          contextSentence: 'Tuvo una epifanía repentina.',
          definition: 'manifestación o revelación',
          associationMnemonic: 'Epi + fanía = revelación',
          languageIsland: 'filosofía',
          timestamp: DateTime(2026, 1, 1),
        ),
      ],
      notes: [
        BookNote(
          bookId: 10,
          content: 'El conocimiento comienza con el asombro.',
          cfi: 'epubcfi(/6/2!/4/1:0)',
          chapter: 'Capítulo 1',
          type: 'highlight',
          color: '000000',
          createTime: DateTime(2026, 1, 1),
          updateTime: DateTime(2026, 1, 1),
          readerNote: 'Releer este pasaje más adelante.',
        ),
      ],
    );

    expect(md, contains('# Mi Cerebro - Vocabulario y Apuntes'));
    expect(md, contains('### Isla: filosofía'));
    expect(md, contains('#### epifanía'));
    expect(md, contains('- **Definición**: manifestación o revelación'));
    expect(md, contains('- **Mnemotecnia**: Epi + fanía = revelación'));
    expect(md, contains('### Capítulo 1'));
    expect(md, contains('> El conocimiento comienza con el asombro.'));
    expect(md, contains('**Nota personal:** Releer este pasaje más adelante.'));
  });
}
