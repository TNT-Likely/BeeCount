import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Renders model output as GitHub-flavored Markdown inside an existing chat
/// bubble. MarkdownBody sizes to its content and does not create a nested
/// scroll view.
class AgentMarkdownText extends StatelessWidget {
  const AgentMarkdownText({
    super.key,
    required this.data,
    this.style,
  });

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        h1: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        h2: baseStyle.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
        h3: baseStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        code: baseStyle.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
