import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/tag.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/service/ai/index.dart';
import 'package:anx_reader/service/ai/tools/repository/tag_repository.dart';
import 'package:anx_reader/utils/color/hash_color.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:langchain_core/chat_models.dart';

/// The AI runner keeps a single active subscription, so background tagging is
/// queued instead of running in parallel (e.g. when importing many books).
Future<void> _queue = Future<void>.value();

/// Asks the LLM for two thematic tags and stores them for [book]. Runs in the
/// background and never throws.
Future<void> autoTagBook(Book book) {
  return _queue = _queue.then((_) => _autoTag(book)).catchError((Object e) {
    AnxLog.warning('AutoTag: queue task failed: $e');
  });
}

Future<void> _autoTag(Book book) async {
  if (book.id <= 0) return;
  if (Prefs().getAiProviders().isEmpty &&
      Prefs().getAiConfig(Prefs().selectedAiService).isEmpty) {
    return;
  }
  final description = (book.description ?? '').trim();
  final prompt = '''Pick exactly 2 short thematic tags for this book.
Title: ${book.title}
Author: ${book.author}
Description: ${description.isEmpty ? '(none)' : description}

Reply with the 2 tags separated by commas, in the book's language. No numbering, no quotes, no explanation.''';

  var answer = '';
  await for (final chunk in aiGenerateStream([ChatMessage.humanText(prompt)])) {
    answer = chunk;
  }
  if (answer.trim().toLowerCase().startsWith('error:')) {
    AnxLog.warning('AutoTag: skipped for "${book.title}": $answer');
    return;
  }

  final tags = answer
      .split(RegExp(r'[,;\n]'))
      .map((tag) => tag.replaceAll(RegExp(r'[\[\]"*#`]'), '').trim())
      .map((tag) => tag.replaceFirst(RegExp(r'^[\d.\-)\s]+'), ''))
      .where((tag) => tag.isNotEmpty && tag.length <= 40)
      .take(2);

  final repository = TagRepository();
  for (final name in tags) {
    final tag = await repository.ensureTag(name, color: hashColor(name));
    await bookTagDao.addRelation(bookId: book.id, tagId: tag.id);
  }
}
