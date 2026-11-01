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
