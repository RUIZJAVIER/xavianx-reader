import 'dart:io';

import 'package:anx_reader/providers/book_list.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/service/convert_to_epub/create_epub.dart';
import 'package:anx_reader/service/convert_to_epub/section.dart';
import 'package:anx_reader/service/md5_service.dart';
import 'package:anx_reader/service/sources/article_extractor.dart';
import 'package:anx_reader/service/sources/youtube_transcript.dart';
import 'package:anx_reader/utils/get_path/get_temp_dir.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SourceKind { youtube, article }

const _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

class _LoadedSource {
  const _LoadedSource({
    required this.title,
    required this.author,
    required this.sections,
    required this.preview,
  });

  final String title;
  final String author;
  final List<Section> sections;
  final String preview;
}

/// Imports a YouTube transcript or a web article as a book in the library, so
/// it can be read and mined for vocabulary like any EPUB.
class SourceImportPage extends ConsumerStatefulWidget {
  const SourceImportPage({super.key, required this.kind});

  final SourceKind kind;

  @override
  ConsumerState<SourceImportPage> createState() => _SourceImportPageState();
}

class _SourceImportPageState extends ConsumerState<SourceImportPage> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  _LoadedSource? _source;

  bool get _isYouTube => widget.kind == SourceKind.youtube;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _error = _isYouTube
          ? 'Pega la URL del vídeo de YouTube.'
          : 'Pega la URL del artículo o su texto.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _source = null;
    });

    try {
      final _LoadedSource loaded;
      if (_isYouTube) {
        final transcript = await fetchYouTubeTranscript(input);
        loaded = _LoadedSource(
          title: transcript.title,
          author: transcript.author,
          sections: _chunkTranscript(transcript.text),
          preview: _previewOf(transcript.text),
        );
      } else if (_isPdfUrl(input)) {
        await _importPdf(_looksLikeUrl(input) ? input : 'https://$input');
        return;
      } else if (_looksLikeUrl(input) || _looksLikeBareUrl(input)) {
        final url = _looksLikeUrl(input) ? input : 'https://$input';
        final article = await fetchArticle(url);
        loaded = _LoadedSource(
          title: article.title,
          author: article.author,
          sections: article.sections,
          preview: article.preview,
        );
      } else {
        final article = articleFromText(input);
        loaded = _LoadedSource(
          title: article.title,
          author: article.author,
          sections: article.sections,
          preview: article.preview,
        );
      }
      if (!mounted) return;
      setState(() {
        _source = loaded;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _describe(e);
      });
    }
  }

  /// Scientific papers are usually served as PDF, which the reader already
  /// opens natively; download it and register it as a book.
  Future<void> _importPdf(String url) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'User-Agent': _userAgent},
      ),
    );
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes, followRedirects: true),
    );
    final bytes = response.data ?? const <int>[];
    if (bytes.isEmpty) {
      throw const FormatException('El PDF está vacío o no se pudo descargar.');
    }

    final uri = Uri.parse(url);
    final fileName =
        uri.pathSegments.isEmpty ? 'documento.pdf' : uri.pathSegments.last;
    final bareName = fileName.toLowerCase().endsWith('.pdf')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    final title = _safeTitle(bareName.replaceAll(RegExp(r'[-_]+'), ' '));

    final dir = await getAnxTempDir();
    final file = File('${dir.path}/$title.pdf');
    await file.writeAsBytes(bytes, flush: true);
    final md5 = await MD5Service.calculateFileMd5(file.path);
    await saveBook(file, title, uri.host, '', md5, '');
    if (!mounted) return;
    ref.read(bookListProvider.notifier).refresh();
    Navigator.pop(context, true);
  }

  bool _isPdfUrl(String value) {
    final uri = Uri.tryParse(_looksLikeUrl(value) ? value : 'https://$value');
    return uri != null && uri.path.toLowerCase().endsWith('.pdf');
  }

  Future<void> _import() async {
    final source = _source;
    if (source == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // createEpub uses the title as a directory name, so it must be safe.
      final file = await createEpub(
        _safeTitle(source.title),
        source.author,
        source.sections,
      );
      final md5 = await MD5Service.calculateFileMd5(file.path);
      await saveBook(file, source.title, source.author, '', md5, '');
      if (!mounted) return;
      ref.read(bookListProvider.notifier).refresh();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo añadir a la biblioteca: ${_describe(e)}';
      });
    }
  }

  /// Long transcripts become numbered chapters so the reader TOC is usable.
  List<Section> _chunkTranscript(String text) {
    const maxChars = 6000;
    final paragraphs = text
        .split('\n')
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) {
      return [Section('Transcripción', text.trim(), 1)];
    }

    final sections = <Section>[];
    final buffer = StringBuffer();
    for (final paragraph in paragraphs) {
      final line = paragraph.trim();
      if (buffer.length + line.length > maxChars && buffer.isNotEmpty) {
        sections.add(
          Section('Parte ${sections.length + 1}', buffer.toString().trim(), 1),
        );
        buffer.clear();
      }
      buffer.writeln(line);
    }
    if (buffer.isNotEmpty) {
      sections
          .add(Section('Parte ${sections.length + 1}', buffer.toString().trim(), 1));
    }
    if (sections.length == 1) {
      return [Section('Transcripción', sections.first.content, 1)];
    }
    return sections;
  }

  String _previewOf(String text) =>
      text.length <= 600 ? text : '${text.substring(0, 600)}…';

  String _safeTitle(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return _isYouTube ? 'YouTube' : 'Articulo';
    return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  }

  bool _looksLikeUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// "ejemplo.com/nota": a single token with a dotted host and no scheme.
  bool _looksLikeBareUrl(String value) {
    if (value.contains(RegExp(r'\s')) || value.length > 200) return false;
    final uri = Uri.tryParse('https://$value');
    return uri != null && uri.host.contains('.');
  }

  String _describe(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      return status == null
          ? 'Error de red (${error.type.name}).'
          : 'La página respondió con HTTP $status.';
    }
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = _source;

    return Scaffold(
      appBar: AppBar(title: Text(_isYouTube ? 'YouTube' : 'Artículo web')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isYouTube
                ? 'Pega la URL del vídeo: se descargará su transcripción '
                    '(subtítulos manuales o autogenerados), se limpiarán los '
                    'ruidos de los subtítulos y quedará en tu biblioteca como '
                    'un libro.'
                : 'Pega la URL de un artículo, blog o paper (HTML o PDF) para '
                    'extraer su texto principal, o pega directamente el texto '
                    'que quieras leer.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            minLines: 1,
            maxLines: _isYouTube ? 1 : 6,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _load(),
            onChanged: (_) {
              if (_source != null || _error != null) {
                setState(() {
                  _source = null;
                  _error = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: _isYouTube ? 'URL del vídeo' : 'URL o texto',
              hintText: _isYouTube
                  ? 'https://www.youtube.com/watch?v=…'
                  : 'https://ejemplo.com/articulo',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Procesar'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (source != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.author,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const Divider(height: 24),
                    Text(
                      source.preview,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('Añadir a la biblioteca'),
            ),
          ],
        ],
      ),
    );
  }
}
