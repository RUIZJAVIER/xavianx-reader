class ManageVocabularyInput {
  final String action;
  final int? id;
  final String? word;
  final String? definition;
  final String? contextSentence;
  final String? island;
  final int limit;
  final String? associationMnemonic;
  final String? languageIsland;
  final String? tags;

  const ManageVocabularyInput({
    this.action = 'list',
    this.id,
    this.word,
    this.definition,
    this.contextSentence,
    this.island,
    this.limit = 20,
    this.associationMnemonic,
    this.languageIsland,
    this.tags,
  });

  factory ManageVocabularyInput.fromJson(Map<String, dynamic> json) =>
      ManageVocabularyInput(
        action: json['action'] as String? ?? 'list',
        id: (json['id'] as num?)?.toInt(),
        word: json['word'] as String?,
        definition: json['definition'] as String?,
        contextSentence: json['contextSentence'] as String?,
        island: json['island'] as String?,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        associationMnemonic: json['associationMnemonic'] as String?,
        languageIsland: json['languageIsland'] as String?,
        tags: json['tags'] as String?,
      );

  bool get isCreate => action.toLowerCase() == 'create';
  bool get isUpdate => action.toLowerCase() == 'update';

  int resolvedLimit() => limit.clamp(1, 100);
}
