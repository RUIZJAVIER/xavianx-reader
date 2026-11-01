import 'package:anx_reader/dao/base_dao.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/utils/text/search_normalize.dart';

class BookDao extends BaseDao {
  BookDao();

  static const String table = 'tb_books';

  Future<int> save(Book book) async {
    if (book.id != -1) {
      await updateBook(book);
      return book.id;
    }
    return insert(table, book.toMap());
  }

  Future<int> insertBook(Book book) => save(book);

  Future<void> updateBook(Book book) async {
    book.updateTime = DateTime.now();
    await update(
      table,
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<List<Book>> selectBooks({bool includeDeleted = true}) {
    return queryList(
      table,
      mapper: Book.fromDb,
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'update_time DESC',
    );
  }

  Future<List<Book>> selectNotDeleteBooks() {
    return selectBooks(includeDeleted: false);
  }

  Future<Book> selectBookById(int id) async {
    final book = await querySingle(
      table,
      mapper: Book.fromDb,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (book == null) {
      throw StateError('Book with id $id not found');
    }
    return book;
  }

  Future<List<String>> getCurrentBooks() async {
    final books = await selectNotDeleteBooks();
    return books.map((book) => book.filePath).toList(growable: false);
  }

  Future<List<String>> getCurrentCover() async {
    final books = await selectNotDeleteBooks();
    return books.map((book) => book.coverPath).toList(growable: false);
  }

  Future<List<Book>> selectAllBooks() {
    return selectBooks();
  }

  Future<Book?> getBookByMd5(String md5) {
    return querySingle(
      table,
      mapper: Book.fromDb,
      where: 'file_md5 = ?',
      whereArgs: [md5],
    );
  }

  Future<List<Book>> searchBooks(String keyword) async {
    if (keyword.trim().isEmpty) {
      return const [];
    }
    return searchBooksPage(keyword: keyword);
  }

  /// Title/author search with SQL-level filtering and pagination. The keyword
  /// comparison ignores accents, so "quimica" matches "Química".
  Future<List<Book>> searchBooksPage({
    String? keyword,
    int? groupId,
    bool includeDeleted = false,
    int? limit,
    int offset = 0,
  }) {
    final query = keyword?.trim() ?? '';
    final conditions = <String>[];
    final args = <Object?>[];

    if (!includeDeleted) {
      conditions.add('is_deleted = 0');
    }
    if (groupId != null) {
      conditions.add('group_id = ?');
      args.add(groupId);
    }
    if (query.isNotEmpty) {
      // shortcut: folding accents with REPLACE means a table scan; add a
      // normalized column if large libraries make search slow.
      final like = '%${normalizeForSearch(query)}%';
      conditions.add(
        '(${accentInsensitiveSql('title')} LIKE ? OR '
        '${accentInsensitiveSql('author')} LIKE ?)',
      );
      args..add(like)..add(like);
    }

    return queryList(
      table,
      mapper: Book.fromDb,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'update_time DESC',
      limit: limit,
      offset: limit == null ? null : offset,
    );
  }

  Future<List<Book>> selectBooksByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(ids.length, '?').join(',');
    return rawQueryList(
      'SELECT * FROM $table WHERE is_deleted = 0 AND id IN ($placeholders)',
      arguments: ids,
      mapper: Book.fromDb,
    );
  }

  Future<void> updateBookMd5(int bookId, String md5) {
    return update(
      table,
      {
        'file_md5': md5,
        'update_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<List<Book>> getBooksWithoutMd5() {
    return queryList(
      table,
      mapper: Book.fromDb,
      where: "is_deleted = 0 AND (file_md5 IS NULL OR file_md5 = '')",
      orderBy: 'update_time DESC',
    );
  }
}

final bookDao = BookDao();
