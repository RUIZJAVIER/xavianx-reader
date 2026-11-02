import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/ai/tools/ai_tool_registry.dart';
import 'package:anx_reader/service/ai/tools/base_tool.dart';
import 'package:anx_reader/service/ai/tools/input/manage_vocabulary_input.dart';

const _manageVocabularyToolId = 'manage_vocabulary';

final manageVocabularyToolDefinition = AiToolDefinition(
  id: _manageVocabularyToolId,
  displayNameBuilder: (L10n l10n) => l10n.aiToolManageVocabularyName,
  descriptionBuilder: (L10n l10n) => l10n.aiToolManageVocabularyDescription,
  build: (context) => ManageVocabularyTool().tool,
);

class ManageVocabularyTool
    extends RepositoryTool<ManageVocabularyInput, Map<String, dynamic>> {
  ManageVocabularyTool()
      : super(
          name: _manageVocabularyToolId,
          description:
              'Read, create, and update the user\'s vocabulary list, language islands, and tags. Use this tool to save new cards, inject mnemonic stories (association_mnemonic), assign tags (tags), or organize words into language islands (language_island). Action "list" reads entries, "create" adds a new card, and "update" edits an existing card.',
          inputJsonSchema: const {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['list', 'create', 'update'],
                'description':
                    'Operation to run: "list" (default) reads entries, "create" adds a new card, "update" edits one entry.',
              },
              'id': {
                'type': 'integer',
                'description':
                    'Required for action "update": vocabulary entry id from a previous "list" call.',
              },
              'word': {
                'type': 'string',
                'description':
                    'Required for action "create": the word or phrase to add.',
              },
              'definition': {
                'type': 'string',
                'description':
                    'For action "create": definition or translation of the word.',
              },
              'contextSentence': {
                'type': 'string',
                'description':
                    'For action "create": example context sentence where the word appears.',
              },
              'island': {
                'type': 'string',
                'description':
                    'Optional filter for action "list": only return words in this language island. Also used as fallback island for "create".',
              },
              'limit': {
                'type': 'integer',
                'description':
                    'Optional. Maximum entries to return for action "list" (range 1-100, defaults to 20).',
              },
              'associationMnemonic': {
                'type': 'string',
                'description':
                    'For action "create" or "update": a short mnemonic story (stored as association_mnemonic), or two native lifeline sentences.',
              },
              'languageIsland': {
                'type': 'string',
                'description':
                    'For action "create" or "update": language island (stored as language_island) of the entry.',
              },
              'tags': {
                'type': 'string',
                'description':
                    'Optional for action "create" and "update": comma-separated tags or labels (stored as tags, e.g. "verb, irregular, b2").',
              },
            },
          },
          timeout: const Duration(seconds: 5),
        );

  @override
  ManageVocabularyInput parseInput(Map<String, dynamic> json) {
    return ManageVocabularyInput.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> run(ManageVocabularyInput input) async {
    if (input.isCreate) {
      final word = input.word?.trim();
      if (word == null || word.isEmpty) {
        throw ArgumentError('word is required when action is "create"');
      }
      final island = (input.languageIsland?.trim().isNotEmpty ?? false)
          ? input.languageIsland!.trim()
          : (input.island?.trim().isNotEmpty ?? false
              ? input.island!.trim()
              : generalLanguageIsland);

      final card = Vocabulary(
        id: -1,
        word: word,
        definition: input.definition?.trim() ?? '',
        contextSentence: input.contextSentence?.trim() ?? '',
        associationMnemonic: input.associationMnemonic?.trim(),
        languageIsland: island,
        tags: input.tags?.trim(),
        timestamp: DateTime.now(),
        nextReviewDate: DateTime.now().millisecondsSinceEpoch,
      );
      final id = await vocabularyDao.insert(VocabularyDao.table, card.toMap());
      final created = await vocabularyDao.fetchById(id);
      return {
        'action': 'create',
        'id': id,
        'vocabulary': created == null ? null : _toJson(created),
      };
    }

    if (input.isUpdate) {
      final id = input.id;
      if (id == null) {
        throw ArgumentError('id is required when action is "update"');
      }
      final updated = await vocabularyDao.updateFields(
        id,
        associationMnemonic: input.associationMnemonic,
        languageIsland: input.languageIsland,
        tags: input.tags?.trim(),
      );
      if (!updated) {
        throw StateError(
            'Vocabulary entry $id was not updated (missing or no fields)');
      }
      final entry = await vocabularyDao.fetchById(id);
      return {
        'action': 'update',
        'vocabulary': entry == null ? null : _toJson(entry),
      };
    }

    final items = await vocabularyDao.fetchAll(
      island: input.island,
      limit: input.resolvedLimit(),
    );
    return {
      'action': 'list',
      'count': items.length,
      'vocabulary': items.map(_toJson).toList(),
    };
  }

  Map<String, dynamic> _toJson(Vocabulary entry) {
    return {
      'id': entry.id,
      'word': entry.word,
      'definition': entry.definition,
      'contextSentence': entry.contextSentence,
      'associationMnemonic': entry.associationMnemonic,
      'languageIsland': entry.languageIsland,
      'tags': entry.tags,
      'timestamp': entry.timestamp.toIso8601String(),
    };
  }
}
