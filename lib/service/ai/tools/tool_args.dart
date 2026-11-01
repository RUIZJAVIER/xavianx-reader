import 'package:anx_reader/utils/color/rgb.dart';

const aiToolFormatErrorMessage =
    'Error de formato. Asegúrate de enviar los IDs como números enteros, no como strings';

/// Schema keys declared as integers, plus rgb (hex string) whose models store ints.
const _intArgKeys = {
  'id',
  'bookId',
  'bookIds',
  'groupId',
  'limit',
  'offset',
  'maxResults',
  'maxSnippets',
  'maxCharacters',
  'ungroupedBookIds',
  'cleanupGroupIds',
};

/// Models often send numeric args as strings ("12"), which makes freezed's
/// generated `as num` casts throw. Coerce them before parsing.
Map<String, dynamic> sanitizeToolArgs(Map<String, dynamic> json) =>
    _sanitizeValue(json, null) as Map<String, dynamic>;

dynamic _sanitizeValue(dynamic value, String? key) {
  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(k.toString(), _sanitizeValue(v, k.toString())),
    );
  }
  if (value is List) {
    return [for (final item in value) _sanitizeValue(item, key)];
  }
  if (key == 'rgb') return parseRgb(value);
  if (key == null || !_intArgKeys.contains(key)) return value;
  if (value == null || value is num) return value;
  final parsed = num.tryParse(value.toString().trim());
  if (parsed == null) throw const FormatException(aiToolFormatErrorMessage);
  return parsed.toInt();
}
