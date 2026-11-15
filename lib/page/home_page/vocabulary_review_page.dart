import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/vocabulary/vocabulary_rich_text.dart';
import 'package:flip_card_plus/flip_card_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum _ReviewMode { flashcard, quiz }

class VocabularyReviewPage extends StatefulWidget {
  const VocabularyReviewPage({super.key, this.island});

  /// When set, only the cards of that deck are reviewed.
  final String? island;

  @override
  State<VocabularyReviewPage> createState() => _VocabularyReviewPageState();
}

class _VocabularyReviewPageState extends State<VocabularyReviewPage> {
  List<Vocabulary>? _cards;

  /// Card id -> shuffled quiz options (definition plus up to 3 distractors).
  Map<int, List<String>> _choices = const {};

  int _index = 0;
  int _reviewed = 0;
  int _correct = 0;
  int _skipped = 0;
  _ReviewMode _mode = _ReviewMode.flashcard;
  bool _revealed = false;
  bool _busy = false;
  String? _picked;

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

  /// Cards due at any point today, matching the dashboard counter.
  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  Future<void> _load() async {
    final cards =
        await vocabularyDao.fetchDue(island: widget.island, now: _endOfToday());
    final pool = await vocabularyDao.fetchRandomDefinitions();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _choices = buildQuizChoices(cards, pool);
    });
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
        _reviewed++;
        _revealed = false;
        _picked = null;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AnxToast.show('${L10n.of(context).commonFailed}: $e');
    }
  }

  /// Quiz answer: shows the colors for a moment, then rates the card.
  /// Correct -> Bien, wrong -> Otra vez.
  Future<void> _answerQuiz(Vocabulary card, String option) async {
    if (_busy || _picked != null) return;
    final right = option == card.definition.trim();
    setState(() {
      _picked = option;
      if (right) _correct++;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _answer(card, right ? 3 : 1);
  }

  void _skipCard() {
    setState(() {
      _index++;
      _skipped++;
      _revealed = false;
      _picked = null;
    });
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

  Widget _modeSelector(List<Vocabulary> cards) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<_ReviewMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _ReviewMode.flashcard,
                  icon: Icon(Icons.style_outlined),
                  label: Text('Tarjeta'),
                ),
                ButtonSegment(
                  value: _ReviewMode.quiz,
                  icon: Icon(Icons.quiz_outlined),
                  label: Text('Quiz'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                  _revealed = false;
                  _picked = null;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_index + 1}/${cards.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }

  Widget _flashcard(Vocabulary card) {
    final l10n = L10n.of(context);
    final now = DateTime.now();
    return Padding(
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
                          style: TextStyle(color: Theme.of(context).hintColor),
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
                        _section(Icons.map_outlined, Text(card.languageIsland!)),
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

  Widget _quiz(Vocabulary card) {
    final options = _choices[card.id];
    if (options == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate, size: 40, color: Theme.of(context).hintColor),
              const SizedBox(height: 12),
              Text(
                'Esta palabra no tiene traducción guardada, así que no se puede '
                'preguntar en el quiz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _skipCard,
                child: const Text('Siguiente'),
              ),
            ],
          ),
        ),
      );
    }

    final answered = _picked != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Center(
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
                    const SizedBox(height: 20),
                    Text(
                      '¿Cuál es su significado?',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final option in options)
            _optionButton(card, option, answered),
        ],
      ),
    );
  }

  Widget _optionButton(Vocabulary card, String option, bool answered) {
    final scheme = Theme.of(context).colorScheme;
    final isRight = option == card.definition.trim();
    final isPicked = option == _picked;

    var background = scheme.secondaryContainer;
    var foreground = scheme.onSecondaryContainer;
    if (answered) {
      if (isRight) {
        background = Colors.green.shade600;
        foreground = Colors.white;
      } else if (isPicked) {
        background = Colors.red.shade600;
        foreground = Colors.white;
      } else {
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: foreground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: answered ? null : () => _answerQuiz(card, option),
          child: Align(
            alignment: Alignment.centerLeft,
            child: VocabularyRichText(option),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Estás al día',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay palabras pendientes de repaso. Vuelve cuando guardes '
              'palabras nuevas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(List<Vocabulary> cards) {
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.celebration_outlined,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  '¡Sesión completada!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text('$_reviewed de ${cards.length} repasadas', style: hint),
                if (_correct > 0)
                  Text('$_correct aciertos en el quiz', style: hint),
                if (_skipped > 0)
                  Text('$_skipped omitidas (sin traducción guardada)',
                      style: hint, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
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
      body = _emptyState();
    } else if (_index >= cards.length) {
      body = _summary(cards);
    } else {
      final card = cards[_index];
      body = Column(
        children: [
          _modeSelector(cards),
          Expanded(
            child: _mode == _ReviewMode.flashcard
                ? _flashcard(card)
                : _quiz(card),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.island ?? l10n.vocabularyReview)),
      body: body,
    );
  }
}
