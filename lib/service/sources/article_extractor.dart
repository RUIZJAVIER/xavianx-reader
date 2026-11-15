import 'dart:convert';

import 'package:anx_reader/service/convert_to_epub/section.dart';
import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Containers used by most blogs, news sites and journal landing pages.
const _contentSelectors = [
  'article',
  '[itemprop="articleBody"]',
  '.post-content',
  '.entry-content',
  '.article-content',
  '.article-body',
  '.post-body',
  '.markdown-body',
  '.story-body',
  '.content-body',
  '#article-body',
  '#content',
  'main',
];

/// Clean article text, already split into book sections.
class ExtractedArticle {
  const ExtractedArticle({
    required this.title,
    required this.author,
    required this.sections,
  });

  final String title;
  final String author;
  final List<Section> sections;

  String get text => sections.map((section) => section.content).join('\n\n');

  String get preview => text.length <= 600 ? text : '${text.substring(0, 600)}…';
}

const _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

Future<ExtractedArticle> fetchArticle(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) {
    throw const FormatException('La URL del artículo no es válida.');
  }
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
        'Upgrade-Insecure-Requests': '1',
      },
    ),
  );
  final Response<List<int>> response;
  try {
    response = await dio.get<List<int>>(
      uri.toString(),
      options: Options(responseType: ResponseType.bytes, followRedirects: true),
    );
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 403 || code == 401) {
      throw const FormatException(
        'Este sitio web está protegido contra lectores automáticos (Cloudflare/Paywall). '
        'Copia y pega directamente el texto del artículo en esta casilla.',
      );
    }
    rethrow;
  }
  final bytes = response.data ?? const <int>[];
  if (bytes.isEmpty) {
    throw const FormatException('La página no devolvió contenido.');
  }
  final html = _decodeHtml(
    bytes,
    response.headers.value(Headers.contentTypeHeader),
  );
  if (html.trim().isEmpty) {
    throw const FormatException('La página no devolvió contenido.');
  }

  if (html.contains('cf-browser-verification') ||
      html.contains('Just a moment...') ||
      html.contains('Attention Required! | Cloudflare')) {
    throw const FormatException(
      'Este sitio web está protegido por Cloudflare. '
      'Copia y pega directamente el texto del artículo en esta casilla.',
    );
  }

  return extractArticleFromHtml(html, url: uri.toString());
}

/// Decodes the response using the charset from the headers or the meta tag;
/// many blogs still serve ISO-8859-1.
String _decodeHtml(List<int> bytes, String? contentType) {
  final declared = RegExp(r'charset=([\w-]+)', caseSensitive: false)
      .firstMatch(contentType ?? '')
      ?.group(1);
  final head = latin1.decode(
    bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes,
    allowInvalid: true,
  );
  final meta = RegExp('charset=["\']?([\\w-]+)', caseSensitive: false)
      .firstMatch(head)
      ?.group(1);
  final charset = (declared ?? meta ?? 'utf-8').toLowerCase();

  try {
    switch (charset) {
      case 'iso-8859-1':
      case 'latin1':
      case 'windows-1252':
        return latin1.decode(bytes);
      case 'gbk':
      case 'gb2312':
        return gbk.decode(bytes);
      case 'utf-16':
      case 'utf16':
        return utf16.decode(bytes);
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

/// Pulls the main article out of a page: strips chrome and scripts, tries the
/// usual blog/news/journal containers, falls back to the densest paragraph
/// container and splits on <h2>-<h4> headings (or block text for pages that do
/// not use <p>).
ExtractedArticle extractArticleFromHtml(String html, {required String url}) {
  final document = html_parser.parse(html);

  final title = _clean(
    _meta(document, 'property', 'og:title') ??
        _meta(document, 'name', 'twitter:title') ??
        _firstText(document, 'article h1') ??
        _firstText(document, 'h1') ??
        _firstText(document, 'title') ??
        '',
  );
  final author = _clean(
    _meta(document, 'name', 'author') ?? (Uri.tryParse(url)?.host ?? ''),
  );

  for (final selector in const [
    'script',
    'style',
    'noscript',
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'iframe',
    'svg',
    'button',
    'canvas',
    'template',
  ]) {
    for (final node in document.querySelectorAll(selector)) {
      node.remove();
    }
  }

  final root = _contentRoot(document);
  final sections = <Section>[];
  final seen = <String>{};
  final buffer = StringBuffer();
  var currentTitle = '';

  void flush() {
    final content = buffer.toString().trim();
    if (content.isNotEmpty) sections.add(Section(currentTitle, content, 1));
    buffer.clear();
  }

  for (final element
      in root.querySelectorAll('h2, h3, h4, p, li, blockquote, pre')) {
    final text = _clean(element.text);
    if (text.length < 2) continue;
    final tag = element.localName ?? '';
    if (tag.startsWith('h')) {
      flush();
      currentTitle = text;
      continue;
    }
    if (!seen.add(text)) continue;
    buffer.writeln(text);
  }
  flush();

  // Blogs without <p> (or with the text hidden in <br> blocks) need the raw
  // block text; keep the paragraph sections when they already cover the page.
  final collected =
      sections.fold<int>(0, (total, section) => total + section.content.length);
  final blockText = _blockText(root);
  final paragraphsArePoor =
      root.querySelectorAll('p').isEmpty || blockText.length > collected * 2;
  if (paragraphsArePoor && blockText.length > collected) {
    sections
      ..clear()
      ..add(Section('', blockText, 1));
  }

  if (sections.isEmpty) {
    throw const FormatException(
      'No se encontró texto legible en la página (puede ser un sitio dinámico). '
      'Copia y pega directamente el texto del artículo en esta casilla.',
    );
  }

  return ExtractedArticle(
    title: title.isEmpty
        ? (Uri.tryParse(url)?.host ?? 'Artículo')
        : title,
    author: author.isEmpty ? 'Web' : author,
    sections: sections,
  );
}

/// Fallback for pasted text instead of a URL: the first short line becomes the
/// title, the rest the body.
ExtractedArticle articleFromText(String text) {
  final normalized = text.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    throw const FormatException('El texto está vacío.');
  }
  final firstLine = normalized.split('\n').firstWhere(
        (line) => line.trim().isNotEmpty,
        orElse: () => '',
      );
  final hasTitle = firstLine.trim().length <= 80;
  final body =
      hasTitle ? normalized.substring(firstLine.length).trim() : normalized;
  return ExtractedArticle(
    title: hasTitle ? firstLine.trim() : 'Artículo pegado',
    author: 'Web',
    sections: [Section('', body.isEmpty ? normalized : body, 1)],
  );
}

String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

String? _meta(dom.Document document, String attribute, String value) {
  final content =
      document.querySelector('meta[$attribute="$value"]')?.attributes['content'];
  return content == null || content.trim().isEmpty ? null : content;
}

String? _firstText(dom.Document document, String selector) {
  final text = document.querySelector(selector)?.text.trim();
  return text == null || text.isEmpty ? null : text;
}

dom.Element _contentRoot(dom.Document document) {
  for (final selector in _contentSelectors) {
    final element = document.querySelector(selector);
    if (element != null && element.text.trim().length > 400) return element;
  }

  dom.Element? best;
  var bestScore = 0;
  for (final candidate
      in document.querySelectorAll('div, section, main, article')) {
    var score = 0;
    for (final paragraph in candidate.querySelectorAll('p')) {
      score += paragraph.text.trim().length;
    }
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  if (best != null && bestScore > 200) return best;

  final body = document.body ?? document.documentElement;
  if (body == null) {
    throw const FormatException('La página no tiene contenido legible.');
  }
  return body;
}

/// Text for pages that use <br> or bare divs instead of <p> paragraphs.
String _blockText(dom.Element root) {
  final html =
      root.innerHtml.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  final text = html_parser.parseFragment(html).text ?? '';
  return text
      .split('\n')
      .map(_clean)
      .where((line) => line.isNotEmpty)
      .join('\n');
}
