import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/ai_advanced.dart';
import '../../../utils/app_localizations_resolver.dart';

class AIAdvancedSample extends StatefulWidget {
  const AIAdvancedSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AIAdvancedSample> createState() => _SampleState();
}

class _SampleState extends State<AIAdvancedSample> {
  bool remembered = true, ask = true;
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeAIAdvancedNotice(
          text: l.agentMemoryIntro, icon: const BeeLineIcon('Brain', size: 22)),
      const SizedBox(height: 12),
      if (remembered)
        BeeAIAdvancedMemoryCard(
            content: '示例：午饭优先使用现金账户',
            deleteLabel: l.commonDelete,
            onDelete: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                        title: Text(l.agentMemoryDeleteTitle),
                        content: Text(l.agentMemoryDeleteDescription),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l.commonCancel)),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => remembered = false);
                              },
                              child: Text(l.commonDelete))
                        ])))
      else
        Text(l.agentMemoryEmpty),
      const SizedBox(height: 12),
      BeeAIAdvancedPermissionSection(
          title: l.agentPermissionsWriteSection,
          subtitle: l.agentPermissionsWriteSectionDescription,
          icon: const BeeLineIcon('ShieldCheck', size: 22),
          rows: [
            BeeAIAdvancedPermissionRow(
                title: l.agentToolRecordTransaction,
                description: l.agentToolRecordTransactionDescription,
                status:
                    ask ? l.agentPermissionAsk : l.agentPermissionAlwaysAllow,
                ask: ask,
                onTap: () => setState(() => ask = !ask))
          ]),
      const SizedBox(height: 12),
      BeeAIAdvancedActivityCard(
          message: '示例：本月花了多少',
          status: l.agentActivityCompleted,
          tone: BeeTone.success,
          toolsLabel: l.agentActivityTools,
          tools: [
            BeeAIAdvancedToolBadge(
                label: l.agentToolQueryTransactions,
                status: l.agentActivityToolCompleted,
                tone: BeeTone.success)
          ]),
      if (widget.liveData != null) ...[
        const SizedBox(height: 12),
        widget.liveData!
      ],
    ]);
  }
}
