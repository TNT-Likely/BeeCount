import 'package:beecount_business_ui/cloud_backup.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/cloud/cloud_sync_page.dart';
import '../../../pages/cloud/backup/bindings/cloud_backup_controls.dart';

/// Only reads the existing local/cache snapshot. Visiting the gallery does not
/// ask auth.currentUser, fetch a remote status or mutate the auto-sync preference.
class LiveCloudBackupPreview extends ConsumerWidget {
  const LiveCloudBackupPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final cached = ref.watch(lastSyncStatusProvider(ledgerId));
    final projection = cloudBackupPresentation(cached, l);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实备份状态缓存（只读）'),
      const SizedBox(height: 8),
      BeeCloudBackupSummary(
          title: l.mineSyncTitle,
          status: projection.label,
          icon: BeeLineIcon(projection.icon, size: 23),
          tone: projection.tone,
          localSummary:
              cached == null ? null : l.mineSyncLocalRecords(cached.localCount),
          remoteSummary: cached?.cloudCount == null
              ? null
              : l.mineSyncCloudRecords(cached!.cloudCount!)),
      const SizedBox(height: 12),
      BeeButton(
          label: l.cloudSyncPageTitle,
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const CloudSyncPage()))),
    ]);
  }
}
