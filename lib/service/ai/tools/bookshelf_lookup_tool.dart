import 'dart:async';

import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/ai/tools/ai_tool_registry.dart';
import 'package:anx_reader/service/ai/tools/input/bookshelf_lookup_input.dart';
import 'package:anx_reader/service/ai/tools/repository/books_repository.dart';

import 'base_tool.dart';

class BookshelfLookupTool
    extends RepositoryTool<BookshelfLookupInput, Map<String, dynamic>> {
  BookshelfLookupTool(this._repository)
      : super(
          name: 'bookshelf_lookup',
          description:
              'Find books that already exist on the user\'s local shelf based on title, author, or group membership. Use this before referencing a book in replies so you can cite real items from the library. Supports optional filters for bookshelf groups and deleted books. Results are paginated: the response returns at most `limit` books, and you can call the tool again with a higher `offset` to fetch the next page. Returns a structured list of matching books with identifiers, metadata, progress, and last-read timestamps.',
          inputJsonSchema: const {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description':
                    'Optional. Text to match against book titles or authors (accent-insensitive). Omit when you want to list everything in a group.',
              },
              'group_id': {
                'type': 'integer',
                'description':
                    'Optional. Restrict the search to a specific bookshelf group ID.',
              },
              'include_deleted': {
                'type': 'boolean',
                'description':
                    'Optional. Set true when you also need books that are currently marked as deleted (defaults to false).',
              },
              'limit': {
                'type': 'integer',
                'description':
                    'Optional. Maximum number of books to return (range 1-100; defaults to 100).',
              },
              'offset': {
                'type': 'integer',
                'description':
                    'Optional. Number of matching books to skip before returning results (defaults to 0). Use it with `limit` to page through large libraries.',
              },
            },
          },
          timeout: const Duration(seconds: 3),
        );

  final BooksRepository _repository;

  @override
  BookshelfLookupInput parseInput(Map<String, dynamic> json) {
    return BookshelfLookupInput.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> run(BookshelfLookupInput input) async {
    final results = await _repository.searchBooks(
      keyword: input.query,
      groupId: input.groupId,
      includeDeleted: input.includeDeleted,
      limit: input.resolvedLimit(),
      offset: input.resolvedOffset(),
    );

    return {
      'query': input.query,
      'groupId': input.groupId,
      'includeDeleted': input.includeDeleted,
      'offset': input.resolvedOffset(),
      'results': results.map((entry) => entry.toMap()).toList(),
    };
  }

  @override
  bool shouldLogError(Object error) {
    return error is! TimeoutException;
  }
}

final AiToolDefinition bookshelfLookupToolDefinition = AiToolDefinition(
  id: 'bookshelf_lookup',
  displayNameBuilder: (L10n l10n) => l10n.aiToolBookshelfLookupName,
  descriptionBuilder: (L10n l10n) => l10n.aiToolBookshelfLookupDescription,
  build: (context) => BookshelfLookupTool(context.booksRepository).tool,
);
