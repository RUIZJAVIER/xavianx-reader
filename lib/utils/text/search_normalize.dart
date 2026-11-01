/// Accent folding shared by the SQLite search and the Dart-side query so
/// "quimica" finds "Química".
const Map<String, String> _diacritics = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
  // SQLite's LOWER() only folds ASCII, so uppercase accents reach REPLACE too.
  'Á': 'a', 'À': 'a', 'Ä': 'a', 'Â': 'a', 'Ã': 'a',
  'É': 'e', 'È': 'e', 'Ë': 'e', 'Ê': 'e',
  'Í': 'i', 'Ì': 'i', 'Ï': 'i', 'Î': 'i',
  'Ó': 'o', 'Ò': 'o', 'Ö': 'o', 'Ô': 'o', 'Õ': 'o',
  'Ú': 'u', 'Ù': 'u', 'Ü': 'u', 'Û': 'u',
  'Ñ': 'n', 'Ç': 'c',
};

String normalizeForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString();
}

/// SQL expression that lowercases and folds [column] the same way as
/// [normalizeForSearch], for use in a LIKE comparison.
String accentInsensitiveSql(String column) {
  var expression = 'LOWER($column)';
  for (final entry in _diacritics.entries) {
    expression = "REPLACE($expression, '${entry.key}', '${entry.value}')";
  }
  return expression;
}
