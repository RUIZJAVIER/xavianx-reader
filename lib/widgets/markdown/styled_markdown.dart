import 'package:anx_reader/widgets/markdown/selection_control.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// A custom Markdown widget with theme-aware styling.
/// This widget provides better contrast and readability in both light and dark modes,
/// especially for blockquotes and code blocks that appear in AI chat responses.
class StyledMarkdown extends StatelessWidget {
  final String data;
  final bool selectable;
  final double? fontSize;

  const StyledMarkdown({
    super.key,
    required this.data,
    this.selectable = true,
    this.fontSize,
  });

  static final RegExp _thinkBlockRegex =
      RegExp(r'<think-block>.*?</think-block>', dotAll: true);
  static final RegExp _toolStepRegex =
      RegExp(r'<tool-step>.*?</tool-step>', dotAll: true);
  static final RegExp _thinkRegex =
      RegExp(r'<think>.*?</think>', dotAll: true);
  static final RegExp _trailingThinkBlock =
      RegExp(r'<think-block>.*$', dotAll: true);
  static final RegExp _trailingToolStep =
      RegExp(r'<tool-step>.*$', dotAll: true);
  static final RegExp _trailingThink =
      RegExp(r'<think>.*$', dotAll: true);

  static String stripLlmArtifacts(String input) {
    return input
        .replaceAll(_thinkBlockRegex, '')
        .replaceAll(_toolStepRegex, '')
        .replaceAll(_thinkRegex, '')
        .replaceAll(_trailingThinkBlock, '')
        .replaceAll(_trailingToolStep, '')
        .replaceAll(_trailingThink, '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseFontSize = fontSize;
    final cleanedData = stripLlmArtifacts(data);
    return SelectableRegion(
      selectionControls: selectionControls(),
      child: GptMarkdown(cleanedData,
          followLinkColor: true,
          style:
              baseFontSize != null ? TextStyle(fontSize: baseFontSize) : null,
          onLinkTap: (href, text) =>
              launchUrlString(href, mode: LaunchMode.externalApplication),
          linkBuilder: (context, text, url, style) => Text.rich(
                text,
                style: style.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              )),
    );
  }
}
