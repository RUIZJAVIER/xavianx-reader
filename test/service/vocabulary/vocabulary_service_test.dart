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

  test('applySm2 grows the interval and resets it after forgetting', () {
    final now = DateTime(2026, 1, 1, 12);

    final first = applySm2(
      quality: 4,
      efactor: 2.5,
      repetition: 0,
      interval: 0,
      now: now,
    );
    expect(first.repetition, 1);
    expect(first.interval, 1);
    expect(first.nextReviewDate,
        now.add(const Duration(days: 1)).millisecondsSinceEpoch);

    final second = applySm2(
      quality: 4,
      efactor: first.efactor,
      repetition: first.repetition,
      interval: first.interval,
      now: now,
    );
    expect(second.repetition, 2);
    expect(second.interval, 6);

    final third = applySm2(
      quality: 5,
      efactor: second.efactor,
      repetition: second.repetition,
      interval: second.interval,
      now: now,
    );
    expect(third.repetition, 3);
    expect(third.interval, (6 * second.efactor).round());
    expect(third.efactor, closeTo(2.6, 0.0001));

    final forgot = applySm2(
      quality: 0,
      efactor: third.efactor,
      repetition: third.repetition,
      interval: third.interval,
      now: now,
    );
    expect(forgot.repetition, 0);
    expect(forgot.interval, 1);
    expect(forgot.efactor, greaterThanOrEqualTo(1.3));
  });
}
