import 'package:anx_reader/service/ai/tools/tool_args.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coerces numeric ids sent as strings, nested and in lists', () {
    final result = sanitizeToolArgs({
      'books': [
        {'bookId': '7', 'bookTitle': '1984', 'tags': ['dystopia']},
      ],
      'updateTags': [
        {'id': ' 3 ', 'rgb': '0x33aa77'},
      ],
      'bookIds': ['4', 5],
      'limit': '10',
    });

    expect(result['books'][0]['bookId'], 7);
    expect(result['books'][0]['bookTitle'], '1984');
    expect(result['updateTags'][0]['id'], 3);
    expect(result['updateTags'][0]['rgb'], 0x33aa77);
    expect(result['bookIds'], [4, 5]);
    expect(result['limit'], 10);
  });

  test('rejects unparseable numeric ids with a format error', () {
    expect(
      () => sanitizeToolArgs({
        'books': [
          {'bookId': 'abc'},
        ],
      }),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, 'message', aiToolFormatErrorMessage),
      ),
    );
  });
}
