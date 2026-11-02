import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/vocabulary/vocabulary_rich_text.dart';
import 'package:flutter/material.dart';

class VocabularyReviewPage extends StatefulWidget {
  const VocabularyReviewPage({super.key, this.island});

  /// When set, only the cards of that deck are reviewed.
  final String? island;

  @override
  State<VocabularyReviewPage> createState() => _VocabularyReviewPageState();
}

class _VocabularyReviewPageState extends State<VocabularyReviewPage> {
  List<Vocabulary>? _cards;
  int _index = 0;
  bool _revealed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await vocabularyDao.fetchDue(island: widget.island);
    if (!mounted) return;
    setState(() => _cards = cards);
  }

  Future<void> _answer(int quality) async {
    if (_busy || !_revealed) return;
    final card = _cards![_index];
    final update = applySm2(
      quality: quality,
      efactor: card.efactor,
      repetition: card.repetition,
      interval: card.interval,
    );
    setState(() => _busy = true);
    try {
      await vocabularyDao.updateSrs(
        card.id,
        efactor: update.efactor,
        repetition: update.repetition,
        interval: update.interval,
        nextReviewDate: update.nextReviewDate,
      );
      if (!mounted) return;
      setState(() {
        _index++;
        _revealed = false;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AnxToast.show('${L10n.of(context).commonFailed}: $e');
    }
  }

  Widget _section(IconData icon, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _answerButton(String label, int quality) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FilledButton(
          onPressed: _busy ? null : () => _answer(quality),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final cards = _cards;

    Widget body;
    if (cards == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (cards.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.vocabularyReviewEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
      );
    } else if (_index >= cards.length) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(l10n.vocabularyReviewDone),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        ),
      );
    } else {
      final card = cards[_index];
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            card.word,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (card.contextSentence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              card.contextSentence,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!_revealed)
            FilledButton.icon(
              onPressed: () => setState(() => _revealed = true),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l10n.vocabularyShowAnswer),
            )
          else ...[
            if (card.definition.isNotEmpty)
              _section(Icons.translate, VocabularyRichText(card.definition)),
            if (card.languageIsland?.isNotEmpty ?? false)
              _section(Icons.map_outlined, Text(card.languageIsland!)),
            if (card.associationMnemonic?.isNotEmpty ?? false)
              _section(
                Icons.psychology_outlined,
                VocabularyRichText(card.associationMnemonic!),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _answerButton(l10n.vocabularyForgot, 0),
                _answerButton(l10n.vocabularyHard, 3),
                _answerButton(l10n.vocabularyGood, 4),
                _answerButton(l10n.vocabularyEasy, 5),
              ],
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.island ?? l10n.vocabularyReview),
        actions: [
          if (cards != null && cards.isNotEmpty && _index < cards.length)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1}/${cards.length}'),
              ),
            ),
        ],
      ),
      body: body,
    );
  }
}
