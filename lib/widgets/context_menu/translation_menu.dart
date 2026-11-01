import 'dart:async';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/translate/index.dart';
import 'package:anx_reader/service/vocabulary/vocabulary_service.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/axis_flex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class TranslationMenu extends StatefulWidget {
  const TranslationMenu({
    super.key,
    required this.content,
    required this.decoration,
    required this.axis,
    this.contextText,
  });
  final String content;
  final BoxDecoration decoration;
  final Axis axis;
  final String? contextText;
  @override
  State<TranslationMenu> createState() => _TranslationMenuState();
}

class _TranslationMenuState extends State<TranslationMenu> {
  Stream<String>? _stream;
  Timer? _debounceTimer;
  bool _initialized = false;

  /// Último resultado mostrado (para el botón Copiar de la barra inferior).
  String _lastResult = '';

  LangListEnum _from = LangListEnum.auto;
  LangListEnum _to = LangListEnum.english;
  TranslateService _service = TranslateService.bingWeb;

  @override
  void initState() {
    super.initState();
    _from = Prefs().translateFrom;
    _to = Prefs().translateTo;
    _service = Prefs().translateService;
    _initializeTranslation();
  }

  @override
  void didUpdateWidget(covariant TranslationMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el texto seleccionado cambia, se cancela la petición anterior y se
    // lanza una nueva (el StreamBuilder cancela la suscripción al cambiar el
    // stream).
    if (oldWidget.content != widget.content) {
      _retranslate();
    }
  }

  void _initializeTranslation() {
    // Use addPostFrameCallback to ensure the UI is rendered first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;

      // Debounce: Delay the translation call to ensure context has stopped
      // updating.
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || _initialized) return;
        _startTranslation();
      });
    });
  }

  void _startTranslation() {
    final from = Prefs().translateFrom;
    final to = Prefs().translateTo;
    final service = Prefs().translateService;

    setState(() {
      _from = from;
      _to = to;
      _service = service;
      _lastResult = '';
      // Los proveedores WebView se dibujan con su propio widget; el resto
      // usa el flujo inteligente (proveedor configurado + respaldo GTX).
      _stream = service.isWebView
          ? null
          : smartTranslateSelectionStream(
              widget.content,
              from: from,
              to: to,
              contextText: _effectiveContextText,
            );
      _initialized = true;
    });
  }

  void _retranslate() {
    if (!mounted) return;
    _debounceTimer?.cancel();
    setState(() {
      _initialized = false;
      _stream = null;
      _lastResult = '';
    });
    _startTranslation();
  }

  String? get _effectiveContextText {
    final contextText = widget.contextText?.trim();
    // Skip context for long selections: it adds noise and slows down the AI.
    if (widget.content.length > 200) return null;
    return (contextText == null || contextText.isEmpty) ? null : contextText;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _copyResult() {
    final text = _lastResult.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _saveVocabulary() async {
    final definition = _lastResult.trim();
    if (definition.isEmpty) return;

    final islandController = TextEditingController();
    final island = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.of(dialogContext).vocabularySave),
        content: TextField(
          controller: islandController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: L10n.of(dialogContext).vocabularyIslandLabel,
            hintText: L10n.of(dialogContext).vocabularyIslandHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L10n.of(dialogContext).commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, islandController.text),
            child: Text(L10n.of(dialogContext).commonSave),
          ),
        ],
      ),
    );
    islandController.dispose();
    if (island == null || !mounted) return;

    try {
      await saveVocabulary(
        word: widget.content,
        definition: definition,
        contextSentence: widget.contextText,
        languageIsland: island,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(L10n.of(context).vocabularySaved)),
        );
      } else {
        AnxToast.show(L10n.of(context).vocabularySaved);
      }
    } catch (e) {
      if (!mounted) return;
      AnxToast.show('${L10n.of(context).commonFailed}: $e');
    }
  }

  Widget _langPicker(bool isFrom) {
    final MenuController menuController = MenuController();

    return PointerInterceptor(
      child: MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.secondaryContainer,
          ),
          maximumSize: WidgetStateProperty.all(const Size(300, 300)),
        ),
        controller: menuController,
        menuChildren: [
          for (var lang in LangListEnum.values)
            PointerInterceptor(
              child: MenuItemButton(
                onPressed: () {
                  if (isFrom) {
                    Prefs().translateFrom = lang;
                  } else {
                    Prefs().translateTo = lang;
                  }
                  // El formato del resultado depende del idioma detectado y
                  // del idioma de destino: se vuelve a traducir.
                  _retranslate();
                },
                child: Text(lang.getNative(context)),
              ),
            ),
        ],
        builder: (context, controller, child) {
          return GestureDetector(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Text(
              isFrom
                  ? Prefs().translateFrom.getNative(context)
                  : Prefs().translateTo.getNative(context),
            ),
          );
        },
      ),
    );
  }

  Widget _loading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Traduciendo...',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const LinearProgressIndicator(),
      ],
    );
  }

  Widget _resultBox(String text) {
    // El botón Copiar vive en la barra inferior fija; aquí sólo va el texto,
    // que se desplaza dentro del área superior.
    return Text(text, style: const TextStyle(fontSize: 14, height: 1.35));
  }

  Widget _buildResult() {
    if (_service.isWebView) {
      return _service.provider.translate(
        widget.content,
        _from,
        _to,
        contextText: _effectiveContextText,
      );
    }

    final stream = _stream;
    if (stream == null) return _loading();

    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        // Nunca se muestran errores de capacidad: el flujo ya cambia a Google
        // GTX y solo emite contenido válido.
        if (data != null && !looksLikeTranslationFailure(data)) {
          final text = data.trim();
          if (text.isNotEmpty) {
            _lastResult = text;
            return _resultBox(text);
          }
        }
        return _loading();
      },
    );
  }

  Widget _bottomBar() {
    final canCopy = _lastResult.trim().isNotEmpty;
    return AxisFlex(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      axis: widget.axis,
      children: [
        _langPicker(true),
        Transform.rotate(
            angle: widget.axis == Axis.horizontal ? 0 : 1.57,
            child: const Icon(Icons.arrow_forward_ios, size: 16)),
        _langPicker(false),
        if (widget.axis == Axis.horizontal) const Spacer(),
        // Guarda la palabra y su definición en el vocabulario (Anki).
        if (!_service.isWebView)
          IconButton(
            tooltip: L10n.of(context).vocabularySave,
            onPressed: canCopy ? _saveVocabulary : null,
            icon: const Icon(Icons.push_pin_outlined, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        // Los proveedores WebView traen su propia interfaz (y su propio botón
        // de copiar): no se duplica aquí.
        if (!_service.isWebView)
          IconButton(
            tooltip: L10n.of(context).commonCopy,
            onPressed: canCopy ? _copyResult : null,
            icon: const Icon(Icons.copy, size: 18),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Container(
          height: widget.axis == Axis.vertical ? double.infinity : 190,
          width: widget.axis == Axis.vertical ? 120 : double.infinity,
          decoration: widget.decoration,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Texto seleccionado + resultado en un área desplazable,
              // separada de la barra inferior (idiomas y Copiar).
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      _buildResult(),
                    ],
                  ),
                ),
              ),
              const Divider(height: 12),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }
}
