import 'package:anx_reader/dao/vocabulary.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/vocabulary.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:flutter/material.dart';

class VocabularyEditPage extends StatefulWidget {
  const VocabularyEditPage({super.key, this.card});

  final Vocabulary? card;

  @override
  State<VocabularyEditPage> createState() => _VocabularyEditPageState();
}

class _VocabularyEditPageState extends State<VocabularyEditPage> {
  late final TextEditingController _word;
  late final TextEditingController _definition;
  late final TextEditingController _context;
  late final TextEditingController _island;
  late final TextEditingController _tags;
  late final TextEditingController _mnemonic;
  final _definitionFocus = FocusNode();
  final _mnemonicFocus = FocusNode();
  bool _saving = false;
  bool _generatingMnemonic = false;
  bool _inferringIsland = false;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _word = TextEditingController(text: card?.word ?? '');
    _definition = TextEditingController(text: card?.definition ?? '');
    _context = TextEditingController(text: card?.contextSentence ?? '');
    _island = TextEditingController(text: card?.languageIsland ?? '');
    _tags = TextEditingController(text: card?.tags ?? '');
    _mnemonic = TextEditingController(text: card?.associationMnemonic ?? '');
  }

  @override
  void dispose() {
    _word.dispose();
    _definition.dispose();
    _context.dispose();
    _island.dispose();
    _tags.dispose();
    _mnemonic.dispose();
    _definitionFocus.dispose();
    _mnemonicFocus.dispose();
    super.dispose();
  }

  void _wrap(
    TextEditingController controller,
    FocusNode focusNode,
    String open,
    String close,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    final hasSelection = selection.isValid &&
        selection.start >= 0 &&
        selection.end >= 0 &&
        selection.end <= text.length;
    final start = hasSelection ? selection.start : text.length;
    final end = hasSelection ? selection.end : text.length;
    final selected = text.substring(start, end);
    final replacement = '$open$selected$close';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    focusNode.requestFocus();
  }

  Widget _formatButton({
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _formatBar(TextEditingController controller, FocusNode focusNode) {
    final l10n = L10n.of(context);
    return Wrap(
      spacing: 2,
      children: [
        _formatButton(
          tooltip: l10n.vocabularyBold,
          icon: const Text('B', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _wrap(controller, focusNode, '<b>', '</b>'),
        ),
        _formatButton(
          tooltip: l10n.vocabularyItalic,
          icon: const Text('I', style: TextStyle(fontStyle: FontStyle.italic)),
          onPressed: () => _wrap(controller, focusNode, '<i>', '</i>'),
        ),
        for (final color in const ['#e53935', '#1e88e5', '#43a047'])
          _formatButton(
            tooltip: l10n.vocabularyColor,
            icon: Icon(Icons.circle, size: 16, color: Color(
              int.parse(color.substring(1), radix: 16) | 0xff000000,
            )),
            onPressed: () =>
                _wrap(controller, focusNode, '<font color="$color">', '</font>'),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    final word = _word.text.trim();
    final definition = _definition.text.trim();
    if (word.isEmpty || definition.isEmpty) {
      AnxToast.show(l10n.vocabularyFieldRequired);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    final mnemonic = _mnemonic.text.trim();
    final tags = _tags.text.trim().isEmpty ? null : _tags.text.trim();
    try {
      final card = widget.card;
      if (card == null) {
        final result = await saveVocabulary(
          word: word,
          definition: definition,
          contextSentence: _context.text,
          languageIsland: _island.text,
          associationMnemonic: mnemonic,
          tags: tags,
        );
        if (!mounted) return;
        final message = result.fallbackUsed
            ? 'Palabra guardada en "General" (IA no disponible)'
            : l10n.vocabularySaved;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: result.fallbackUsed ? Colors.orange : Colors.green,
            content: Text(message),
          ),
        );
        Navigator.pop(context, true);
        return;
      } else {
        await vocabularyDao.updateCard(card.copyWith(
          word: word,
          definition: definition,
          contextSentence: _context.text.trim(),
          languageIsland: _island.text.trim(),
          associationMnemonic: mnemonic,
          tags: tags,
        ));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(l10n.vocabularySaved),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('${l10n.commonFailed}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateMnemonic() async {
    final word = _word.text.trim();
    if (word.isEmpty) {
      AnxToast.show(L10n.of(context).vocabularyFieldRequired);
      return;
    }
    setState(() => _generatingMnemonic = true);
    try {
      final mnemonic = await generateAssociationMnemonic(
        word: word,
        definition: _definition.text.trim(),
        contextSentence: _context.text.trim(),
        languageIsland: _island.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _mnemonic.text = mnemonic;
      });
      AnxToast.show('Mnemotecnia generada ✨');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('${L10n.of(context).commonFailed}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingMnemonic = false);
    }
  }

  Future<void> _inferIsland() async {
    final word = _word.text.trim();
    if (word.isEmpty) {
      AnxToast.show(L10n.of(context).vocabularyFieldRequired);
      return;
    }
    setState(() => _inferringIsland = true);
    try {
      final island = await inferLanguageIsland(
        word: word,
        definition: _definition.text.trim(),
        contextSentence: _context.text.trim(),
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _island.text = island;
      });
      AnxToast.show('Isla asignada: $island ✨');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('${L10n.of(context).commonFailed}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _inferringIsland = false);
    }
  }

  Widget _richField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          minLines: 2,
          maxLines: null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: trailing,
          ),
        ),
        _formatBar(controller, focusNode),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null
            ? l10n.vocabularyNewCard
            : l10n.vocabularyEditCard),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _word,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.vocabularyFieldWord,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _richField(
            label: l10n.vocabularyFieldDefinition,
            controller: _definition,
            focusNode: _definitionFocus,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _context,
            minLines: 2,
            maxLines: null,
            decoration: InputDecoration(
              labelText: l10n.vocabularyFieldContext,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _island,
            decoration: InputDecoration(
              labelText: l10n.vocabularyIslandLabel,
              hintText: l10n.vocabularyIslandHint,
              border: const OutlineInputBorder(),
              suffixIcon: _inferringIsland
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Clasificar isla con IA ✨',
                      icon: const Icon(Icons.auto_awesome),
                      onPressed: _inferIsland,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Etiquetas (Tags)',
              hintText: 'ej. verbo, b2, viaje',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          _richField(
            label: l10n.vocabularyFieldMnemonic,
            controller: _mnemonic,
            focusNode: _mnemonicFocus,
            trailing: _generatingMnemonic
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Generar Mnemotecnia con IA ✨',
                    icon: const Icon(Icons.auto_awesome),
                    onPressed: _generateMnemonic,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonSave),
        ),
      ),
    );
  }
}
