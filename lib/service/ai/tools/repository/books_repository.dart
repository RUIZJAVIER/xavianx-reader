import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/models/book.dart';

class BookSearchResult {
  BookSearchResult(this.book);

  final Book book;

  Map<String, dynamic> toMap() {
    return {
      'bookId': book.id,
      'title': book.title,
      'author': book.author,
      'description': book.description,
      'readingPercentage': book.readingPercentage,
      'lastReadPosition': book.lastReadPosition,
      'groupId': book.groupId,
      'updatedAt': book.updateTime.toIso8601String(),
      'isDeleted': book.isDeleted,
    };
  }
}

class BooksRepository {
  const BooksRepository();

  Future<Map<int, Book>> fetchByIds(Iterable<int> ids) async {
    final uniqueIds = ids.where((id) => id > 0).toSet().toList();
    if (uniqueIds.isEmpty) {
      return const <int, Book>{};
    }

    final books = await bookDao.selectBooksByIds(uniqueIds);
    return {for (final book in books) book.id: book};
  }

  Future<List<BookSearchResult>> searchBooks({
    String? keyword,
    int? groupId,
    bool includeDeleted = false,
    int limit = 10,
    int offset = 0,
  }) async {
    final query = keyword?.trim() ?? '';
    final books = await bookDao.searchBooksPage(
      keyword: query,
      groupId: groupId,
      includeDeleted: includeDeleted,
      limit: limit,
      offset: offset,
    );
    return books.map(BookSearchResult.new).toList();
  }
}
