import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/ai/tools/ai_tool_registry.dart';
import 'package:anx_reader/service/ai/tools/base_tool.dart';

const _getSrsStatisticsToolId = 'get_srs_statistics';

final getSrsStatisticsToolDefinition = AiToolDefinition(
  id: _getSrsStatisticsToolId,
  displayNameBuilder: (L10n l10n) => 'SRS Statistics',
  descriptionBuilder: (L10n l10n) =>
      'Read deck progress, new cards and reviews due today',
  build: (context) => GetSrsStatisticsTool().tool,
);

class GetSrsStatisticsTool
    extends RepositoryTool<Map<String, dynamic>, Map<String, dynamic>> {
  GetSrsStatisticsTool()
      : super(
          name: _getSrsStatisticsToolId,
          description:
              'Get spaced repetition (SRS) statistics and progress across all vocabulary decks: count of total cards, new cards, cards due for review today, and a breakdown per deck/language island. Use this to analyze learning progress and advise the user.',
          inputJsonSchema: const {
            'type': 'object',
            'properties': {},
          },
          timeout: const Duration(seconds: 5),
        );

  @override
  Map<String, dynamic> parseInput(Map<String, dynamic> json) => json;

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> input) async {
    final decks = await vocabularyDao.fetchDecks();
    final allCards = await vocabularyDao.fetchAll();
    final dueCount = await vocabularyDao.countDue();
    final newCount = allCards.where((c) => c.lastReviewDate == null).length;
    final learnedCount = allCards.where((c) => c.lastReviewDate != null).length;

    return {
      'total_cards': allCards.length,
      'new_cards': newCount,
      'due_today': dueCount,
      'learned_cards': learnedCount,
      'total_decks': decks.length,
      'decks': [
        for (final d in decks)
          {
            'island': d.island,
            'new_cards': d.newCards,
            'due_today': d.due,
          }
      ],
    };
  }
}
