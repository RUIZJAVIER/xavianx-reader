import 'package:anx_reader/models/vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vocabulary keeps the book id through the db mapping', () {
    final card = Vocabulary(
      id: 7,
      word: 'harbor',
      contextSentence: 'The ship left the harbor at dawn.',
      definition: '',
      associationMnemonic: null,
      languageIsland: null,
      timestamp: DateTime(2026, 1, 1),
      bookId: 42,
    );

    final Map<String, dynamic> row = {'id': card.id, ...card.toMap()};
    expect(row['book_id'], 42);
    expect(Vocabulary.fromDb(row).bookId, 42);
  });

  test('Vocabulary leaves the book id empty for words saved outside a book',
      () {
    final card = Vocabulary(
      id: 8,
      word: 'harbor',
      contextSentence: '',
      definition: 'puerto',
      associationMnemonic: null,
      languageIsland: 'General',
      timestamp: DateTime(2026, 1, 1),
    );

    final Map<String, dynamic> row = {'id': card.id, ...card.toMap()};
    expect(row['book_id'], isNull);
    expect(Vocabulary.fromDb(row).bookId, isNull);
  });
}
