import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/vocabulary/vocabulary_rich_text.dart';
import 'package:flip_card_plus/flip_card_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  late final FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _load();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakCard(Vocabulary card) async {
    try {
      final text = card.contextSentence.isNotEmpty
          ? '${card.word}. ${card.contextSentence}'
          : card.word;
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  Future<void> _load() async {
    final cards = await vocabularyDao.fetchDue(island: widget.island);
    if (!mounted) return;
    setState(() => _cards = cards);
  }

  Future<void> _answer(Vocabulary card, int rating) async {
    if (_busy) return;
    _flutterTts.stop();
    final update = scheduleFsrs(card, rating);
    setState(() => _busy = true);
    try {
      await vocabularyDao.updateFsrs(
        card.id,
        state: update.state,
        step: update.step,
        stability: update.stability,
        difficulty: update.difficulty,
        interval: update.interval,
        nextReviewDate: update.nextReviewDate,
        lastReviewDate: update.lastReviewDate,
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

  Widget _face(Widget child) {
    return SizedBox.expand(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }

  String _formatInterval(Duration interval) {
    if (interval.inDays >= 1) return '${interval.inDays}d';
    if (interval.inHours >= 1) return '${interval.inHours}h';
    return '${interval.inMinutes.clamp(1, 59)}m';
  }

  Widget _answerButton(
    String label,
    int rating,
    Vocabulary card,
    DateTime now,
  ) {
    final update = scheduleFsrs(card, rating, now: now);
    final interval = DateTime.fromMillisecondsSinceEpoch(update.nextReviewDate)
        .difference(now);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          ),
          onPressed: _busy ? null : () => _answer(card, rating),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, textAlign: TextAlign.center),
              Text(_formatInterval(interval),
                  style: const TextStyle(fontSize: 11)),
            ],
          ),
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
      final now = DateTime.now();
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: FlipCardPlus(
                key: ValueKey(card.id),
                duration: const Duration(milliseconds: 450),
                fill: Fill.back,
                borderRadius: BorderRadius.circular(16),
                isDisabled: _busy,
                onFlipDone: (side) {
                  if (!mounted) return;
                  final isBack = side == CardSide.back;
                  setState(() => _revealed = isBack);
                  if (isBack) {
                    _speakCard(card);
                  }
                },
                front: _face(
                  Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.word,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (card.contextSentence.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              card.contextSentence,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Icon(Icons.touch_app_outlined,
                              color: Theme.of(context).hintColor),
                          Text(
                            l10n.vocabularyShowAnswer,
                            style:
                                TextStyle(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                back: _face(
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            card.word,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (card.definition.isNotEmpty)
                          _section(Icons.translate,
                              VocabularyRichText(card.definition)),
                        if (card.languageIsland?.isNotEmpty ?? false)
                          _section(
                              Icons.map_outlined, Text(card.languageIsland!)),
                        if (card.associationMnemonic?.isNotEmpty ?? false)
                          _section(
                            Icons.psychology_outlined,
                            VocabularyRichText(card.associationMnemonic!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_revealed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _answerButton(l10n.vocabularyForgot, 1, card, now),
                  _answerButton(l10n.vocabularyHard, 2, card, now),
                  _answerButton(l10n.vocabularyGood, 3, card, now),
                  _answerButton(l10n.vocabularyEasy, 4, card, now),
                ],
              ),
            ],
          ],
        ),
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
