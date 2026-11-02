import 'package:anx_reader/dao/book_note.dart';
import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/page/home_page/vocabulary_coach_page.dart';
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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loading = true;
    try {
      final decks = await vocabularyDao.fetchDecks();
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _due = decks.fold(0, (sum, deck) => sum + deck.newCards + deck.due);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _decks = _decks ?? const [];
        _due = 0;
        _loading = false;
      });
    }
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

  Future<void> _exportPkmMarkdown() async {
    final l10n = L10n.of(context);
    final items = await vocabularyDao.fetchAll();
    final notes = await bookNoteDao.selectAllBookNotes();
    if (items.isEmpty && notes.isEmpty) {
      AnxToast.show(l10n.vocabularyExportEmpty);
      return;
    }
    try {
      final path = await exportPkmMarkdown(vocabulary: items, notes: notes);
      if (path != null) {
        AnxToast.show('${l10n.notesPageExportedTo} $path');
      }
    } catch (e) {
      AnxToast.show('${l10n.commonFailed}: $e');
    }
  }

  /// Blue "new" / green "due today" numeric badge.
  Widget _counter(Color color, int count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: (decks == null || (_loading && decks.isEmpty))
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : (decks.isEmpty && !_loading)
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 64),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.style_outlined,
                              size: 48,
                              color: Theme.of(context).hintColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.vocabularyCardsEmpty.isNotEmpty
                                  ? l10n.vocabularyCardsEmpty
                                  : 'Aún no hay palabras guardadas',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: decks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final deck = decks[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            deck.island,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                _counter(Colors.blue, deck.newCards,
                                    l10n.vocabularyDeckNew),
                                _counter(Colors.green, deck.due,
                                    l10n.vocabularyDeckDue),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDeck(deck),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vocabulary_coach_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VocabularyCoachPage()),
        ),
        icon: const Icon(Icons.psychology_alt_outlined),
        label: const Text('Coach'),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.upload_file),
                    label: Text(l10n.vocabularyExportToAnki),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportPkmMarkdown,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Exportar .md'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
