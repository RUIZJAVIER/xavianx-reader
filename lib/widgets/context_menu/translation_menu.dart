import 'dart:async';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/translate/index.dart';
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
    });
    _startTranslation();
  }

  String? get _effectiveContextText {
    final contextText = widget.contextText?.trim();
    return (contextText == null || contextText.isEmpty) ? null : contextText;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 18,
        child: Center(child: Text('...')),
      ),
    );
  }

  Widget _resultBox(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            child: Text(L10n.of(context).commonCopy),
          ),
        ),
      ],
    );
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
          return _resultBox(data.trim());
        }
        return _loading();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Container(
          height: widget.axis == Axis.vertical ? double.infinity : 150,
          width: widget.axis == Axis.vertical ? 100 : double.infinity,
          decoration: widget.decoration,
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.content,
                  style: const TextStyle(
                    fontSize: 16,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResult(),
                    const Divider(),
                    AxisFlex(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      axis: widget.axis,
                      children: [
                        _langPicker(true),
                        Transform.rotate(
                            angle: widget.axis == Axis.horizontal ? 0 : 1.57,
                            child: Icon(Icons.arrow_forward_ios, size: 16)),
                        _langPicker(false),
                        if (widget.axis == Axis.horizontal) const Spacer(),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
