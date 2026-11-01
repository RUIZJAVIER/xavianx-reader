import 'package:anx_reader/dao/base_dao.dart';
import 'package:anx_reader/models/vocabulary.dart';

class VocabularyDao extends BaseDao {
  static const String table = 'vocabulary';

  Future<int> save(Vocabulary vocabulary) {
    return insert(table, vocabulary.toMap());
  }

  Future<List<Vocabulary>> fetchAll({String? island, int? limit}) {
    final trimmedIsland = island?.trim();
    return queryList(
      table,
      mapper: Vocabulary.fromDb,
      where: trimmedIsland == null || trimmedIsland.isEmpty
          ? null
          : 'language_island = ?',
      whereArgs: trimmedIsland == null || trimmedIsland.isEmpty
          ? null
          : [trimmedIsland],
      orderBy: 'timestamp DESC',
      limit: limit,
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

  Future<List<Vocabulary>> fetchDue({DateTime? now}) {
    return queryList(
      table,
      mapper: Vocabulary.fromDb,
      where: 'next_review_date <= ?',
      whereArgs: [(now ?? DateTime.now()).millisecondsSinceEpoch],
      orderBy: 'next_review_date ASC',
    );
  }

  Future<int> countDue({DateTime? now}) async {
    final count = await rawQuerySingle(
      'SELECT COUNT(*) AS total FROM $table WHERE next_review_date <= ?',
      arguments: [(now ?? DateTime.now()).millisecondsSinceEpoch],
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
