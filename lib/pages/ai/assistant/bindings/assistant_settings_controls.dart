import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../agent/runtime/agent_execution_settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/ai_chat_providers.dart';
import '../../agent_activity_page.dart';
import '../../agent_memory_page.dart';
import '../../agent_permissions_page.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

class AssistantSettingsControls extends ConsumerStatefulWidget {
  const AssistantSettingsControls({super.key, required this.ledgerId});
  final int ledgerId;
  @override
  ConsumerState<AssistantSettingsControls> createState() =>
      _AssistantSettingsControlsState();
}

class _AssistantSettingsControlsState
    extends ConsumerState<AssistantSettingsControls> {
  AgentExecutionSettings? settings;
  Object? error;
  bool saving = false, loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final value = await ref.read(agentExecutionSettingsStoreProvider).read();
      if (mounted) {
        setState(() {
          settings = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  List<BeeExecutionDepthOption> options(AppLocalizations l) => [
        for (final item in [
          (2, l.agentExecutionDepthQuick),
          (AgentExecutionSettings.standardTurns, l.agentExecutionDepthStandard),
          (6, l.agentExecutionDepthDeep),
          (AgentExecutionSettings.maximumTurns, l.agentExecutionDepthCustom)
        ])
          BeeExecutionDepthOption(
              turns: item.$1,
              label: item.$2,
              description: l.agentExecutionDepthSelected(item.$1))
      ];
  Future<void> choose() async {
    if (settings == null || saving || loading) return;
    final l = AppLocalizations.of(context);
    final selected = await showBeeSheet<int>(context,
        title: l.agentExecutionDepthChooseTitle,
        child: SingleChildScrollView(
            child: BeeExecutionDepthPicker(
                options: options(l),
                selected: settings!.maximumModelTurns,
                onChanged: (v) => Navigator.pop(context, v))));
    if (selected == null || !mounted) return;
    setState(() => saving = true);
    try {
      await ref
          .read(agentExecutionSettingsStoreProvider)
          .setMaximumModelTurns(selected);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void go(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.agentAssistantSettingsTitle, leading: const BackButton()),
      Expanded(
          child: BeePageBody(children: [
        Text(l.agentAssistantSettingsSubtitle,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        BeeSurface(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(children: [
              BeeMenuRow(
                  title: l.agentAssistantPermissionsEntry,
                  subtitle: l.agentAssistantPermissionsEntryDescription,
                  leading: const BeeLineIcon('ShieldCheck'),
                  onTap: () => go(const AgentPermissionsPage())),
              const Divider(height: 1, indent: 12, endIndent: 12),
              BeeMenuRow(
                  title: l.agentAssistantMemoryEntry,
                  subtitle: l.agentAssistantMemoryEntryDescription,
                  leading: const BeeLineIcon('Brain'),
                  onTap: () => go(AgentMemoryPage(ledgerId: widget.ledgerId))),
              const Divider(height: 1, indent: 12, endIndent: 12),
              BeeMenuRow(
                  title: l.agentAssistantActivityEntry,
                  subtitle: l.agentAssistantActivityEntryDescription,
                  leading: const BeeLineIcon('History'),
                  onTap: () => go(AgentActivityPage(ledgerId: widget.ledgerId)))
            ])),
        BeeSurface(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: BeeMenuRow(
                title: l.agentExecutionDepthEntry,
                subtitle: settings == null
                    ? l.agentExecutionDepthEntryDescription
                    : l.agentExecutionDepthSelected(
                        settings!.maximumModelTurns),
                leading: const BeeLineIcon('SlidersHorizontal'),
                trailing: loading || saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: settings == null || saving || loading ? null : choose)),
        if (error != null)
          BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                BeeStatus(
                    label: '${l.commonError}: $error', tone: BeeTone.error),
                const SizedBox(height: 8),
                BeeButton(
                    label: l.helpCenterRetry,
                    kind: BeeButtonKind.secondary,
                    onPressed: load)
              ]))
      ]))
    ]));
  }
}
