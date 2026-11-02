import 'package:anx_reader/dao/base_dao.dart';
import 'package:anx_reader/models/vocabulary.dart';

class VocabularyDao extends BaseDao {
  static const String table = 'vocabulary';

  // Cards without an island (or with a blank one) live in the General deck.
  static const String _islandExpr =
      "COALESCE(NULLIF(TRIM(language_island), ''), '$generalLanguageIsland')";

  Future<int> save(Vocabulary vocabulary) {
    return insert(table, vocabulary.toMap());
  }

  Future<List<Vocabulary>> fetchAll({String? island, int? limit}) {
    final trimmedIsland = island?.trim();
    final scoped = trimmedIsland != null && trimmedIsland.isNotEmpty;
    return queryList(
      table,
      mapper: Vocabulary.fromDb,
      where: scoped ? '$_islandExpr = ?' : null,
      whereArgs: scoped ? [trimmedIsland] : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// One row per deck, with its card and due counts.
  Future<List<VocabularyDeck>> fetchDecks({DateTime? now}) {
    return rawQueryList(
      'SELECT $_islandExpr AS island, COUNT(*) AS total, '
      'SUM(CASE WHEN next_review_date <= ? THEN 1 ELSE 0 END) AS due '
      'FROM $table GROUP BY island ORDER BY island COLLATE NOCASE',
      arguments: [(now ?? DateTime.now()).millisecondsSinceEpoch],
      mapper: VocabularyDeck.fromDb,
    );
  }

  Future<Vocabulary?> fetchById(int id) {
    return querySingle(
      table,
      mapper: Vocabulary.fromDb,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Vocabulary>> fetchDue({DateTime? now, String? island}) {
    final trimmedIsland = island?.trim();
    final scoped = trimmedIsland != null && trimmedIsland.isNotEmpty;
    return queryList(
      table,
      mapper: Vocabulary.fromDb,
      where: scoped
          ? 'next_review_date <= ? AND $_islandExpr = ?'
          : 'next_review_date <= ?',
      whereArgs: [
        (now ?? DateTime.now()).millisecondsSinceEpoch,
        if (scoped) trimmedIsland,
      ],
      orderBy: 'next_review_date ASC',
    );
  }

  Future<int> countDue({DateTime? now, String? island}) async {
    final trimmedIsland = island?.trim();
    final scoped = trimmedIsland != null && trimmedIsland.isNotEmpty;
    final count = await rawQuerySingle(
      'SELECT COUNT(*) AS total FROM $table WHERE next_review_date <= ?'
      '${scoped ? ' AND $_islandExpr = ?' : ''}',
      arguments: [
        (now ?? DateTime.now()).millisecondsSinceEpoch,
        if (scoped) trimmedIsland,
      ],
      mapper: (row) => row['total'] as int,
    );
    return count ?? 0;
  }

  Future<bool> updateCard(Vocabulary card) async {
    final updated = await update(
      table,
      {
        'word': card.word,
        'context_sentence': card.contextSentence,
        'definition': card.definition,
        'association_mnemonic': card.associationMnemonic,
        'language_island': card.languageIsland,
      },
      where: 'id = ?',
      whereArgs: [card.id],
    );
    return updated > 0;
  }

  Future<bool> updateSrs(
    int id, {
    required double efactor,
    required int repetition,
    required int interval,
    required int nextReviewDate,
  }) async {
    final updated = await update(
      table,
      {
        'efactor': efactor,
        'repetition': repetition,
        'interval': interval,
        'next_review_date': nextReviewDate,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return updated > 0;
  }

  Future<bool> updateFields(
    int id, {
    String? associationMnemonic,
    String? languageIsland,
  }) async {
    final values = <String, Object?>{
      if (associationMnemonic != null)
        'association_mnemonic': associationMnemonic,
      if (languageIsland != null) 'language_island': languageIsland,
    };
    if (values.isEmpty) return false;
    final updated = await update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    return updated > 0;
  }
}

final vocabularyDao = VocabularyDao();
