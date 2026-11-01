class Vocabulary {
  const Vocabulary({
    required this.id,
    required this.word,
    required this.contextSentence,
    required this.definition,
    required this.associationMnemonic,
    required this.languageIsland,
    required this.timestamp,
    this.efactor = 2.5,
    this.repetition = 0,
    this.interval = 0,
    this.nextReviewDate = 0,
  });

  final int id;
  final String word;
  final String contextSentence;
  final String definition;
  final String? associationMnemonic;
  final String? languageIsland;
  final DateTime timestamp;

  /// SM-2 scheduling state. [nextReviewDate] is milliseconds since epoch;
  /// 0 means the card is due immediately.
  final double efactor;
  final int repetition;
  final int interval;
  final int nextReviewDate;

  Map<String, Object?> toMap() {
    return {
      'word': word,
      'context_sentence': contextSentence,
      'definition': definition,
      'association_mnemonic': associationMnemonic,
      'language_island': languageIsland,
      'timestamp': timestamp.toIso8601String(),
      'efactor': efactor,
      'repetition': repetition,
      'interval': interval,
      'next_review_date': nextReviewDate,
    };
  }

  Vocabulary copyWith({
    String? word,
    String? contextSentence,
    String? definition,
    String? associationMnemonic,
    String? languageIsland,
    double? efactor,
    int? repetition,
    int? interval,
    int? nextReviewDate,
  }) {
    return Vocabulary(
      id: id,
      word: word ?? this.word,
      contextSentence: contextSentence ?? this.contextSentence,
      definition: definition ?? this.definition,
      associationMnemonic: associationMnemonic ?? this.associationMnemonic,
      languageIsland: languageIsland ?? this.languageIsland,
      timestamp: timestamp,
      efactor: efactor ?? this.efactor,
      repetition: repetition ?? this.repetition,
      interval: interval ?? this.interval,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
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
      efactor: (map['efactor'] as num?)?.toDouble() ?? 2.5,
      repetition: map['repetition'] as int? ?? 0,
      interval: map['interval'] as int? ?? 0,
      nextReviewDate: map['next_review_date'] as int? ?? 0,
    );
  }
}
