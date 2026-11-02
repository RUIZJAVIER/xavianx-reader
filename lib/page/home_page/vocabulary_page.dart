import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/page/home_page/vocabulary_deck_page.dart';
import 'package:anx_reader/page/home_page/vocabulary_edit_page.dart';
import 'package:anx_reader/page/home_page/vocabulary_review_page.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:flutter/material.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  List<VocabularyDeck>? _decks;
  int _due = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final decks = await vocabularyDao.fetchDecks();
    if (!mounted) return;
    setState(() {
      _decks = decks;
      _due = decks.fold(0, (sum, deck) => sum + deck.due);
    });
  }

  Future<void> _openEditor() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VocabularyEditPage()),
    );
    if (changed == true) _load();
  }

  Future<void> _openDeck(VocabularyDeck deck) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VocabularyDeckPage(island: deck.island),
      ),
    );
    // Cards may have been reviewed or edited (or moved to another deck).
    if (mounted) _load();
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VocabularyReviewPage()),
    );
    // Answers are saved even if the user leaves the review early.
    if (mounted) _load();
  }

  Future<void> _export() async {
    final l10n = L10n.of(context);
    final items = await vocabularyDao.fetchAll();
    if (items.isEmpty) {
      AnxToast.show(l10n.vocabularyExportEmpty);
      return;
    }
    try {
      final path = await exportVocabularyCsv(items);
      if (path != null) {
        AnxToast.show('${l10n.notesPageExportedTo} $path');
      }
    } catch (e) {
      AnxToast.show('${l10n.commonFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final decks = _decks;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vocabularyCardsTitle),
        actions: [
          IconButton(
            tooltip: l10n.vocabularyNewCard,
            icon: const Icon(Icons.add),
            onPressed: _openEditor,
          ),
        ],
      ),
      body: decks == null
          ? const Center(child: CircularProgressIndicator())
          : decks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.vocabularyCardsEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: decks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final deck = decks[index];
                    final due = deck.due == 0
                        ? ''
                        : ' · ${deck.due} ${l10n.vocabularyReviewPending}';
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(
                          deck.island,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${deck.total} ${l10n.vocabularyDeckCards}$due'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDeck(deck),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _due == 0 ? null : _openReview,
              icon: const Icon(Icons.school_outlined),
              label: Text(
                  '${l10n.vocabularyReview} ($_due ${l10n.vocabularyReviewPending})'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.vocabularyExportToAnki),
            ),
          ],
        ),
      ),
    );
  }
}
