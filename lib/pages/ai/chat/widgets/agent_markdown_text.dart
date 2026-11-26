import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Renders selectable GitHub-flavored Markdown in a chat message.
class AgentMarkdownText extends StatefulWidget {
  const AgentMarkdownText({
    super.key,
    required this.data,
    this.style,
  });

  final String data;
  final TextStyle? style;

  @override
  State<AgentMarkdownText> createState() => _AgentMarkdownTextState();
}

class _AgentMarkdownTextState extends State<AgentMarkdownText> {
  // Selectable text and code blocks have their own scrollables. Keep their
  // offsets separate from the enclosing ExpansionTile's stored bool.
  final _markdownStorage = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    return PageStorage(
      bucket: _markdownStorage,
      child: MarkdownBody(
        data: widget.data,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: baseStyle,
          h1: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
          h2: baseStyle.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
          h3: baseStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          code: baseStyle.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
