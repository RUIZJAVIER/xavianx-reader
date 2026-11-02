import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/page/home_page/vocabulary_edit_page.dart';
import 'package:anx_reader/page/home_page/vocabulary_review_page.dart';
import 'package:anx_reader/widgets/vocabulary/vocabulary_rich_text.dart';
import 'package:flutter/material.dart';

/// Cards of a single language island.
class VocabularyDeckPage extends StatefulWidget {
  const VocabularyDeckPage({super.key, required this.island});

  final String island;

  @override
  State<VocabularyDeckPage> createState() => _VocabularyDeckPageState();
}

class _VocabularyDeckPageState extends State<VocabularyDeckPage> {
  List<Vocabulary>? _items;
  int _due = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await vocabularyDao.fetchAll(island: widget.island);
    final due = await vocabularyDao.countDue(island: widget.island);
    if (!mounted) return;
    setState(() {
      _items = items;
      _due = due;
    });
  }

  Future<void> _openEditor(Vocabulary card) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VocabularyEditPage(card: card)),
    );
    if (changed == true) _load();
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VocabularyReviewPage(island: widget.island),
      ),
    );
    if (mounted) _load();
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
      appBar: AppBar(title: Text(widget.island)),
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
        child: FilledButton.icon(
          onPressed: _due == 0 ? null : _openReview,
          icon: const Icon(Icons.school_outlined),
          label: Text(
              '${l10n.vocabularyReview} ($_due ${l10n.vocabularyReviewPending})'),
        ),
      ),
    );
  }
}
