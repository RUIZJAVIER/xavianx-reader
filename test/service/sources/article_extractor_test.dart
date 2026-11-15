import 'package:anx_reader/service/sources/article_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const html = '''
<html>
<head>
  <title>Mi artículo | Blog</title>
  <meta name="author" content="Ana Pérez">
</head>
<body>
  <nav><a href="/">Inicio</a></nav>
  <article>
    <h1>Mi artículo</h1>
    <p>Primer párrafo del artículo con contenido suficiente para leer.</p>
    <h2>Sección uno</h2>
    <p>Segundo párrafo con más contenido para la extracción.</p>
    <script>alert('no')</script>
  </article>
  <footer>Pie de página</footer>
</body>
</html>
''';

  test('extractArticleFromHtml keeps the main text and drops the chrome', () {
    final article = extractArticleFromHtml(
      html,
      url: 'https://example.com/post',
    );

    expect(article.title, 'Mi artículo');
    expect(article.author, 'Ana Pérez');

    final text = article.text;
    expect(text, contains('Primer párrafo'));
    expect(text, contains('Segundo párrafo'));
    expect(text, isNot(contains('alert')));
    expect(text, isNot(contains('Inicio')));
    expect(text, isNot(contains('Pie de página')));
    expect(article.sections.map((section) => section.title),
        contains('Sección uno'));
  });

  test('articleFromText uses the first short line as title', () {
    final article = articleFromText('Título corto\n\nCuerpo del texto pegado.');

    expect(article.title, 'Título corto');
    expect(article.text, contains('Cuerpo del texto pegado.'));
    expect(article.preview, contains('Cuerpo del texto pegado.'));
  });
}
