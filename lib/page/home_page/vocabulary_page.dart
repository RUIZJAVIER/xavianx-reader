import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/page/home_page/vocabulary_edit_page.dart';
import 'package:anx_reader/page/home_page/vocabulary_review_page.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/vocabulary/vocabulary_rich_text.dart';
import 'package:flutter/material.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  List<Vocabulary>? _items;
  int _due = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await vocabularyDao.fetchAll();
    final due = await vocabularyDao.countDue();
    if (!mounted) return;
    setState(() {
      _items = items;
      _due = due;
    });
  }

  Future<void> _openEditor([Vocabulary? card]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VocabularyEditPage(card: card)),
    );
    if (changed == true) _load();
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
    final items = _items ?? const <Vocabulary>[];
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

  Widget _line(IconData icon, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).hintColor),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vocabularyCardsTitle),
        actions: [
          IconButton(
            tooltip: l10n.vocabularyNewCard,
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
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
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openEditor(item),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.word,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (item.definition.isNotEmpty)
                                _line(Icons.translate,
                                    VocabularyRichText(item.definition)),
                              if (item.languageIsland?.isNotEmpty ?? false)
                                _line(Icons.map_outlined,
                                    Text(item.languageIsland!)),
                              if (item.associationMnemonic?.isNotEmpty ?? false)
                                _line(
                                    Icons.psychology_outlined,
                                    VocabularyRichText(
                                        item.associationMnemonic!)),
                              if (item.contextSentence.isNotEmpty)
                                _line(Icons.format_quote,
                                    Text(item.contextSentence)),
                            ],
                          ),
                        ),
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
