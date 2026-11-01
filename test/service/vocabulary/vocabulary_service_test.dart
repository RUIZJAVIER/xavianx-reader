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
}
