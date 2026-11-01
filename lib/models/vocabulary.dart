class Vocabulary {
  const Vocabulary({
    required this.id,
    required this.word,
    required this.contextSentence,
    required this.definition,
    required this.associationMnemonic,
    required this.languageIsland,
    required this.timestamp,
  });

  final int id;
  final String word;
  final String contextSentence;
  final String definition;
  final String? associationMnemonic;
  final String? languageIsland;
  final DateTime timestamp;

  Map<String, Object?> toMap() {
    return {
      'word': word,
      'context_sentence': contextSentence,
      'definition': definition,
      'association_mnemonic': associationMnemonic,
      'language_island': languageIsland,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Vocabulary.fromDb(Map<String, dynamic> map) {
    return Vocabulary(
      id: map['id'] as int,
      word: map['word'] as String? ?? '',
      contextSentence: map['context_sentence'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      associationMnemonic: map['association_mnemonic'] as String?,
      languageIsland: map['language_island'] as String?,
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
