import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Renders the small HTML subset written by the flashcard editor (<b>, <i>,
/// <font color>) so cards look the same in the app and in Anki.
class VocabularyRichText extends StatelessWidget {
  const VocabularyRichText(this.data, {super.key, this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: buildVocabularySpans(data, baseStyle),
      ),
    );
  }
}

List<InlineSpan> buildVocabularySpans(String data, TextStyle baseStyle) {
  if (!data.contains('<')) return [TextSpan(text: data, style: baseStyle)];
  try {
    return _spans(html_parser.parseFragment(data), baseStyle);
  } catch (_) {
    return [TextSpan(text: data, style: baseStyle)];
  }
}

List<InlineSpan> _spans(dom.Node node, TextStyle style) {
  final spans = <InlineSpan>[];
  for (final child in node.nodes) {
    if (child is dom.Text) {
      spans.add(TextSpan(text: child.text, style: style));
      continue;
    }
    if (child is! dom.Element) continue;

    final tag = child.localName;
    if (tag == 'br') {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }
    var childStyle = style;
    if (tag == 'b' || tag == 'strong') {
      childStyle = style.copyWith(fontWeight: FontWeight.bold);
    } else if (tag == 'i' || tag == 'em') {
      childStyle = style.copyWith(fontStyle: FontStyle.italic);
    } else if (tag == 'u') {
      childStyle = style.copyWith(decoration: TextDecoration.underline);
    } else if (tag == 'font') {
      final color = _hexColor(child.attributes['color']);
      if (color != null) childStyle = style.copyWith(color: color);
    }
    spans.addAll(_spans(child, childStyle));
  }
  return spans;
}

Color? _hexColor(String? value) {
  final hex = value?.trim().replaceFirst('#', '') ?? '';
  if (hex.length != 6 && hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(hex.length == 8 ? parsed : 0xff000000 | parsed);
}
