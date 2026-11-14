import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizations_resolver.dart';

class AIPromptSample extends StatefulWidget {
  const AIPromptSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AIPromptSample> createState() => _AIPromptSampleState();
}

class _AIPromptSampleState extends State<AIPromptSample> {
  final input = TextEditingController(text: 'QA合成模板 {{OCR_TEXT}}');
  String saved = 'QA合成模板 {{OCR_TEXT}}', event = '示例草稿，不写真实配置';
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeePromptVariables(
          title: l.aiPromptVariables,
          hint: l.aiPromptVariablesHint,
          variables: [
            BeePromptVariable('{{OCR_TEXT}}', l.aiPromptVarOcrText),
            BeePromptVariable('{{CURRENCIES}}', l.aiPromptVarCurrencies)
          ]),
      const SizedBox(height: 12),
      BeePromptDocument(
          title: l.aiPromptContent,
          unsavedLabel: l.aiPromptUnsaved,
          dirty: input.text != saved,
          editor: BeeCodeEditor(
              label: l.aiPromptContent,
              controller: input,
              minLines: 3,
              maxLines: 8,
              onChanged: (_) => setState(() {}))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        BeeButton(
            label: l.aiPromptSave,
            onPressed: input.text == saved
                ? null
                : () => setState(() {
                      saved = input.text;
                      event = '示例已保存，不写真实模板';
                    })),
        BeeButton(
            label: l.aiPromptResetDefault,
            kind: BeeButtonKind.secondary,
            onPressed: () => setState(() {
                  input.text = 'QA合成模板 {{OCR_TEXT}}';
                  event = '示例恢复，只改草稿';
                })),
        BeeButton(
            label: l.aiPromptPreview,
            kind: BeeButtonKind.secondary,
            onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => BeeDialog(
                        title: Text(l.aiPromptPreviewTitle),
                        content:
                            BeeCodeBlock(
                                text: input.text
                                    .replaceAll('{{OCR_TEXT}}', '合成账单文本')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l.commonClose))
                        ])))
      ]),
      const SizedBox(height: 8),
      Text(event),
      const SizedBox(height: 16),
      widget.liveData ?? const Text('App读取真实模板长度与缺失能力；编辑与系统分享由App绑定。')
    ]);
  }
}
