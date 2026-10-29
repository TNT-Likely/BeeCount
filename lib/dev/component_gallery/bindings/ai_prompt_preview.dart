import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../ai/core/prompt_builder.dart';
import '../../../ai/providers/ai_constants.dart';
import '../../../pages/ai/ai_prompt_edit_page.dart';

class LiveAIPromptPreview extends StatelessWidget {
  const LiveAIPromptPreview({super.key});
  Future<String> read() async {
    final raw = (await SharedPreferences.getInstance())
        .getString(AIConstants.keyAiCustomPrompt);
    return raw != null && raw.trim().isNotEmpty
        ? raw
        : PromptBuilder.defaultTemplate;
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('真实提示词（只读）'),
        const SizedBox(height: 8),
        FutureBuilder<String>(
            future: read(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('${snapshot.error}');
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final value = snapshot.data!,
                  missing = PromptBuilder.missingPlaceholdersIn(value);
              return BeeSurface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('${value.runes.length} 字符 · 缺失能力 ${missing.length} 项'),
                    const SizedBox(height: 8),
                    BeeCodeBlock(
                        text: value.runes.length > 300
                            ? '${String.fromCharCodes(value.runes.take(300))}\n…（预览前300字符）'
                            : value)
                  ]));
            }),
        BeeButton(
            label: '打开真实提示词编辑',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const AIPromptEditPage())))
      ]);
}
