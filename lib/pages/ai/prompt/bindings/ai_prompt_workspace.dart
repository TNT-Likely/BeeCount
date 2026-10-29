import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../ai/core/prompt_builder.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/ai_prompt_controller.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

class AIPromptWorkspace extends StatefulWidget {
  const AIPromptWorkspace({super.key});
  @override
  State<AIPromptWorkspace> createState() => _AIPromptWorkspaceState();
}

class _AIPromptWorkspaceState extends State<AIPromptWorkspace> {
  final c = AIPromptEditorController();
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String description(String token, AppLocalizations l) => switch (token) {
        '{{BILL_GUARD}}' => l.aiPromptVarBillGuard,
        '{{INPUT_SOURCE}}' => l.aiPromptVarInputSource,
        '{{CURRENT_TIME}}' => l.aiPromptVarCurrentTime,
        '{{CURRENT_DATE}}' => l.aiPromptVarCurrentDate,
        '{{OCR_TEXT}}' => l.aiPromptVarOcrText,
        '{{CATEGORIES}}' => l.aiPromptVarCategories,
        '{{ACCOUNTS}}' => l.aiPromptVarAccounts,
        '{{CURRENCIES}}' => l.aiPromptVarCurrencies,
        _ => token
      };
  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null || data!.text!.isEmpty) return;
    c.text.text = data.text!;
    showBeeToast(context, AppLocalizations.of(context).aiPromptPasted);
  }

  Future<void> share() async {
    if (c.text.text.isEmpty) return;
    await SharePlus.instance.share(ShareParams(
        text: c.text.text,
        subject: AppLocalizations.of(context).aiPromptEditTitle));
  }

  Future<void> reset() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => BeeDialog(
                title: Text(l.aiPromptResetConfirmTitle),
                content: Text(l.aiPromptResetConfirmMessage),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.commonCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.commonConfirm))
                ]));
    if (mounted && confirmed == true) c.resetDraft();
  }

  void preview() {
    final l = AppLocalizations.of(context);
    showDialog<void>(
        context: context,
        builder: (ctx) => BeeDialog(
                title: Text(l.aiPromptPreviewTitle),
                content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BeeCodeBlock(text: c.preview()),
                      const SizedBox(height: 12),
                      Text(l.aiPromptPreviewNote,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Theme.of(ctx).hintColor))
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l.commonClose))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedBuilder(
        animation: c,
        builder: (context, _) => V4PageScaffold(
                body: Column(children: [
              BeePageHeader(
                  title: l.aiPromptEditTitle,
                  leading: const BackButton(),
                  actions: [
                    BeeIconButton(
                        label: l.aiPromptShare,
                        icon: const BeeLineIcon('Share2'),
                        onPressed: c.loading ? null : share),
                    BeeIconButton(
                        label: l.aiPromptPaste,
                        icon: const BeeLineIcon('ClipboardPlus'),
                        onPressed: c.loading ? null : paste)
                  ]),
              Expanded(
                  child: c.loading
                      ? const Center(child: CircularProgressIndicator())
                      : c.error != null && c.text.text.isEmpty
                          ? BeeEmptyState(
                              title: l.commonError,
                              message: '${c.error}',
                              action: BeeButton(
                                  label: l.helpCenterRetry, onPressed: c.load))
                          : BeePageBody(eager: true, children: [
                              Text(l.aiPromptEditSubtitle,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor)),
                              BeePromptVariables(
                                  title: l.aiPromptVariables,
                                  hint: l.aiPromptVariablesHint,
                                  variables: [
                                    for (final p in PromptBuilder.placeholders)
                                      BeePromptVariable(
                                          p.token, description(p.token, l))
                                  ]),
                              if (c.missing.isNotEmpty)
                                BeeSurface(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                      BeeStatus(
                                          label: l.aiPromptMissingVarsHint(c
                                              .missing
                                              .map((p) => p.token)
                                              .join('、')),
                                          tone: BeeTone.warning),
                                      const SizedBox(height: 12),
                                      for (final p in c.missing.where(
                                          (p) => p.appendSnippet != null)) ...[
                                        BeeButton(
                                            label: l.aiPromptInsertVarSection(
                                                p.token),
                                            onPressed: () {
                                              if (c.append(p)) {
                                                showBeeToast(
                                                    context,
                                                    l.aiPromptVarSectionInserted(
                                                        p.token));
                                              }
                                            }),
                                        const SizedBox(height: 8)
                                      ],
                                      BeeButton(
                                          label: l.aiPromptResetDefault,
                                          kind: BeeButtonKind.secondary,
                                          onPressed: reset)
                                    ])),
                              BeePromptDocument(
                                  key: const ValueKey('ai-prompt-document'),
                                  title: l.aiPromptContent,
                                  unsavedLabel: l.aiPromptUnsaved,
                                  dirty: c.dirty,
                                  editor: BeeCodeEditor(
                                      label: l.aiPromptContent,
                                      controller: c.text,
                                      hint: l.aiPromptInputHint)),
                              BeeSurface(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                    Wrap(spacing: 12, runSpacing: 8, children: [
                                      BeeButton(
                                          label: l.aiPromptPreview,
                                          kind: BeeButtonKind.secondary,
                                          onPressed: preview),
                                      BeeButton(
                                          label: l.aiPromptSave,
                                          onPressed: !c.dirty || c.saving
                                              ? null
                                              : () async {
                                                  final saved = await c.save();
                                                  if (!context.mounted) return;
                                                  showBeeToast(
                                                      context,
                                                      saved
                                                          ? l.aiPromptSaved
                                                          : '${l.commonError}: ${c.error}');
                                                })
                                    ]),
                                    const SizedBox(height: 12),
                                    BeeButton(
                                        label: l.aiPromptResetDefault,
                                        kind: BeeButtonKind.secondary,
                                        onPressed: reset)
                                  ]))
                            ]))
            ])));
  }
}
