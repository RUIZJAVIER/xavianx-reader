import 'dart:async';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/translate/google_gtx.dart';
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
  Stream<String>? _providerStream;
  Future<String>? _fastFuture;
  Timer? _debounceTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTranslation();
  }

  void _initializeTranslation() {
    // Use addPostFrameCallback to ensure the UI is rendered first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;

      // Debounce: Delay the translation call to ensure context has stopped updating
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || _initialized) return;

        final from = Prefs().translateFrom;
        final to = Prefs().translateTo;
        final service = Prefs().translateService;

        // Con el motor de IA la saturación (RateLimitException) es frecuente:
        // se lanza en paralelo el motor rápido de Google para tener una
        // traducción instantánea y usarla si la IA falla.
        if (service == TranslateService.ai) {
          _ensureFastTranslation(from, to);
        }

        setState(() {
          _providerStream = service.provider.translateStream(
            widget.content,
            from,
            to,
            contextText: _effectiveContextText,
          );
          _initialized = true;
        });
      });
    });
  }

  String? get _effectiveContextText {
    final contextText = widget.contextText?.trim();
    return (contextText == null || contextText.isEmpty) ? null : contextText;
  }

  /// Motor rápido (Google GTX): se lanza una sola vez y se reutiliza.
  void _ensureFastTranslation(LangListEnum from, LangListEnum to) {
    if (_fastFuture != null) return;
    final future = GoogleGtxTranslateProvider()
        .translateTextOnly(widget.content, from, to);
    _fastFuture = future;
    future.then(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (Object _) {
        if (mounted) setState(() {});
      },
    );
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

  bool _isProviderResultValid(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '...') return false;
    // El proveedor de IA devuelve el error como texto (RateLimitException...).
    final errorLabel = L10n.of(context).translateError;
    if (errorLabel.isNotEmpty && trimmed.startsWith(errorLabel)) return false;
    return true;
  }

  Widget _resultBox(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: text)),
                child: Text(L10n.of(context).commonCopy)),
          ],
        ),
      ],
    );
  }

  Widget _buildResult() {
    final stream = _providerStream;
    if (stream == null) {
      return const SizedBox(
        height: 20,
        child: Center(child: Text('...')),
      );
    }

    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snapshot) {
        // El proveedor configurado manda cuando responde bien.
        if (_isProviderResultValid(snapshot.data)) {
          return _resultBox(snapshot.data!);
        }

        // Si falla (429, 502, RateLimitException...) se arranca el motor rápido.
        if (snapshot.hasError && _fastFuture == null) {
          _ensureFastTranslation(Prefs().translateFrom, Prefs().translateTo);
        }

        // Si no, se muestra la traducción rápida (Google GTX).
        return FutureBuilder<String>(
          future: _fastFuture,
          builder: (context, fastSnapshot) {
            if (fastSnapshot.hasData &&
                fastSnapshot.data!.trim().isNotEmpty) {
              return _resultBox(fastSnapshot.data!);
            }
            if (snapshot.hasError) {
              return Text(
                '${L10n.of(context).translateError}${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }
            return const SizedBox(
              height: 20,
              child: Center(child: Text('...')),
            );
          },
        );
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
