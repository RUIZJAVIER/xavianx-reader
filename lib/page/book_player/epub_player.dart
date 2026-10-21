import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/dao/book_note.dart';
import 'package:anx_reader/enums/page_turn_mode.dart';
import 'package:anx_reader/enums/reading_info.dart';
import 'package:anx_reader/enums/translation_mode.dart';
import 'package:anx_reader/enums/writing_mode.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/models/book_style.dart';
import 'package:anx_reader/models/bookmark.dart';
import 'package:anx_reader/models/font_model.dart';
import 'package:anx_reader/models/read_theme.dart';
import 'package:anx_reader/models/reading_rules.dart';
import 'package:anx_reader/models/search_result_model.dart';
import 'package:anx_reader/models/toc_item.dart';
import 'package:anx_reader/page/book_player/image_viewer.dart';
import 'package:anx_reader/page/home_page.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/providers/book_list.dart';
import 'package:anx_reader/providers/book_toc.dart';
import 'package:anx_reader/providers/bookmark.dart';
import 'package:anx_reader/providers/chapter_content_bridge.dart';
import 'package:anx_reader/providers/current_reading.dart';
import 'package:anx_reader/service/book_player/book_player_server.dart';
import 'package:anx_reader/providers/toc_search.dart';
import 'package:anx_reader/service/ai/ai_vision_ocr_service.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/models/tts_sentence.dart';
import 'package:anx_reader/service/tts/tts_handler.dart';
import 'package:anx_reader/utils/coordinates_to_part.dart';
import 'package:anx_reader/utils/js/convert_dart_color_to_js.dart';
import 'package:anx_reader/utils/platform_utils.dart';
import 'package:anx_reader/models/book_note.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/utils/webView/epub_webview.dart';
import 'package:anx_reader/utils/webView/epub_webview_controller.dart';
import 'package:anx_reader/utils/webView/gererate_url.dart';
import 'package:anx_reader/utils/webView/page_capture.dart';
import 'package:anx_reader/utils/webView/webview_console_message.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:anx_reader/widgets/context_menu/context_menu.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/page_turning/diagram.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/page_turning/types_and_icons.dart';
import 'package:anx_reader/widgets/reading_page/style_widget.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import 'minute_clock.dart';

class EpubPlayer extends ConsumerStatefulWidget {
  final Book book;
  final String? cfi;
  final Function showOrHideAppBarAndBottomBar;
  final Function onLoadEnd;
  final List<ReadTheme> initialThemes;
  final Function updateParent;

  const EpubPlayer(
      {super.key,
      required this.showOrHideAppBarAndBottomBar,
      required this.book,
      this.cfi,
      required this.onLoadEnd,
      required this.initialThemes,
      required this.updateParent});

  @override
  ConsumerState<EpubPlayer> createState() => EpubPlayerState();
}

class EpubPlayerState extends ConsumerState<EpubPlayer>
    with TickerProviderStateMixin {
  late EpubWebViewController webViewController;
  late ContextMenu contextMenu;
  String cfi = '';
  double percentage = 0.0;
  String chapterTitle = '';
  String chapterHref = '';
  int chapterCurrentPage = 0;
  int chapterTotalPages = 0;
  OverlayEntry? contextMenuEntry;
  AnimationController? _animationController;
  Animation<double>? _animation;
  bool showHistory = false;
  bool canGoBack = false;
  bool canGoForward = false;
  late Book book;
  String? backgroundColor;
  String? textColor;
  /// Color de fondo real del tema (en los PDF difiere del color de pantalla,
  /// que es blanco: el visor lo usa para el filtro de lectura nocturna/sepia).
  String? themeBackgroundColor;
  /// True mientras una página del PDF está ampliada: desactiva el cambio de
  /// página por zonas de toque para poder explorar la página con calma.
  bool _pdfZoomed = false;
  Timer? styleTimer;
  String bookmarkCfi = '';
  bool bookmarkExists = false;
  WritingModeEnum writingMode = WritingModeEnum.horizontalTb;
  String? _lastSelectionContextText;
  bool _selectionClearLocked = false;
  bool _selectionClearPending = false;

  // --- Selección y anotaciones en PDF ---
  /// Android dispara `contextmenu` muchas veces mientras se arrastran los
  /// selectores verdes. La traducción y el menú se lanzan una sola vez, cuando
  /// la selección lleva 500 ms quieta.
  Timer? _selectionDebounce;
  int _selectionGeneration = 0;
  /// Total de páginas real del PDF (lo informa el visor).
  int _pdfTotalPages = 0;
  /// Página visible del PDF según el visor (1-based).
  int _pdfVisiblePage = 0;

  static final RegExp _pdfBookmarkCfiPattern = RegExp(r'^pdf:page=(\d+)$');
  static final RegExp _pdfNoteCfiPattern = RegExp(r'^pdf:page=(\d+):(\d+)-(\d+)$');
  static final RegExp _pdfSpineCfiPattern = RegExp(r'^epubcfi\(/6/(\d+)');

  // --- AI vision OCR (scanned / photocopied PDF pages) ---
  /// Service that turns a page screenshot into text via the user's AI config.
  final AiVisionOcrService _visionOcr = const AiVisionOcrService();
  /// Cache of OCR text keyed by page (so repeated AI/TTS calls reuse it).
  final Map<String, String> _ocrTextCache = <String, String>{};
  /// Pages whose OCR text was already handed to the TTS, to avoid loops.
  final Set<String> _ocrServedPages = <String>{};
  /// In-flight OCR request, so concurrent TTS/AI calls share one screenshot.
  Future<String>? _ocrInFlight;
  /// Minimum meaningful characters for page text to be considered readable.
  /// Below this the page is treated as a scanned/photocopied image.
  static const int _minReadableTextLength = 10;

  // Scroll wheel debounce
  Timer? _scrollDebounceTimer;
  double _accumulatedScrollDelta = 0;
  static const double _scrollThreshold = 50.0;

  // to know anytime if we are on top of navigation stack
  bool get _isTopOfNavigationStack =>
      ModalRoute.of(context)?.isCurrent ?? false;

  /// PDFs render on a white canvas like Google Drive / Acrobat, independent of
  /// the EPUB reading theme. This also avoids a dark flash while the WebView
  /// and PDF.js are still booting.
  bool get _isPdf => widget.book.fileFullPath.toLowerCase().endsWith('.pdf');

  /// True when the open book is a PDF (rendered on a canvas).
  bool get isPdf => _isPdf;

  /// Página (1-based) que representa un CFI de PDF, un marcador `pdf:page=N` o
  /// una nota `pdf:page=N:start-end`.
  int? _pdfPageFromCfi(String value) {
    if (value.isEmpty) return null;
    final bookmark = _pdfBookmarkCfiPattern.firstMatch(value);
    if (bookmark != null) return int.tryParse(bookmark.group(1)!);
    final note = _pdfNoteCfiPattern.firstMatch(value);
    if (note != null) return int.tryParse(note.group(1)!);
    // CFI sintético del renderer de página fija: epubcfi(/6/N) con N = 2*página.
    final spine = _pdfSpineCfiPattern.firstMatch(value);
    if (spine != null) {
      final index = int.tryParse(spine.group(1)!);
      if (index != null && index >= 2) return index ~/ 2;
    }
    return null;
  }

  /// Página actual del PDF (1-based).
  int get pdfCurrentPage {
    if (_pdfVisiblePage > 0) return _pdfVisiblePage;
    return _pdfPageFromCfi(cfi) ??
        (chapterCurrentPage > 0 ? chapterCurrentPage : 1);
  }

  String pdfBookmarkCfi([int? page]) => 'pdf:page=${page ?? pdfCurrentPage}';

  bool isPdfBookmarkCfi(String value) => _pdfBookmarkCfiPattern.hasMatch(value);

  bool isPdfNoteCfi(String value) => value.startsWith('pdf:page=');

  /// Progreso (0..1) de una página de PDF; la última hoja llega al 100%.
  double _pdfPagePercentage(int page) {
    final total = _pdfTotalPages > 0 ? _pdfTotalPages : chapterTotalPages;
    if (total <= 1) return 0.0;
    return ((page - 1) / (total - 1)).clamp(0.0, 1.0).toDouble();
  }

  void prevPage() {
    webViewController.execute('''
      if (typeof clearSelection === 'function') { clearSelection(); }
      prevPage();
      ''');
  }

  void nextPage() {
    webViewController.execute('''
      if (typeof clearSelection === 'function') { clearSelection(); }
      nextPage();
      ''');
  }

  void prevChapter() {
    webViewController.execute('''
      prevSection()
      ''');
  }

  void nextChapter() {
    webViewController.execute('''
      nextSection()
      ''');
  }

  void setTranslationMode(TranslationModeEnum mode) {
    webViewController.execute('''
      if (typeof reader !== 'undefined' && typeof reader.view !== 'undefined' && reader.view.setTranslationMode) {
        reader.view.setTranslationMode('${mode.code}');
      }
      ''');
  }

  Future<void> goToPercentage(double value) async {
    await webViewController.execute('''
      goToPercent($value); 
      ''');
  }

  void setSelectionClearLocked(bool locked) {
    _selectionClearLocked = locked;
    if (!locked && _selectionClearPending) {
      _selectionClearPending = false;
      _lastSelectionContextText = null;
      removeOverlay();
      restoreReaderFocus();
    }
  }

  void restoreReaderFocus() {
    // CEF may still hold GTK/browser focus after a page click dismissed the
    // menu; release it so arrow keys reach Flutter again.
    webViewController.setBrowserFocus(false);
    webViewController.execute(
      "try { window.__anxResetClickSuppress && window.__anxResetClickSuppress(); } catch (_) {}",
    );
    readingPageKey.currentState?.requestReaderFocus();
  }

  void changeTheme(ReadTheme readTheme) {
    textColor = readTheme.textColor;
    themeBackgroundColor = readTheme.backgroundColor;
    backgroundColor = _isPdf ? 'FFFFFF' : readTheme.backgroundColor;

    // En los PDF la página se muestra siempre sobre blanco, pero el color real
    // del tema se envía al visor para que aplique el filtro de lectura
    // nocturna/sepia al canvas (los píxeles que se envían a la IA no cambian).
    String bc =
        convertDartColorToJs(_isPdf ? themeBackgroundColor! : backgroundColor!);
    String tc = convertDartColorToJs(readTheme.textColor);

    webViewController.execute('''
      changeStyle({
        backgroundColor: '#$bc',
        fontColor: '#$tc',
      })
      ''');
  }

  void changeStyle(BookStyle? bookStyle) {
    styleTimer?.cancel();
    String bgimgUrl = Prefs().bgimg.getEffectiveUrl(
          isDarkMode: isDarkMode,
          autoAdjust: Prefs().autoAdjustReadingTheme,
        );

    styleTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      BookStyle style = bookStyle ?? Prefs().bookStyle;
      webViewController.execute('''
      changeStyle({
        fontSize: ${style.fontSize},
        spacing: ${style.lineHeight},
        fontWeight: ${style.fontWeight},
        paragraphSpacing: ${style.paragraphSpacing},
        topMargin: ${style.topMargin},
        bottomMargin: ${style.bottomMargin},
        sideMargin: ${style.sideMargin},
        letterSpacing: ${style.letterSpacing},
        textIndent: ${style.indent},
        maxColumnCount: ${style.maxColumnCount},
        columnThreshold: ${style.columnThreshold},
        writingMode: '${Prefs().writingMode.code}',
        textAlign: '${Prefs().textAlignment.code}',
        backgroundImage: '$bgimgUrl',
        bgimgBlur: ${Prefs().bgimg.blur},
        bgimgOpacity: ${Prefs().bgimg.opacity},
        bgimgFit: '${Prefs().bgimgFit.code}',
        customCSS: `${Prefs().customCSS.replaceAll('`', '\\`')}`,
        customCSSEnabled: ${Prefs().customCSSEnabled},
        useBookStyles: ${Prefs().useBookStyles},
        headingFontSize: ${style.headingFontSize},
        codeHighlightTheme: '${Prefs().codeHighlightTheme.code}',
      })
      ''');
    });
  }

  void changeBgimgEffect() {
    if (!mounted) return;
    final bgimg = Prefs().bgimg;
    final bgimgUrl = bgimg.getEffectiveUrl(
      isDarkMode: isDarkMode,
      autoAdjust: Prefs().autoAdjustReadingTheme,
    );
    webViewController.execute('''
      changeStyle({
        backgroundImage: '$bgimgUrl',
        bgimgBlur: ${bgimg.blur},
        bgimgOpacity: ${bgimg.opacity},
        bgimgFit: '${Prefs().bgimgFit.code}',
      })
    ''');
  }

  void changeReadingRules(ReadingRules readingRules) {
    webViewController.execute('''
      readingFeatures({
        convertChineseMode: '${readingRules.convertChineseMode.name}',
        bionicReadingMode: ${readingRules.bionicReading},
      })
    ''');
  }

  void changeFont(FontModel font) {
    webViewController.execute('''
      changeStyle({
        fontName: '${font.name}',
        fontPath: '${font.path}',
      })
    ''');
  }

  void changePageTurnStyle(PageTurn pageTurnStyle) {
    webViewController.execute('''
      changeStyle({
        pageTurnStyle: '${pageTurnStyle.name}',
      })
    ''');
  }

  void goToHref(String href) => webViewController.execute("goToHref('$href')");

  void goToCfi(String cfi) {
    // Marcadores y notas de PDF: el CFI sintético sólo codifica la página.
    final pdfPage = _isPdf ? _pdfPageFromCfi(cfi) : null;
    if (pdfPage != null) {
      goToPage(pdfPage);
      return;
    }
    webViewController.execute("goToCfi('$cfi')");
  }

  /// Salta a una página concreta de un PDF (1-based).
  void goToPage(int page) {
    final total = _pdfTotalPages > 0 ? _pdfTotalPages : chapterTotalPages;
    final target = (total > 0 ? page.clamp(1, total) : page).toInt();
    _pdfVisiblePage = target;
    webViewController.execute("goToHref('${target - 1}')");
  }

  void addAnnotation(BookNote bookNote) {
    // Los subrayados de PDF los pinta pdf.js sobre el canvas a partir de la
    // lista de notas; no se envían al overlayer de CFI.
    if (_isPdf && isPdfNoteCfi(bookNote.cfi)) {
      _pushPdfHighlightsSoon();
      return;
    }
    final noteContent =
        (bookNote.content).replaceAll('\n', ' ').replaceAll("'", "\\'");
    webViewController.execute('''
      addAnnotation({
        id: ${bookNote.id},
        type: '${bookNote.type}',
        value: '${bookNote.cfi}',
        color: '#${bookNote.color}',
        note: '$noteContent',
      })
      ''');
  }

  void addBookmark(BookmarkModel bookmark) {
    if (_isPdf) {
      // Los marcadores de PDF viven sólo en la base de datos.
      _refreshPdfBookmarkState();
      return;
    }
    webViewController.execute('''
      addAnnotation({
        id: ${bookmark.id},
        type: 'bookmark',
        value: '${bookmark.cfi}',
        color: '#000000',
        note: 'None',
      })
      ''');
  }

  void addBookmarkHere() {
    webViewController.execute('''
      addBookmarkHere()
      ''');
  }

  /// Alterna el marcador de la página actual.
  ///
  /// En EPUB se delega al visor (gesto/JS). En PDF se guarda en la base de
  /// datos con un CFI sintético `pdf:page=N`, porque el visor de página fija
  /// no expone un rango de texto para el marcador.
  Future<void> toggleBookmarkHere() async {
    if (!_isPdf) {
      if (bookmarkExists) {
        removeAnnotation(bookmarkCfi);
      } else {
        addBookmarkHere();
      }
      return;
    }

    final page = pdfCurrentPage;
    final cfi = pdfBookmarkCfi(page);
    final notifier = ref.read(BookmarkProvider(book.id).notifier);
    try {
      final bookmarks = await ref.read(BookmarkProvider(book.id).future);
      final existing = bookmarks.where((b) => b.cfi == cfi).toList();
      if (existing.isNotEmpty) {
        notifier.removeBookmark(cfi: cfi);
        bookmarkCfi = '';
        bookmarkExists = false;
      } else {
        final now = DateTime.now();
        await notifier.addBookmark(BookmarkModel(
          bookId: book.id,
          content: 'Page $page',
          cfi: cfi,
          chapter: 'Page $page',
          percentage: percentage,
          createTime: now,
          updateTime: now,
        ));
        bookmarkCfi = cfi;
        bookmarkExists = true;
      }
      if (!mounted) return;
      setState(() {});
      widget.updateParent();
    } catch (e) {
      AnxLog.warning('toggleBookmarkHere (PDF) failed: $e');
    }
  }

  /// Mantiene el icono de marcador sincronizado con la página actual del PDF.
  Future<void> _refreshPdfBookmarkState() async {
    if (!_isPdf || !mounted) return;
    final cfi = pdfBookmarkCfi();
    try {
      final bookmarks = await ref.read(BookmarkProvider(book.id).future);
      final exists = bookmarks.any((b) => b.cfi == cfi);
      if (!mounted) return;
      if (exists == bookmarkExists && (!exists || bookmarkCfi == cfi)) return;
      setState(() {
        bookmarkExists = exists;
        bookmarkCfi = exists ? cfi : '';
      });
      widget.updateParent();
    } catch (e) {
      AnxLog.warning('PDF bookmark state failed: $e');
    }
  }

  void removeAnnotation(String cfi) {
    if (isPdfNoteCfi(cfi)) {
      // Marcador de PDF: se actualiza el icono al instante.
      if (isPdfBookmarkCfi(cfi) && bookmarkCfi == cfi) {
        bookmarkExists = false;
        bookmarkCfi = '';
        if (mounted) setState(() {});
        widget.updateParent();
      }
      _pushPdfHighlightsSoon();
      return;
    }
    webViewController.execute("removeAnnotation('$cfi')");
  }

  /// Envía a pdf.js los subrayados guardados de este libro para que los pinte
  /// sobre cada página.
  Future<void> _pushPdfHighlights() async {
    if (!_isPdf) return;
    try {
      final notes = await bookNoteDao.selectBookNotesByBookId(book.id);
      final payload = <Map<String, dynamic>>[];
      for (final note in notes) {
        if (note.type == 'bookmark') continue;
        final match = _pdfNoteCfiPattern.firstMatch(note.cfi);
        if (match == null) continue;
        final page = int.tryParse(match.group(1) ?? '');
        final start = int.tryParse(match.group(2) ?? '');
        final end = int.tryParse(match.group(3) ?? '');
        if (page == null || start == null || end == null || end <= start) {
          continue;
        }
        payload.add({
          'id': note.id,
          'page': page,
          'start': start,
          'end': end,
          'color': note.color,
          'type': note.type,
          'note': note.readerNote ?? '',
        });
      }
      await webViewController
          .execute('window.setPdfHighlights(${jsonEncode(payload)})');
    } catch (e) {
      AnxLog.warning('PDF highlights sync failed: $e');
    }
  }

  /// Reintenta la sincronización tras un borrado (la fila se elimina sin
  /// esperar en la UI, así que se da un margen antes de releer la base).
  void _pushPdfHighlightsSoon() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _pushPdfHighlights();
    });
  }

  void clearSearch() {
    ref.read(tocSearchProvider.notifier).clear();
    _clearSearchHighlights();
  }

  void search(String text) {
    final sanitized = text.trim();
    if (sanitized.isEmpty) {
      clearSearch();
      return;
    }
    _clearSearchHighlights();
    ref.read(tocSearchProvider.notifier).start(sanitized);
    webViewController.execute('''
      search('$sanitized', {
        'scope': 'book',
        'matchCase': false,
        'matchDiacritics': false,
        'matchWholeWords': false,
      })
    ''');
  }

  Future<void> runAiBookSearch(String keyword) async {
    ref.read(tocSearchProvider.notifier).start(keyword);
    final escaped = jsonEncode(keyword);
    await webViewController.execute('clearSearch()');
    await webViewController.execute(
        'search($escaped, {"scope":"book","matchCase":false,"matchDiacritics":false,"matchWholeWords":false})');
  }

  void _clearSearchHighlights() {
    webViewController.execute("clearSearch()");
  }

  // --- AI vision OCR (scanned / photocopied PDF pages) -----------------------

  /// Stable key identifying the currently visible page.
  String get _currentPageKey =>
      cfi.isNotEmpty ? cfi : '$chapterHref#$chapterCurrentPage';

  /// Number of meaningful (letter/digit) characters in [text].
  int _meaningfulLength(String text) =>
      text.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').length;

  /// True when [text] carries no usable characters (empty or symbols only).
  bool _isTextUnusable(String text) => _meaningfulLength(text) == 0;

  /// Capture the visible page and run AI vision OCR on it.
  ///
  /// Results are cached per page and concurrent callers share one request.
  Future<String> _ocrVisiblePage() {
    final existing = _ocrInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _runVisionOcr();
    _ocrInFlight = future;
    return future.whenComplete(() {
      _ocrInFlight = null;
    });
  }

  Future<String> _runVisionOcr() async {
    final pageKey = _currentPageKey;
    final cached = _ocrTextCache[pageKey];
    if (cached != null) {
      return cached;
    }

    try {
      final Uint8List? bytes = await captureVisiblePage(webViewController);
      if (bytes == null || bytes.isEmpty) {
        return '';
      }
      final result = await _visionOcr.extractText(bytes);
      if (!result.success || result.text.isEmpty) {
        if (result.error != null) {
          AnxLog.warning('Vision OCR failed: ${result.error}');
        }
        return '';
      }
      _ocrTextCache[pageKey] = result.text;
      AnxLog.info(
          'Vision OCR extracted ${result.text.length} chars for page $pageKey');
      return result.text;
    } catch (e) {
      AnxLog.severe('Vision OCR error: $e');
      return '';
    }
  }

  /// Returns [jsText] unless it has no real text layer, in which case it falls
  /// back to AI vision OCR of the visible page (served at most once per page).
  Future<String> _ttsTextOrOcr(String jsText) async {
    if (!_isTextUnusable(jsText)) {
      return jsText;
    }

    final pageKey = _currentPageKey;
    if (_ocrServedPages.contains(pageKey)) {
      // Already narrated this scanned page; don't loop forever.
      return jsText;
    }

    final ocrText = await _ocrVisiblePage();
    if (ocrText.isEmpty) {
      return jsText;
    }
    _ocrServedPages.add(pageKey);
    return ocrText;
  }

  Future<void> initTts({String? fromCfi}) async {
    // En PDF el CFI sintético (pdf:page=N...) no se puede resolver a un rango
    // de texto: se narra desde la posición actual del visor.
    final usableCfi = (fromCfi != null &&
            fromCfi.isNotEmpty &&
            !isPdfNoteCfi(fromCfi))
        ? fromCfi
        : null;
    if (usableCfi != null) {
      await webViewController.execute("window.ttsFromCfi('$usableCfi')");
    } else {
      await webViewController.execute("window.ttsHere()");
    }
  }

  void ttsStop() => webViewController.execute("ttsStop()");

  Future<String> ttsNext() async {
    final js = _jsString(
      await webViewController.callAsyncJavaScript(
        functionBody: "return await ttsNext()",
      ),
    );
    return _ttsTextOrOcr(js);
  }

  Future<String> ttsPrev() async {
    final js = _jsString(
      await webViewController.callAsyncJavaScript(
        functionBody: "return await ttsPrev()",
      ),
    );
    return _ttsTextOrOcr(js);
  }

  Future<String> ttsPrevSection() async {
    final js = _jsString(
      await webViewController.callAsyncJavaScript(
        functionBody: "return await ttsPrevSection()",
      ),
    );
    return _ttsTextOrOcr(js);
  }

  Future<String> ttsNextSection() async {
    final js = _jsString(
      await webViewController.callAsyncJavaScript(
        functionBody: "return await ttsNextSection()",
      ),
    );
    return _ttsTextOrOcr(js);
  }

  Future<String> ttsPrepare() async {
    final js =
        (await webViewController.evaluate("ttsPrepare()"))?.toString() ?? '';
    return _ttsTextOrOcr(js);
  }

  TtsSentence? _parseTtsSentence(dynamic value) {
    if (value is Map<dynamic, dynamic>) {
      try {
        return TtsSentence.fromMap(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<TtsSentence> _parseTtsSentences(dynamic value) {
    if (value is! List) return const [];

    final sentences = <TtsSentence>[];
    for (final item in value) {
      final sentence = _parseTtsSentence(item);
      if (sentence != null) {
        sentences.add(sentence);
      }
    }
    return sentences;
  }

  Future<TtsSentence?> ttsCurrentDetail() async {
    final result = await webViewController.callAsyncJavaScript(
      functionBody: 'return ttsCurrentDetail()',
    );
    return _parseTtsSentence(result.value);
  }

  Future<List<TtsSentence>> ttsCollectDetails({
    required int count,
    bool includeCurrent = false,
    int offset = 1,
  }) async {
    final result = await webViewController.callAsyncJavaScript(
      functionBody:
          'return ttsCollectDetails($count, ${includeCurrent ? 'true' : 'false'}, $offset)',
    );
    final sentences = _parseTtsSentences(result.value);
    if (sentences.isNotEmpty) {
      return sentences;
    }

    // Scanned / photocopied page: the reader exposes no sentences, so fall
    // back to AI vision OCR of the visible page (once per page).
    final pageKey = _currentPageKey;
    if (_ocrServedPages.contains(pageKey)) {
      return sentences;
    }
    final ocrText = await _ocrVisiblePage();
    if (ocrText.isEmpty) {
      return sentences;
    }
    _ocrServedPages.add(pageKey);
    return <TtsSentence>[
      TtsSentence(text: ocrText, cfi: cfi.isNotEmpty ? cfi : null),
    ];
  }

  String _jsString(EpubJavaScriptResult result) =>
      result.value?.toString() ?? '';

  Future<void> ttsHighlightByCfi(String cfi) async {
    await webViewController.callAsyncJavaScript(
      functionBody: 'return ttsHighlightByCfi(${jsonEncode(cfi)})',
    );
  }

  Future<bool> isFootNoteOpen() async =>
      (await webViewController.evaluate("window.isFootNoteOpen()"));

  void backHistory() {
    webViewController.execute("back()");
  }

  void forwardHistory() {
    webViewController.execute("forward()");
  }

  void refreshToc() {
    webViewController.execute("refreshToc()");
  }

  Future<String> theChapterContent() async =>
      (await webViewController.evaluate("theChapterContent()")).toString();

  Future<String> previousContent(int count) async =>
      (await webViewController.evaluate("previousContent($count)")).toString();

  Future<String> _getCurrentChapterContent({int? maxCharacters}) async {
    final raw = await theChapterContent();
    final content = _normalizeChapterContent(raw, maxCharacters);
    if (_meaningfulLength(content) >= _minReadableTextLength) {
      return content;
    }

    // No usable text layer (scanned / photocopied PDF): fall back to AI vision
    // OCR of the currently visible page so the AI assistant still gets content.
    final ocrText = await _ocrVisiblePage();
    if (ocrText.isEmpty) {
      return content;
    }
    return _normalizeChapterContent(ocrText, maxCharacters);
  }

  Future<String> _getChapterContentByHref(
    String href, {
    int? maxCharacters,
  }) async {
    if (href.isEmpty) {
      return '';
    }

    final result = await webViewController.callAsyncJavaScript(
      functionBody:
          'return await getChapterContentByHref("${href.replaceAll('"', '\\"')}")',
    );

    final value = result.value;
    if (value is String) {
      return _normalizeChapterContent(value, maxCharacters);
    }
    return '';
  }

  String _normalizeChapterContent(String? content, int? maxCharacters) {
    if (content == null || content.isEmpty) {
      return '';
    }
    final trimmed = content.trim();
    if (maxCharacters != null &&
        maxCharacters > 0 &&
        trimmed.length > maxCharacters) {
      return trimmed.substring(0, maxCharacters);
    }
    return trimmed;
  }

  void _registerChapterContentBridge() {
    ref.read(chapterContentBridgeProvider.notifier).state =
        ChapterContentHandlers(
      fetchCurrentChapter: ({int? maxCharacters}) =>
          _getCurrentChapterContent(maxCharacters: maxCharacters),
      fetchChapterByHref: (href, {int? maxCharacters}) =>
          _getChapterContentByHref(href, maxCharacters: maxCharacters),
    );
  }

  Future<void> _handleExternalLink(dynamic rawLink) async {
    String? normalizeExternalLink(dynamic raw) {
      if (raw == null) {
        return null;
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      if (raw is Map && raw['href'] is String) {
        final href = raw['href'].toString().trim();
        return href.isEmpty ? null : href;
      }
      return null;
    }

    final link = normalizeExternalLink(rawLink);
    if (!mounted || link == null) {
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme.isEmpty || uri.scheme == 'javascript') {
      AnxLog.warning('Ignored invalid external link: $link');
      return;
    }

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = L10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.readingPageOpenExternalLinkTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.readingPageOpenExternalLinkMessage),
              const SizedBox(height: 8),
              SelectableText(link),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.readingPageOpenExternalLinkAction),
            ),
          ],
        );
      },
    );

    if (shouldOpen != true) {
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      AnxLog.warning('Failed to open external link: $link');
    }
  }

  void onClick(Map<String, dynamic> location) {
    readingPageKey.currentState?.resetAwakeTimer();
    if (contextMenuEntry != null) {
      removeOverlay();
      return;
    }
    final x = location['x'];
    final y = location['y'];
    final part = coordinatesToPart(x, y);

    PageTurningType action;
    final pageTurnMode = PageTurnMode.fromCode(Prefs().pageTurnMode);

    if (pageTurnMode == PageTurnMode.simple) {
      // Use predefined page turning types
      final currentPageTurningType = Prefs().pageTurningType;
      final pageTurningType = pageTurningTypes[currentPageTurningType];
      action = pageTurningType[part];

      // Apply swap if enabled
      if (Prefs().swapPageTurnArea) {
        if (action == PageTurningType.prev) {
          action = PageTurningType.next;
        } else if (action == PageTurningType.next) {
          action = PageTurningType.prev;
        }
      }
    } else {
      // Use custom configuration
      final customConfig = Prefs().customPageTurnConfig;
      action = PageTurningType.values[customConfig[part]];
    }

    // Disable mouse/touch page turning when keyboard shortcuts are enabled
    if (Prefs().keyboardShortcutTurnPage) {
      // Only allow menu action, disable prev/next page turning
      if (action == PageTurningType.prev || action == PageTurningType.next) {
        return;
      }
    }

    // Con la página del PDF ampliada no se cambia de página: el usuario
    // explora la zona ampliada sin que un toque accidental salte de hoja.
    if (_isPdf && _pdfZoomed) {
      if (action == PageTurningType.prev || action == PageTurningType.next) {
        return;
      }
    }

    switch (action) {
      case PageTurningType.prev:
        prevPage();
        break;
      case PageTurningType.next:
        nextPage();
        break;
      case PageTurningType.menu:
        widget.showOrHideAppBarAndBottomBar(true);
        break;
      case PageTurningType.none:
        break;
    }
  }

  /// CFI sintético para una selección de PDF: `pdf:page=N:start-end`, donde
  /// los desplazamientos son índices de caracteres en la capa de texto.
  String _pdfSelectionCfi(Map<String, dynamic> location) {
    final page = (location['pdfPage'] as num?)?.toInt() ?? pdfCurrentPage;
    final start = (location['startOffset'] as num?)?.toInt();
    final end = (location['endOffset'] as num?)?.toInt();
    if (start != null && end != null && end > start) {
      return 'pdf:page=$page:$start-$end';
    }
    return 'pdf:page=$page';
  }

  /// Abre el menú de selección/traducción una vez que la selección se detuvo.
  void _handleSelectionEnd(Map<String, dynamic> location) {
    if (!mounted) return;
    removeOverlay();
    final text = location['text']?.toString() ?? '';
    if (text.trim().isEmpty) return;
    var cfi = location['cfi']?.toString() ?? '';
    if (_isPdf) {
      cfi = _pdfSelectionCfi(location);
      final page = _pdfPageFromCfi(cfi) ?? pdfCurrentPage;
      chapterCurrentPage = page;
      _pdfVisiblePage = page;
      chapterTitle = 'Page $page';
    }
    // En PDF la selección también debe ofrecer subrayar/resaltar (el menú de
    // anotaciones se oculta cuando `footnote` es true).
    final footnote = _isPdf ? false : (location['footnote'] == true);
    final rawContextText = location['contextText']?.toString();
    _lastSelectionContextText =
        (rawContextText?.trim().isEmpty ?? true) ? null : rawContextText;
    final pos = location['pos'];
    if (pos is! Map) return;
    final left = (pos['left'] as num?)?.toDouble() ?? 0;
    final top = (pos['top'] as num?)?.toDouble() ?? 0;
    final right = (pos['right'] as num?)?.toDouble() ?? 0;
    final bottom = (pos['bottom'] as num?)?.toDouble() ?? 0;
    showContextMenu(
      context,
      left,
      top,
      right,
      bottom,
      text,
      cfi,
      null,
      footnote,
      writingMode.isVertical ? Axis.vertical : Axis.horizontal,
      contextText: _lastSelectionContextText,
    );
  }

  Future<void> renderAnnotations(EpubWebViewController controller) async {
    List<BookNote> annotationList =
        await bookNoteDao.selectBookNotesByBookId(widget.book.id);
    // Los subrayados de PDF usan `pdf:page=N:start-end` y los pinta pdf.js
    // sobre el canvas: no son CFI válidos para el overlayer del EPUB.
    final cfiAnnotations = _isPdf
        ? annotationList.where((e) => !isPdfNoteCfi(e.cfi)).toList()
        : annotationList;
    String allAnnotations =
        jsonEncode(cfiAnnotations.map((e) => e.toJson()).toList())
            .replaceAll('\'', '\\\'');
    controller.execute('''
     const allAnnotations = $allAnnotations
     renderAnnotations()
    ''');
    if (_isPdf) {
      await _pushPdfHighlights();
    }
  }

  void getThemeColor() {
    if (Prefs().autoAdjustReadingTheme) {
      List<ReadTheme> themes = widget.initialThemes;
      final isDayMode =
          Theme.of(navigatorKey.currentContext!).brightness == Brightness.light;
      backgroundColor =
          isDayMode ? themes[0].backgroundColor : themes[1].backgroundColor;
      textColor = isDayMode ? themes[0].textColor : themes[1].textColor;
    } else {
      backgroundColor = Prefs().readTheme.backgroundColor;
      textColor = Prefs().readTheme.textColor;
    }
    themeBackgroundColor = backgroundColor;
    // PDF pages are always white, even with a dark EPUB theme.
    if (_isPdf) {
      backgroundColor = 'FFFFFF';
    }
  }

  Future<void> setHandler(EpubWebViewController controller) async {
    controller.addJavaScriptHandler(
        handlerName: 'onLoadEnd',
        callback: (args) {
          widget.onLoadEnd();
        });

    controller.addJavaScriptHandler(
        handlerName: 'onRelocated',
        callback: (args) {
          final raw = args.isNotEmpty ? args.first : null;
          if (raw is! Map) return;
          Map<String, dynamic> location = Map<String, dynamic>.from(raw);
          final nextCfi = location['cfi']?.toString() ?? '';
          // En PDF el CFI es sintético (cambia con la página), pero el
          // encabezado/pie deben refrescarse siempre: no se descarta el evento
          // aunque el CFI se repita.
          if (!_isPdf && nextCfi == cfi) return;
          final pdfPage = _isPdf ? _pdfPageFromCfi(nextCfi) : null;
          setState(() {
            cfi = nextCfi;
            if (_isPdf) {
              final reportedTotal =
                  (location['chapterTotalPages'] as num?)?.toInt() ?? 0;
              if (reportedTotal > 0) _pdfTotalPages = reportedTotal;
              final reportedPage =
                  (location['chapterCurrentPage'] as num?)?.toInt() ?? 0;
              final page = pdfPage ??
                  (reportedPage > 0 ? reportedPage : chapterCurrentPage);
              chapterCurrentPage = page > 0 ? page : 1;
              _pdfVisiblePage = chapterCurrentPage;
              chapterTotalPages =
                  _pdfTotalPages > 0 ? _pdfTotalPages : reportedTotal;
              chapterTitle = 'Page $chapterCurrentPage';
              chapterHref = location['chapterHref']?.toString() ?? chapterHref;
              percentage = _pdfPagePercentage(chapterCurrentPage);
              // El estado del marcador lo calcula Dart (pdf:page=N).
            } else {
              percentage =
                  double.tryParse(location['percentage'].toString()) ?? 0.0;
              chapterTitle = location['chapterTitle'] ?? '';
              chapterHref = location['chapterHref'] ?? '';
              chapterCurrentPage = location['chapterCurrentPage'] ?? 0;
              chapterTotalPages = location['chapterTotalPages'] ?? 0;
              final bookmark = location['bookmark'];
              if (bookmark is Map) {
                bookmarkExists = bookmark['exists'] ?? false;
                bookmarkCfi = bookmark['cfi'] ?? '';
              }
            }
            writingMode =
                WritingModeEnum.fromCode(location['writingMode'] ?? '');
          });
          ref.read(currentReadingProvider.notifier).update(
                cfi: cfi,
                percentage: percentage,
                chapterTitle: chapterTitle,
                chapterHref: chapterHref,
                chapterCurrentPage: chapterCurrentPage,
                chapterTotalPages: chapterTotalPages,
              );
          widget.updateParent();
          saveReadingProgress();
          readingPageKey.currentState?.resetAwakeTimer();
          if (_isPdf) _refreshPdfBookmarkState();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onPdfPageChanged',
        callback: (args) {
          if (!_isPdf) return;
          final raw = args.isNotEmpty ? args.first : null;
          if (raw is! Map) return;
          final payload = Map<String, dynamic>.from(raw);
          final page = (payload['page'] as num?)?.toInt() ?? 0;
          final total = (payload['total'] as num?)?.toInt() ?? 0;
          if (page <= 0) return;
          if (total > 0) _pdfTotalPages = total;
          if (page == chapterCurrentPage && total == chapterTotalPages) return;
          setState(() {
            chapterCurrentPage = page;
            _pdfVisiblePage = page;
            if (_pdfTotalPages > 0) chapterTotalPages = _pdfTotalPages;
            chapterTitle = 'Page $page';
            percentage = _pdfPagePercentage(page);
          });
          ref.read(currentReadingProvider.notifier).update(
                cfi: cfi,
                percentage: percentage,
                chapterTitle: chapterTitle,
                chapterHref: chapterHref,
                chapterCurrentPage: chapterCurrentPage,
                chapterTotalPages: chapterTotalPages,
              );
          widget.updateParent();
          _refreshPdfBookmarkState();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onClick',
        callback: (args) {
          Map<String, dynamic> location = args[0];
          onClick(location);
        });
    controller.addJavaScriptHandler(
        handlerName: 'onPdfZoom',
        callback: (args) {
          final payload = args.isNotEmpty ? args.first : null;
          final zoomed =
              payload is Map ? payload['zoomed'] == true : false;
          if (zoomed == _pdfZoomed) return;
          setState(() {
            _pdfZoomed = zoomed;
          });
        });
    controller.addJavaScriptHandler(
      handlerName: 'onExternalLink',
      callback: (args) async {
        final payload = args.isNotEmpty ? args.first : null;
        await _handleExternalLink(payload);
      },
    );
    controller.addJavaScriptHandler(
        handlerName: 'onSetToc',
        callback: (args) {
          List<dynamic> t = args[0];
          final toc = t.map((i) => TocItem.fromJson(i)).toList();
          ref.read(bookTocProvider.notifier).setToc(toc);
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSelectionEnd',
        callback: (args) {
          final raw = args.isNotEmpty ? args.first : null;
          if (raw is! Map) return;
          final location = Map<String, dynamic>.from(raw);
          // Se espera a que la selección esté quieta: mientras se arrastran
          // los selectores verdes, Android dispara decenas de eventos y la
          // traducción se quedaba colgada en "...".
          _selectionDebounce?.cancel();
          final generation = ++_selectionGeneration;
          _selectionDebounce =
              Timer(const Duration(milliseconds: 500), () {
            if (!mounted || generation != _selectionGeneration) return;
            _handleSelectionEnd(location);
          });
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSelectionCleared',
        callback: (args) {
          // Cancela el menú/traducción pendiente de una selección descartada.
          _selectionDebounce?.cancel();
          _selectionGeneration++;
          if (_selectionClearLocked) {
            _selectionClearPending = true;
            return;
          }
          _lastSelectionContextText = null;
          removeOverlay();
          restoreReaderFocus();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onAnnotationClick',
        callback: (args) {
          Map<String, dynamic> annotation = args[0];

          if (annotation['annotation'] == null) {
            // Check if TTS is active and the click is on the currently read text
            final currentTtsState = TtsHandler().ttsStateNotifier.value;
            if (currentTtsState == TtsStateEnum.playing ||
                currentTtsState == TtsStateEnum.paused) {
              if (currentTtsState == TtsStateEnum.playing) {
                audioHandler.pause();
              } else {
                audioHandler.play();
              }
              return;
            }
          }

          int id = annotation['annotation']['id'];
          String cfi = annotation['annotation']['value'];
          String note = annotation['annotation']['note'];
          final rawContextText = annotation['contextText']?.toString();
          _lastSelectionContextText =
              (rawContextText?.trim().isEmpty ?? true) ? null : rawContextText;
          double left = (annotation['pos']['left'] as num).toDouble();
          double top = (annotation['pos']['top'] as num).toDouble();
          double right = (annotation['pos']['right'] as num).toDouble();
          double bottom = (annotation['pos']['bottom'] as num).toDouble();
          showContextMenu(
            context,
            left,
            top,
            right,
            bottom,
            note,
            cfi,
            id,
            false,
            writingMode.isVertical ? Axis.vertical : Axis.horizontal,
            contextText: _lastSelectionContextText,
          );
        });
    controller.addJavaScriptHandler(
      handlerName: 'onSearch',
      callback: (args) {
        Map<String, dynamic> search = args[0];
        setState(() {
          final tocSearch = ref.read(tocSearchProvider.notifier);
          if (search['process'] != null) {
            final progress = search['process'].toDouble();
            tocSearch.updateProgress(progress);
          } else {
            tocSearch.addResult(SearchResultModel.fromJson(search));
          }
        });
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'renderAnnotations',
      callback: (args) {
        renderAnnotations(controller);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPushState',
      callback: (args) {
        Map<String, dynamic> state = args[0];
        if (!mounted) return;
        setState(() {
          canGoBack = state['canGoBack'];
          canGoForward = state['canGoForward'];
          showHistory = canGoBack || canGoForward;
        });
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onImageClick',
      callback: (args) {
        String image = args[0];
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ImageViewer(
                      image: image,
                      bookName: widget.book.title,
                    )));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onFootnoteClose',
      callback: (args) {
        removeOverlay();
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPullUp',
      callback: (args) {
        widget.showOrHideAppBarAndBottomBar(true);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'handleBookmark',
      callback: (args) async {
        Map<String, dynamic> detail = args[0]['detail'];
        bool remove = args[0]['remove'];
        String cfi = detail['cfi'] ?? '';
        double percentage =
            double.tryParse(detail['percentage'].toString()) ?? 0.0;
        String content = detail['content']?.toString() ?? '';

        // El gesto de la esquina en un PDF no tiene CFI de texto: se guarda el
        // marcador sintético de la página actual.
        if (_isPdf) {
          final page = _pdfPageFromCfi(cfi) ?? pdfCurrentPage;
          cfi = pdfBookmarkCfi(page);
          if (content.trim().isEmpty) content = 'Page $page';
          percentage = _pdfPagePercentage(page);
        }

        if (remove) {
          ref.read(bookmarkProvider(widget.book.id).notifier).removeBookmark(
                cfi: cfi,
              );
          bookmarkCfi = '';
          bookmarkExists = false;
        } else {
          BookmarkModel bookmark = await ref
              .read(BookmarkProvider(widget.book.id).notifier)
              .addBookmark(
                BookmarkModel(
                  bookId: widget.book.id,
                  cfi: cfi,
                  percentage: percentage,
                  content: content,
                  chapter: chapterTitle,
                  updateTime: DateTime.now(),
                  createTime: DateTime.now(),
                ),
              );
          bookmarkCfi = cfi;
          bookmarkExists = true;
          addBookmark(bookmark);
        }
        widget.updateParent();
        setState(() {});
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'translateText',
      callback: (args) async {
        try {
          String text = args[0];
          final service = Prefs().fullTextTranslateService;
          final from = Prefs().fullTextTranslateFrom;
          final to = Prefs().fullTextTranslateTo;

          return await service.provider
              .translateTextOnly(text, from, to, isFullText: true);
        } catch (e) {
          AnxLog.severe('Translation error: $e');
          return 'Translation error: $e';
        }
      },
    );
  }

  Future<void> onWebViewCreated(EpubWebViewController controller) async {
    if (AnxPlatform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
    webViewController = controller;
    setHandler(controller);
    _registerChapterContentBridge();

    // Initialize translation mode based on book-specific settings
    Future.delayed(const Duration(milliseconds: 300), () {
      setTranslationMode(Prefs().getBookTranslationMode(widget.book.id));
    });
  }

  void removeOverlay() {
    _selectionClearLocked = false;
    _selectionClearPending = false;
    if (contextMenuEntry == null || contextMenuEntry?.mounted == false) return;
    contextMenuEntry?.remove();
    contextMenuEntry = null;
  }

  Future<void> _handlePointerEvents(PointerEvent event) async {
    if (await isFootNoteOpen() || Prefs().pageTurnStyle == PageTurn.scroll) {
      return;
    }
    // Disable scroll wheel page turning when keyboard shortcuts are enabled
    if (Prefs().keyboardShortcutTurnPage) {
      return;
    }
    if (event is PointerScrollEvent) {
      _accumulatedScrollDelta += event.scrollDelta.dy;

      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 80), () {
        if (_accumulatedScrollDelta.abs() >= _scrollThreshold) {
          if (_accumulatedScrollDelta > 0) {
            nextPage();
          } else {
            prevPage();
          }
        }
        _accumulatedScrollDelta = 0;
      });
    }
  }

  @override
  void initState() {
    book = widget.book;
    getThemeColor();

    contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      onCreateContextMenu: (hitTestResult) async {
        // webViewController.execute("showContextMenu()");
      },
      onHideContextMenu: () {
        // removeOverlay();
      },
    );
    if (Prefs().openBookAnimation) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _animation =
          Tween<double>(begin: 1.0, end: 0.0).animate(_animationController!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationController!.forward();
      });
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> saveReadingProgress() async {
    if (cfi == '' || widget.cfi != null) return;
    Book book = widget.book;
    book.lastReadPosition = cfi;
    book.readingPercentage = percentage;
    await bookDao.updateBook(book);
    if (mounted) {
      ref.read(bookListProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _selectionDebounce?.cancel();
    _animationController?.dispose();
    saveReadingProgress();
    removeOverlay();
    super.dispose();
  }

  InAppWebViewSettings initialSettings = InAppWebViewSettings(
    // Pinch-to-zoom for EPUB/PDF pages. Zoom controls are hidden so the
    // reader keeps its clean look; taps still turn pages at 1.0x.
    supportZoom: true,
    builtInZoomControls: true,
    displayZoomControls: false,
    transparentBackground: true,
    isInspectable: kDebugMode,
    useHybridComposition: true,
  );

  bool get isDarkMode =>
      Theme.of(navigatorKey.currentContext!).brightness == Brightness.dark;

  void changeReadingInfo() {
    setState(() {});
  }

  Widget _buildHistoryCapsule() {
    final l10n = L10n.of(context);
    final buttonColor = Color(int.parse('0x$textColor')).withAlpha(200);

    // Common button style for all history navigation buttons
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
    );

    // Helper method to create history navigation buttons
    Widget createHistoryButton(
        IconData icon, String label, VoidCallback onPressed) {
      return TextButton.icon(
        icon: Icon(icon, size: 18, color: buttonColor),
        label: Text(label, style: TextStyle(color: buttonColor, fontSize: 14)),
        onPressed: onPressed,
        style: buttonStyle,
      );
    }

    // Build buttons list
    final List<Widget> buttons = [];

    if (canGoBack) {
      buttons.add(createHistoryButton(
        Icons.arrow_back,
        l10n.historyBack,
        backHistory,
      ));
    }

    buttons.add(createHistoryButton(
      Icons.close,
      l10n.historyClose,
      () => setState(() => showHistory = false),
    ));

    if (canGoForward) {
      buttons.add(createHistoryButton(
        Icons.arrow_forward,
        l10n.historyForward,
        forwardHistory,
      ));
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainer
                    .withAlpha(123),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: buttons,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget readingInfoWidget() {
    if (chapterCurrentPage == 0 && percentage == 0.0) {
      return const SizedBox();
    }

    final readingInfoColor = Color(int.parse('0x$textColor')).withAlpha(150);
    final iconColor = Color(int.parse('0x$textColor'));

    Widget getWidget(ReadingInfoEnum readingInfoEnum, TextStyle textStyle) {
      final batteryTextStyle = TextStyle(
        color: iconColor,
        fontSize: (textStyle.fontSize ?? 10) - 1,
      );
      final batteryIconSize = (textStyle.fontSize ?? 10) * 2.7;

      final chapterTitleWidget = Text(
        (!_isPdf && chapterCurrentPage == 1 ? widget.book.title : chapterTitle),
        style: textStyle,
      );

      final chapterProgressWidget = Text(
        '$chapterCurrentPage/$chapterTotalPages',
        style: textStyle,
      );

      final bookProgressWidget =
          Text('${(percentage * 100).toStringAsFixed(2)}%', style: textStyle);

      final timeWidget = MinuteClock(textStyle: textStyle);

      final batteryWidget = FutureBuilder(
          future: Battery().batteryLevel,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        0, (textStyle.fontSize ?? 10) * 0.08, 2, 0),
                    child: Text('${snapshot.data}', style: batteryTextStyle),
                  ),
                  Icon(
                    HeroIcons.battery_0,
                    size: batteryIconSize,
                    color: iconColor,
                  ),
                ],
              );
            } else {
              return const SizedBox();
            }
          });

      Widget batteryAndTimeWidget() => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              batteryWidget,
              const SizedBox(width: 5),
              timeWidget,
            ],
          );

      switch (readingInfoEnum) {
        case ReadingInfoEnum.chapterTitle:
          return chapterTitleWidget;
        case ReadingInfoEnum.chapterProgress:
          return chapterProgressWidget;
        case ReadingInfoEnum.bookProgress:
          return bookProgressWidget;
        case ReadingInfoEnum.battery:
          return batteryWidget;
        case ReadingInfoEnum.time:
          return timeWidget;
        case ReadingInfoEnum.batteryAndTime:
          return batteryAndTimeWidget();
        case ReadingInfoEnum.none:
          return const SizedBox(width: 30);
      }
    }

    final readingInfo = Prefs().readingInfo;

    final headerTextStyle = TextStyle(
      color: readingInfoColor,
      fontSize: readingInfo.header.fontSize,
    );
    final footerTextStyle = TextStyle(
      color: readingInfoColor,
      fontSize: readingInfo.footer.fontSize,
    );

    List<Widget> headerWidgets = [
      getWidget(readingInfo.header.left, headerTextStyle),
      getWidget(readingInfo.header.center, headerTextStyle),
      getWidget(readingInfo.header.right, headerTextStyle),
    ];

    List<Widget> footerWidgets = [
      getWidget(readingInfo.footer.left, footerTextStyle),
      getWidget(readingInfo.footer.center, footerTextStyle),
      getWidget(readingInfo.footer.right, footerTextStyle),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: readingInfo.header.verticalMargin,
            left: readingInfo.header.leftMargin,
            right: readingInfo.header.rightMargin,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: headerWidgets,
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.only(
            bottom: readingInfo.footer.verticalMargin,
            left: readingInfo.footer.leftMargin,
            right: readingInfo.footer.rightMargin,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: footerWidgets,
          ),
        ),
      ],
    );
  }

  Widget buildWebviewWithIOSWorkaround(
      BuildContext context, String url, String initialCfi) {
    final generatedUrl = generateUrl(
      url,
      initialCfi,
      backgroundColor: _isPdf ? themeBackgroundColor : backgroundColor,
      textColor: textColor,
      isDarkMode: Theme.of(context).brightness == Brightness.dark,
    );

    final webView = EpubWebView(
      url: generatedUrl,
      webViewEnvironment: webViewEnvironment,
      initialSettings: initialSettings,
      contextMenu: contextMenu,
      onWebViewCreated: onWebViewCreated,
      onConsoleMessage: webviewConsoleMessage,
    );

    if (!AnxPlatform.isIOS) {
      return SizedBox.expand(child: webView);
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          webView,
          Positioned.fill(
            child: PointerInterceptor(
              intercepting: !_isTopOfNavigationStack,
              debug: false,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String uri = Uri.encodeComponent(widget.book.fileFullPath);
    String url = 'http://127.0.0.1:${Server().port}/book/$uri';
    String initialCfi = widget.cfi ?? widget.book.lastReadPosition;
    // Marcadores/notas de PDF: `pdf:page=N` se traduce al CFI sintético que
    // entiende el renderer de página fija al abrir el libro.
    if (_isPdf) {
      final page = _pdfPageFromCfi(initialCfi);
      if (page != null) {
        initialCfi = 'epubcfi(/6/${page * 2})';
      }
    }

    return Listener(
      onPointerSignal: (event) {
        _handlePointerEvents(event);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _isPdf ? Colors.white : null,
        body: Stack(
          children: [
            buildWebviewWithIOSWorkaround(context, url, initialCfi),
            readingInfoWidget(),
            if (showHistory) _buildHistoryCapsule(),
            if (Prefs().openBookAnimation)
              SizedBox.expand(
                  child: IgnorePointer(
                ignoring: true,
                child: FadeTransition(
                    opacity: _animation!, child: BookCover(book: widget.book)),
              )),
          ],
        ),
      ),
    );
  }
}
