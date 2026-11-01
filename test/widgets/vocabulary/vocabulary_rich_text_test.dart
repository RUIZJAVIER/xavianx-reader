import 'package:anx_reader/widgets/vocabulary/vocabulary_rich_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildVocabularySpans renders bold and font colors', () {
    final spans = buildVocabularySpans(
      '<b>miedo</b> <i>intrépido</i> <font color="#e53935">rojo</font>',
      const TextStyle(),
    );

    final bold = spans.firstWhere((span) => (span as TextSpan).text == 'miedo')
        as TextSpan;
    expect(bold.style?.fontWeight, FontWeight.bold);

    final italic =
        spans.firstWhere((span) => (span as TextSpan).text == 'intrépido')
            as TextSpan;
    expect(italic.style?.fontStyle, FontStyle.italic);

    final colored =
        spans.firstWhere((span) => (span as TextSpan).text == 'rojo')
            as TextSpan;
    expect(colored.style?.color, const Color(0xffe53935));
  });
}
