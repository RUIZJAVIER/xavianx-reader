/// Deck used for cards whose island is missing or blank.
const String generalLanguageIsland = 'General';

class VocabularyDeck {
  const VocabularyDeck({
    required this.island,
    required this.newCards,
    required this.due,
  });

  final String island;
  final int newCards;
  final int due;

  factory VocabularyDeck.fromDb(Map<String, dynamic> row) {
    return VocabularyDeck(
      island: row['island'] as String? ?? generalLanguageIsland,
      newCards: (row['new_cards'] as num?)?.toInt() ?? 0,
      due: (row['due'] as num?)?.toInt() ?? 0,
    );
  }
}

class Vocabulary {
  const Vocabulary({
    required this.id,
    required this.word,
    required this.contextSentence,
    required this.definition,
    required this.associationMnemonic,
    required this.languageIsland,
    required this.timestamp,
    this.tags,
    this.fsrsState = 1,
    this.fsrsStep,
    this.stability,
    this.difficulty,
    this.lastReviewDate,
    this.nextReviewDate = 0,
  });

  final int id;
  final String word;
  final String contextSentence;
  final String definition;
  final String? associationMnemonic;
  final String? languageIsland;
  final String? tags;
  final DateTime timestamp;

  /// FSRS scheduling state. [nextReviewDate] and [lastReviewDate] are
  /// milliseconds since epoch; a null [lastReviewDate] means a new card.
  final int fsrsState;
  final int? fsrsStep;
  final double? stability;
  final double? difficulty;
  final int? lastReviewDate;
  final int nextReviewDate;

  Map<String, Object?> toMap() {
    return {
      'word': word,
      'context_sentence': contextSentence,
      'definition': definition,
      'association_mnemonic': associationMnemonic,
      'language_island': languageIsland,
      'tags': tags,
      'timestamp': timestamp.toIso8601String(),
      'fsrs_state': fsrsState,
      'fsrs_step': fsrsStep,
      'stability': stability,
      'difficulty': difficulty,
      'last_review_date': lastReviewDate,
      'next_review_date': nextReviewDate,
    };
  }

  Vocabulary copyWith({
    String? word,
    String? contextSentence,
    String? definition,
    String? associationMnemonic,
    String? languageIsland,
    String? tags,
  }) {
    return Vocabulary(
      id: id,
      word: word ?? this.word,
      contextSentence: contextSentence ?? this.contextSentence,
      definition: definition ?? this.definition,
      associationMnemonic: associationMnemonic ?? this.associationMnemonic,
      languageIsland: languageIsland ?? this.languageIsland,
      tags: tags ?? this.tags,
      timestamp: timestamp,
      fsrsState: fsrsState,
      fsrsStep: fsrsStep,
      stability: stability,
      difficulty: difficulty,
      lastReviewDate: lastReviewDate,
      nextReviewDate: nextReviewDate,
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
      tags: map['tags'] as String?,
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      fsrsState: map['fsrs_state'] as int? ?? 1,
      fsrsStep: map['fsrs_step'] as int?,
      stability: (map['stability'] as num?)?.toDouble(),
      difficulty: (map['difficulty'] as num?)?.toDouble(),
      lastReviewDate: map['last_review_date'] as int?,
      nextReviewDate: map['next_review_date'] as int? ?? 0,
    );
  }
}
