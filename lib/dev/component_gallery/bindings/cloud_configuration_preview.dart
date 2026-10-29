import 'package:beecount_business_ui/cloud_configuration.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import '../../../l10n/app_localizations.dart';
import '../../../pages/cloud/cloud_service_page.dart';
import '../../../providers/sync_providers.dart';

/// Reads configuration metadata only; never initializes auth or tests a server.
class LiveCloudConfigurationPreview extends ConsumerWidget {
  const LiveCloudConfigurationPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实云服务配置（只读）'),
      const SizedBox(height: 8),
      ref.watch(activeCloudConfigProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => BeeStatus(label: '$error', tone: BeeTone.error),
          data: (config) => BeeCloudConnectionSummary(
              currentLabel: l.commonCurrent,
              service: config.type == CloudBackendType.local
                  ? l.cloudLocalStorageTitle
                  : config.name,
              endpoint: config.type == CloudBackendType.local
                  ? l.cloudLocalStorageSubtitle
                  : config.obfuscatedUrl(),
              status: l.cloudStatusNotTested,
              tone: BeeTone.neutral)),
      const SizedBox(height: 12),
      BeeButton(
          label: l.mineCloudService,
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const CloudServicePage()))),
    ]);
  }
}
