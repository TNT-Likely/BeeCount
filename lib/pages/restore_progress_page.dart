import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../widgets/ui/ui.dart';
import '../l10n/app_localizations.dart';

class RestoreProgressPage extends ConsumerWidget {
  const RestoreProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(cloudRestoreProgressProvider);
    final logs = ref.watch(cloudRestoreLogProvider);
    final summary = ref.watch(cloudRestoreSummaryProvider);
    final title =
        p.running ? AppLocalizations.of(context)!.restoreProgress(p.currentIndex, p.totalLedgers) : AppLocalizations.of(context)!.restorePreparing;
    final sub = p.currentLedgerName == null
        ? ''
        : AppLocalizations.of(context)!.restoreLedgerProgress(
            p.currentLedgerName ?? '',
            p.currentDone,
            p.currentTotal,
          );

    // 仅当检测到“已完成摘要”时自动返回，避免任务尚未启动（running=false）时立刻返回
    if (!p.running && summary != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context)!.restoreTitle,
            showBack: true,
            actions: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.copyLog,
                onPressed: logs.isEmpty
                    ? null
                    : () async {
                        final text = logs.join('\n');
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          showToast(context, AppLocalizations.of(context)!.logCopied);
                        }
                      },
                icon: const Icon(Icons.copy, color: Colors.black87),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16)),
                      if (!p.running && summary == null) ...[
                        const SizedBox(height: 6),
                        Text(AppLocalizations.of(context)!.waitingRestore),
                      ],
                      const SizedBox(height: 6),
                      // 总体百分比条（已完成账本/总账本）
                      SizedBox(
                        height: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p.totalLedgers <= 0
                                ? 0
                                : (p.currentIndex / p.totalLedgers)
                                    .clamp(0.0, 1.0),
                            backgroundColor: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (sub.isNotEmpty) Text(sub),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: p.currentTotal <= 0
                            ? null
                            : (p.currentDone / (p.currentTotal))
                                .clamp(0.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: logs.length,
              itemBuilder: (_, i) => Text(
                logs[i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
