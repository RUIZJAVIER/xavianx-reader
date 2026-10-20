/// Utilidades lingüísticas locales (sin red) usadas por el servicio de
/// traducción:
///
/// * [detectLanguageCode]: detección aproximada del idioma de un fragmento.
/// * [englishPronunciationForSpanish]: pronunciación figurada en español para
///   texto en inglés (para que el lector sepa cómo decirlo en voz alta incluso
///   cuando el motor de IA no está disponible).
library;

/// Palabras muy frecuentes del español (sin ambigüedades con el inglés).
const Set<String> _spanishWords = {
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del', 'al',
  'en', 'y', 'que', 'qué', 'es', 'son', 'era', 'eran', 'ser', 'estar', 'está',
  'están', 'estoy', 'estás', 'por', 'para', 'con', 'sin', 'sobre', 'entre',
  'cuando', 'cómo', 'como', 'donde', 'dónde', 'porque', 'pero', 'más', 'menos',
  'muy', 'también', 'ya', 'sí', 'su', 'sus', 'mi', 'mis', 'tu', 'tus', 'le',
  'les', 'lo', 'se', 'nos', 'yo', 'tú', 'él', 'ella', 'ellos', 'ellas',
  'nosotros', 'usted', 'ustedes', 'vosotros', 'hay', 'había', 'han', 'he',
  'has', 'ha', 'fue', 'fueron', 'este', 'esta', 'esto', 'estos', 'estas',
  'ese', 'esa', 'eso', 'esos', 'esas', 'aquel', 'aquella', 'todo', 'toda',
  'todos', 'todas', 'otro', 'otra', 'otros', 'otras', 'mismo', 'misma', 'tan',
  'tanto', 'mucho', 'mucha', 'muchos', 'muchas', 'poco', 'poca', 'pocos',
  'pocas', 'quién', 'quiénes', 'cual', 'cuál', 'cuáles', 'mientras', 'aunque',
  'sino', 'solo', 'sólo', 'hasta', 'desde', 'hacia', 'durante', 'antes',
  'después', 'siempre', 'nunca', 'jamás', 'aquí', 'ahí', 'allí', 'ahora',
  'entonces', 'luego', 'así', 'bien', 'mal', 'mejor', 'peor', 'grande',
  'pequeño', 'nuevo', 'viejo', 'bueno', 'malo', 'hombre', 'mujer', 'vida',
  'mundo', 'tiempo', 'día', 'noche', 'año', 'años', 'vez', 'veces', 'libro',
  'lector', 'poder', 'amor', 'muerte', 'guerra', 'paz', 'verdad', 'mentira',
  'corazón', 'alma', 'mente', 'casa', 'agua', 'tierra', 'fuego', 'viento',
  'rey', 'reina', 'pueblo', 'gente', 'persona', 'personas', 'niño', 'niña',
  'señor', 'señora', 'dios', 'diablo', 'ley', 'leyes', 'fuerza', 'miedo',
  'deseo', 'placer', 'dolor', 'felicidad', 'libertad', 'justicia', 'honor',
  'orgullo', 'envidia', 'ira', 'pereza', 'avaricia', 'lujuria', 'gula',
  'soberbia', 'palabra', 'palabras', 'historia', 'mujeres', 'hombres',
  'trabajo', 'ciudad', 'país', 'ejército', 'enemigo',
  'amigo', 'amiga', 'familia', 'padre', 'madre', 'hijo', 'hija', 'hermano',
  'hermana', 'quizá', 'tal', 'cada', 'según',
  'contra', 'tras', 'mediante', 'aún', 'todavía', 'casi', 'sólo', 'además',
  'incluso', 'pues', 'acerca', 'través', 'dentro',
  'fuera', 'debajo', 'encima', 'detrás', 'delante', 'junto', 'lejos', 'cerca'};

/// Palabras muy frecuentes del inglés (sin ambigüedades con el español).
const Set<String> _englishWords = {
  'the', 'and', 'or', 'but', 'if', 'of', 'to', 'in', 'on', 'at', 'by', 'for',
  'with', 'from', 'into', 'over', 'under', 'about', 'as', 'than', 'then',
  'that', 'this', 'these', 'those', 'there', 'their', 'they', 'them', 'he',
  'she', 'it', 'we', 'you', 'me', 'my', 'your', 'his', 'her', 'its', 'our',
  'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had',
  'do', 'does', 'did', 'will', 'would', 'can', 'could', 'shall', 'should',
  'may', 'might', 'must', 'not', 'yes', 'so', 'very', 'just', 'only', 'also',
  'more', 'most', 'much', 'many', 'some', 'any', 'all', 'both', 'each',
  'every', 'other', 'another', 'such', 'what', 'which', 'who', 'whom',
  'whose', 'when', 'where', 'why', 'how', 'because', 'while', 'before',
  'after', 'since', 'until', 'though', 'although', 'however', 'therefore',
  'again', 'still', 'always', 'never', 'often', 'sometimes', 'here', 'now',
  'later', 'today', 'tomorrow', 'yesterday', 'one', 'two', 'three', 'people',
  'man', 'woman', 'life', 'world', 'time', 'day', 'night', 'year', 'years',
  'book', 'word', 'words', 'love', 'death', 'war', 'peace', 'truth', 'power',
  'mind', 'heart', 'soul', 'king', 'queen', 'god', 'devil', 'law', 'laws',
  'fear', 'desire', 'pain', 'pleasure', 'happiness', 'freedom', 'justice',
  'honor', 'pride', 'envy', 'anger', 'sloth', 'greed', 'lust', 'gluttony',
  'wrath', 'story', 'history', 'men', 'women', 'work', 'city', 'country',
  'army', 'enemy', 'friend', 'family', 'father', 'mother', 'son', 'daughter',
  'brother', 'sister', 'nothing', 'something', 'everything', 'anyone',
  'everyone', 'someone', 'perhaps', 'maybe', 'through',
  'against', 'between', 'during', 'without', 'within', 'upon'};

/// Detecta de forma aproximada el idioma de [text].
///
/// Devuelve `'es'`, `'en'` o `null` cuando no hay señales suficientes (en ese
/// caso conviene dejar que Google GTX lo detecte en la respuesta).
String? detectLanguageCode(String text) {
  final lower = text.toLowerCase().trim();
  if (lower.isEmpty) return null;

  // Caracteres inequívocamente españoles.
  final hasSpanishMarks = RegExp(r'[¿¡ñáéíóúü]').hasMatch(lower);

  final words = lower
      .replaceAll(RegExp(r"[^a-záéíóúüñç'’\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1)
      .toList();
  if (words.isEmpty) return null;

  var spanishHits = 0;
  var englishHits = 0;
  for (final word in words) {
    if (_spanishWords.contains(word)) spanishHits++;
    if (_englishWords.contains(word)) englishHits++;
  }

  if (hasSpanishMarks && spanishHits >= englishHits - 1) return 'es';
  if (spanishHits == 0 && englishHits == 0) return null;
  if (spanishHits > englishHits) return 'es';
  if (englishHits > spanishHits) return 'en';
  return hasSpanishMarks ? 'es' : null;
}

/// Pronunciación figurada en español para un texto en inglés.
///
/// Ejemplo: `useful` → `ius-ful`. Se separan las sílabas con guiones para que
/// sea fácil leerlo en voz alta.
String englishPronunciationForSpanish(String text, {int maxWords = 16}) {
  final words = text
      .split(RegExp(r"[^A-Za-z'’-]+"))
      .where((w) => w.replaceAll(RegExp(r"[^A-Za-z]"), '').isNotEmpty)
      .take(maxWords)
      .toList();
  if (words.isEmpty) return '';

  final parts = <String>[];
  for (final word in words) {
    final respelled = _respellWord(word);
    if (respelled.isNotEmpty) parts.add(respelled);
  }
  return parts.join(' · ');
}

/// Pronunciaciones frecuentes que las reglas generales no aciertan.
const Map<String, String> _knownPronunciations = {
  'the': 'ze', 'a': 'e', 'an': 'an', 'and': 'and', 'of': 'ov', 'to': 'tu',
  'in': 'in', 'is': 'is', 'it': 'it', 'that': 'zat', 'for': 'for',
  'was': 'uos', 'with': 'uid', 'as': 'as', 'his': 'jis', 'on': 'on',
  'be': 'bi', 'at': 'at', 'by': 'bai', 'had': 'jad', 'not': 'not',
  'are': 'ar', 'but': 'bat', 'from': 'from', 'or': 'or', 'have': 'jav',
  'they': 'zei', 'which': 'uich', 'one': 'uan', 'you': 'iu', 'were': 'uer',
  'her': 'jer', 'all': 'ol', 'she': 'shi', 'there': 'zer', 'would': 'uud',
  'their': 'zer', 'we': 'ui', 'him': 'jim', 'been': 'bin', 'has': 'jas',
  'when': 'uen', 'who': 'ju', 'will': 'uil', 'more': 'mor', 'no': 'nou',
  'if': 'if', 'out': 'aut', 'so': 'sou', 'said': 'sed', 'what': 'uat',
  'up': 'ap', 'its': 'its', 'about': 'abaut', 'into': 'intu',
  'than': 'zan', 'them': 'zem', 'can': 'can', 'only': 'ounli',
  'other': 'oder', 'new': 'niu', 'some': 'sam', 'could': 'cud',
  'time': 'taim', 'these': 'diz', 'two': 'tu', 'may': 'mei', 'then': 'zen',
  'do': 'du', 'first': 'ferst', 'any': 'eni', 'my': 'mai', 'now': 'nau',
  'such': 'sach', 'like': 'laik', 'our': 'aur', 'over': 'ouver',
  'man': 'man', 'me': 'mi', 'even': 'iven', 'most': 'moust',
  'made': 'meid', 'after': 'after', 'also': 'olso', 'did': 'did',
  'many': 'meni', 'before': 'bifor', 'must': 'mast', 'through': 'zru',
  'back': 'bak', 'years': 'yirs', 'where': 'uer', 'much': 'mach',
  'your': 'yor', 'way': 'uei', 'well': 'uel', 'down': 'daun',
  'should': 'shud', 'because': 'bicos', 'each': 'ich', 'just': 'yast',
  'those': 'zous', 'people': 'pipol', 'how': 'jau', 'too': 'tu',
  'little': 'litol', 'good': 'gud', 'very': 'veri', 'make': 'meik',
  'world': 'uerld', 'still': 'stil', 'own': 'oun', 'see': 'si',
  'work': 'uerk', 'long': 'long', 'get': 'get', 'here': 'jir',
  'between': 'bituin', 'both': 'boud', 'life': 'laif', 'being': 'biing',
  'under': 'ander', 'never': 'never', 'day': 'dei', 'same': 'seim',
  'another': 'anoder', 'know': 'nou', 'while': 'uail', 'last': 'last',
  'might': 'mait', 'us': 'as', 'great': 'greit', 'old': 'ould',
  'year': 'yir', 'off': 'of', 'come': 'cam', 'since': 'sins',
  'against': 'aguinst', 'go': 'gou', 'came': 'keim', 'right': 'rait',
  'used': 'iust', 'take': 'teik', 'three': 'zri', 'love': 'lav',
  'book': 'buk', 'read': 'rid', 'word': 'uerd', 'say': 'sei',
  'think': 'zink', 'look': 'luk', 'give': 'guiv', 'find': 'faind',
  'tell': 'tel', 'ask': 'ask', 'feel': 'fil', 'try': 'trai',
  'leave': 'liv', 'call': 'col', 'yes': 'yes', 'hello': 'jelou',
  'hi': 'jai', 'please': 'plis', 'thank': 'zank', 'thanks': 'zanks',
  'sorry': 'sori', 'water': 'uoter', 'house': 'jaus', 'school': 'skul',
  'friend': 'frend', 'night': 'nait', 'light': 'lait', 'today': 'tudei',
  'tomorrow': 'tumorou', 'yesterday': 'yesterdei', 'money': 'mani',
  'mother': 'mader', 'father': 'fader', 'brother': 'brader',
  'sister': 'sister', 'heart': 'jart', 'mind': 'maind', 'soul': 'soul',
  'death': 'dez', 'power': 'pauer', 'king': 'king', 'queen': 'kuin',
  'war': 'uor', 'peace': 'pis', 'truth': 'truz', 'beautiful': 'biutiful',
  'important': 'important', 'different': 'difrent', 'useful': 'iusful',
  'human': 'jiuman',
  'nature': 'neicher', 'future': 'fiucher', 'question': 'queschon',
  'language': 'languich', 'english': 'inglish', 'spanish': 'spanish',
  'words': 'uerds', 'letter': 'leter', 'number': 'namber',
  'happy': 'japi', 'sad': 'sad', 'angry': 'angri', 'afraid': 'afreid',
  'strong': 'strong', 'weak': 'uik', 'young': 'yong', 'wise': 'uais',
  'fool': 'ful', 'enemy': 'enemi', 'family': 'famili',
  'son': 'san', 'daughter': 'doter',
  'story': 'stori', 'history': 'jistori',
  'beauty': 'biuti', 'freedom': 'fridom', 'justice': 'yastis',
  'honor': 'onor', 'pride': 'praid', 'envy': 'envi', 'anger': 'anguer',
  'greed': 'grid', 'lust': 'last', 'wrath': 'raz', 'sloth': 'slouz',
  'gluttony': 'glatoni', 'desire': 'disair', 'pleasure': 'plesher',
  'pain': 'pein', 'happiness': 'japines', 'fear': 'fir', 'hope': 'joup',
  'faith': 'feiz', 'logic': 'loyik', 'reason': 'rison',
  'lie': 'lai', 'liar': 'lair', 'secret': 'sikret', 'silence': 'sailens',
  'voice': 'vois', 'sound': 'saund', 'color': 'color',
  'white': 'uait', 'black': 'blak', 'red': 'red', 'blue': 'blu',
  'green': 'grin', 'yellow': 'ielou', 'gold': 'gould', 'silver': 'silver',
};

/// Patrones de letras → sonido aproximado en español (se prueban de 4 a 2
/// letras, de más largo a más corto).
const Map<String, String> _patterns = {
  'ough': 'ou',
  'augh': 'o',
  'eigh': 'ei',
  'ight': 'ait',
  'tion': 'shon',
  'sion': 'shon',
  'ture': 'cher',
  'cian': 'shon',
  'cial': 'shal',
  'ious': 'ias',
  'eous': 'ias',
  'ph': 'f',
  'sh': 'sh',
  'ch': 'ch',
  'ck': 'k',
  'kn': 'n',
  'wr': 'r',
  'wh': 'u',
  'gn': 'n',
  'qu': 'ku',
  'th': 'z',
  'dg': 'y',
  'gh': '',
  'll': 'l',
  'ss': 's',
  'tt': 't',
  'pp': 'p',
  'ff': 'f',
  'mm': 'm',
  'nn': 'n',
  'rr': 'r',
  'bb': 'b',
  'dd': 'd',
  'gg': 'g',
  'zz': 's',
  'cc': 'k',
  'ee': 'i',
  'ea': 'i',
  'oo': 'u',
  'ou': 'au',
  'ow': 'ou',
  'oa': 'ou',
  'oi': 'oi',
  'oy': 'oi',
  'ai': 'ei',
  'ay': 'ei',
  'au': 'o',
  'aw': 'o',
  'ew': 'iu',
  'eu': 'iu',
  'ei': 'ei',
  'ie': 'i',
  'ar': 'ar',
  'er': 'er',
  'ir': 'er',
  'or': 'or',
  'ur': 'er',
};

String _respellWord(String raw) {
  var word = raw.toLowerCase().replaceAll('’', "'");
  word = word.replaceAll(RegExp(r"^[^a-z]+|[^a-z]+$"), '');
  if (word.isEmpty) return '';

  final apostrophe = word.indexOf("'");
  if (apostrophe > 0) word = word.substring(0, apostrophe);
  if (word.isEmpty) return '';

  final known = _knownPronunciations[word];
  if (known != null) return _syllabify(known);

  // Plurales y tercera persona regulares: se respeta el lexema.
  var stem = word;
  if (word.length > 4 && word.endsWith('ies')) {
    stem = '${word.substring(0, word.length - 3)}y';
  } else if (word.length > 4 &&
      word.endsWith('es') &&
      _endsWithSibilant(word.substring(0, word.length - 2))) {
    stem = word.substring(0, word.length - 2);
  } else if (word.length > 4 && word.endsWith('s') && !word.endsWith('ss')) {
    stem = word.substring(0, word.length - 1);
  }

  if (stem != word) {
    final base = _knownPronunciations[stem] ?? _respellStem(stem);
    return _syllabify('${base}s');
  }
  return _syllabify(_respellStem(word));
}

bool _endsWithSibilant(String value) {
  if (value.isEmpty) return false;
  return value.endsWith('s') ||
      value.endsWith('x') ||
      value.endsWith('z') ||
      value.endsWith('ch') ||
      value.endsWith('sh');
}

bool _hasSilentFinalE(String word) {
  if (word.length < 4 || !word.endsWith('e')) return false;
  if (word.endsWith('ee') || word.endsWith('ie') || word.endsWith('ue')) {
    return false;
  }
  if (word.endsWith('le') && !'aeiou'.contains(word[word.length - 3])) {
    return false;
  }
  return true;
}

/// Índice de la última vocal del lexema cuando después solo queda una
/// consonante (regla de la «e muda»: `make`, `time`, `note`).
int _magicVowelIndex(String stem) {
  const vowels = 'aeiouy';
  var last = -1;
  for (var i = 0; i < stem.length; i++) {
    if (vowels.contains(stem[i])) last = i;
  }
  if (last < 0) return -1;
  return stem.length - last - 1 == 1 ? last : -1;
}

String _respellStem(String word) {
  if (word.isEmpty) return '';

  var stem = word;
  var silentE = false;
  if (_hasSilentFinalE(stem)) {
    stem = stem.substring(0, stem.length - 1);
    silentE = true;
  }
  final magicIndex = silentE ? _magicVowelIndex(stem) : -1;

  final out = StringBuffer();
  var i = 0;
  while (i < stem.length) {
    final remaining = stem.substring(i);
    String? replacement;
    var consumed = 0;
    for (final length in const [4, 3, 2]) {
      if (remaining.length < length) continue;
      final value = _patterns[remaining.substring(0, length)];
      if (value != null) {
        replacement = value;
        consumed = length;
        break;
      }
    }
    if (replacement != null) {
      out.write(replacement);
      i += consumed;
      continue;
    }
    // Con la «e muda» eliminada, una «c»/«g» final sigue viéndose seguida de
    // vocal: `influence` → `influens` (no `influenk`).
    var next = i + 1 < stem.length ? stem[i + 1] : '';
    if (next.isEmpty && silentE) next = 'e';
    out.write(_singleLetter(stem[i], isMagic: i == magicIndex, next: next));
    i++;
  }
  return out.toString();
}

String _singleLetter(String letter, {bool isMagic = false, String next = ''}) {
  switch (letter) {
    case 'a':
      return isMagic ? 'ei' : 'a';
    case 'e':
      return isMagic ? 'i' : 'e';
    case 'i':
      return isMagic ? 'ai' : 'i';
    case 'o':
      return isMagic ? 'ou' : 'o';
    case 'u':
      return isMagic ? 'iu' : 'u';
    case 'c':
      return next.isNotEmpty && 'eiy'.contains(next) ? 's' : 'k';
    case 'g':
      return next.isNotEmpty && 'eiy'.contains(next) ? 'y' : 'g';
    case 'h':
      return 'j';
    case 'j':
      return 'y';
    case 'q':
      return 'k';
    case 'w':
      return 'u';
    case 'x':
      return 'ks';
    case 'z':
      return 's';
    case 'y':
      return next.isEmpty ? 'i' : 'y';
    default:
      return letter;
  }
}

/// Divide la pronunciación en sílabas legibles (`iu-ti-laiz`).
String _syllabify(String value) {
  if (value.length < 5) return value;
  const vowels = 'aeiouáéíóú';
  final syllables = <String>[];
  final current = StringBuffer();

  for (var i = 0; i < value.length; i++) {
    final letter = value[i];
    final next = i + 1 < value.length ? value[i + 1] : '';
    final currentText = current.toString();
    final hasVowel = currentText.split('').any(vowels.contains);
    final isConsonant = !vowels.contains(letter);
    // `ch` y `sh` son un solo sonido: no se separan (`ques-chon`).
    final isDigraphTail = letter == 'h' &&
        currentText.isNotEmpty &&
        (currentText.endsWith('c') || currentText.endsWith('s'));
    if (hasVowel &&
        isConsonant &&
        !isDigraphTail &&
        next.isNotEmpty &&
        vowels.contains(next)) {
      syllables.add(currentText);
      current.clear();
    }
    current.write(letter);
  }
  if (current.isNotEmpty) syllables.add(current.toString());

  return syllables.where((s) => s.isNotEmpty).join('-');
}
