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
              'Read and update the user\'s vocabulary list and its language islands. Use this tool to inject a mnemonic story (association_mnemonic) or two native lifeline sentences so the user masters the word inside its language_island. Action "list" returns saved words (optionally filtered by island); action "update" writes association_mnemonic and/or language_island for one entry. The user can later export the list to Anki as CSV.',
          inputJsonSchema: const {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['list', 'update'],
                'description':
                    'Operation to run: "list" (default) reads entries, "update" edits one entry.',
              },
              'id': {
                'type': 'integer',
                'description':
                    'Required for action "update": vocabulary entry id from a previous "list" call.',
              },
              'island': {
                'type': 'string',
                'description':
                    'Optional filter for action "list": only return words in this language island.',
              },
              'limit': {
                'type': 'integer',
                'description':
                    'Optional. Maximum entries to return for action "list" (range 1-100, defaults to 20).',
              },
              'associationMnemonic': {
                'type': 'string',
                'description':
                    'For action "update": a short mnemonic story (stored as association_mnemonic), or two native lifeline sentences, that help the user remember the word in its language island.',
              },
              'languageIsland': {
                'type': 'string',
                'description':
                    'For action "update": rename or set the language island (stored as language_island) of the entry.',
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
    if (input.isUpdate) {
      final id = input.id;
      if (id == null) {
        throw ArgumentError('id is required when action is "update"');
      }
      final updated = await vocabularyDao.updateFields(
        id,
        associationMnemonic: input.associationMnemonic,
        languageIsland: input.languageIsland,
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
      'timestamp': entry.timestamp.toIso8601String(),
    };
  }
}
