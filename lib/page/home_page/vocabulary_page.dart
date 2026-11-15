import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/page/home_page/vocabulary_coach_page.dart';
import 'package:anx_reader/page/home_page/vocabulary_deck_page.dart';
import 'package:anx_reader/page/home_page/vocabulary_decks_page.dart';
import 'package:anx_reader/page/home_page/vocabulary_edit_page.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/vocabulary/vocabulary_progress_rings.dart';
import 'package:flutter/material.dart';

/// Learning dashboard: smart review, progress rings and content sources.
class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  VocabularyProgress? _progress;
  int _due = 0;
  bool _guideDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final progress = await vocabularyDao.fetchProgress();
      final due = await vocabularyDao.countDue(now: _endOfToday());
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _due = due;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _progress = _progress ??
            const VocabularyProgress(reviewed: 0, recognized: 0, learned: 0);
        _due = 0;
      });
    }
  }

  /// Cards scheduled for any moment of today already count as pending.
  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  Future<void> _openAllWords() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VocabularyDeckPage()),
    );
    if (mounted) _load();
  }

  Future<void> _openDecks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VocabularyDecksPage()),
    );
    if (mounted) _load();
  }

  Future<void> _openEditor() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VocabularyEditPage()),
    );
    if (changed == true && mounted) _load();
  }

  void _openCoach() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VocabularyCoachPage()),
    );
  }

  /// The book importer lives in the library behind this page.
  void _openLibrary() {
    Navigator.of(context).maybePop();
  }

  void _comingSoon() {
    AnxToast.show('Próximamente');
  }

  void _startSmartReview() {
    AnxToast.show(_due > 0
        ? 'Modo de repaso en construcción (Fase 3)'
        : 'Estás al día');
  }

  void _showReadingTips() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lectura inmersiva: consejos rápidos'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Tip('Empieza con una o dos páginas al día: la constancia gana '
                  'a la cantidad.'),
              _Tip('Guarda sólo las palabras que te frenan la lectura; el resto '
                  'se aprende por contexto.'),
              _Tip('Repasa la frase completa, no la palabra suelta: el contexto '
                  'es la memoria.'),
              _Tip('Mezcla fuentes: un vídeo corto, un artículo de tu tema y un '
                  'libro de ficción.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L10n.of(context).commonOk),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final progress = _progress;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vocabularyTitle),
        actions: [
          IconButton(
            tooltip: 'Islas',
            icon: const Icon(Icons.folder_outlined),
            onPressed: _openDecks,
          ),
          IconButton(
            tooltip: l10n.vocabularyNewCard,
            icon: const Icon(Icons.add),
            onPressed: _openEditor,
          ),
          IconButton(
            tooltip: 'Coach',
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: _openCoach,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: progress == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _welcomeHeader(context),
                  const SizedBox(height: 20),
                  _smartReviewCard(context),
                  const SizedBox(height: 16),
                  _progressCard(context, progress),
                  const SizedBox(height: 16),
                  if (!_guideDismissed) _guideCard(context),
                  const SizedBox(height: 24),
                  _sourcesSection(context),
                ],
              ),
      ),
    );
  }

  Widget _welcomeHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = Prefs().translateTo;
    final language =
        target.code == 'auto' ? 'un nuevo idioma' : target.getNative(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.school_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Aprendiendo $language',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _smartReviewCard(BuildContext context) {
    final hasPending = _due > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C6FFF), Color(0xFF6A4BE8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C6FFF).withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMART REVIEW',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasPending ? '$_due pendientes' : 'Estás al día',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPending
                      ? 'Repasa con el contexto de tus libros'
                      : 'Vuelve cuando guardes palabras nuevas',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _startSmartReview,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4055D8),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            child: const Text('EMPEZAR'),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(BuildContext context, VocabularyProgress progress) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: _openAllWords,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tu progreso',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Semantics(
                    label:
                        '${progress.reviewed} revisadas, ${progress.recognized} '
                        'reconocidas, ${progress.learned} aprendidas',
                    child: VocabularyProgressRings(
                      sweeps: progress.ringSweeps,
                      center: FittedBox(
                        child: Text(
                          '${progress.reviewed}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendRow(context, vocabularyRingColors[0],
                            progress.reviewed, 'Revisadas'),
                        const SizedBox(height: 10),
                        _legendRow(context, vocabularyRingColors[1],
                            progress.recognized, 'Reconocidas'),
                        const SizedBox(height: 10),
                        _legendRow(context, vocabularyRingColors[2],
                            progress.learned, 'Aprendidas'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Toca para ver todas tus palabras',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow(BuildContext context, Color color, int count, String label) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _guideCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Color(0xFFE0A100), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cómo elegir fuentes para practicar',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Descartar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _guideDismissed = true),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Elige material corto, con audio o traducción fácil, y que te '
                'interese de verdad.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showReadingTips,
                child: const Text('Ver consejos rápidos'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourcesSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AGREGAR FUENTES',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _sourceTile(
                context,
                icon: Icons.play_circle_outline,
                label: 'YouTube',
                color: const Color(0xFFE53935),
                onTap: _comingSoon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _sourceTile(
                context,
                icon: Icons.article_outlined,
                label: 'Artículo',
                color: const Color(0xFF1E88E5),
                onTap: _comingSoon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _sourceTile(
                context,
                icon: Icons.menu_book_outlined,
                label: 'Libro',
                subtitle: 'EPUB / PDF',
                color: const Color(0xFF5E35B1),
                onTap: _openLibrary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sourceTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
