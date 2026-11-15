import 'package:anx_reader/service/convert_to_epub/section.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

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
      headers: {'User-Agent': _userAgent, 'Accept-Language': 'es,en;q=0.8'},
    ),
  );
  final response = await dio.get<String>(
    uri.toString(),
    options: Options(responseType: ResponseType.plain, followRedirects: true),
  );
  final html = response.data ?? '';
  if (html.trim().isEmpty) {
    throw const FormatException('La página no devolvió contenido.');
  }
  return extractArticleFromHtml(html, url: uri.toString());
}

/// Pulls the main article out of a page: strips chrome and scripts, picks the
/// densest paragraph container and splits on <h2>-<h4> headings.
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

  if (sections.isEmpty) {
    throw const FormatException('No se encontró texto en la página.');
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
  final article = document.querySelector('article');
  if (article != null && article.text.trim().length > 200) return article;

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
