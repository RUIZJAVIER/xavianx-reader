import 'package:anx_reader/utils/text/search_normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeForSearch folds accents and case', () {
    expect(normalizeForSearch('Química'), 'quimica');
    expect(normalizeForSearch('ÁRBOL'), 'arbol');
    expect(normalizeForSearch('niño'), 'nino');
  });

  test('accentInsensitiveSql folds the same characters in SQL', () {
    final sql = accentInsensitiveSql('title');
    expect(sql, startsWith('REPLACE(LOWER(title)'));
    expect(sql, contains("'í', 'i'"));
    expect(sql, contains("'Ñ', 'n'"));
  });
}
