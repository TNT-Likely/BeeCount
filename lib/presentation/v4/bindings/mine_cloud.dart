import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import '../../../providers.dart';
import '../../../cloud/sync_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/cloud/cloud_service_page.dart';
import '../../../pages/cloud/cloud_sync_page.dart';
import '../../../pages/cloud/beecount_cloud_sync_page.dart';

/// The authentication future is owned by Riverpod, not recreated on every paint.
final mineCloudUserProvider =
    FutureProvider.autoDispose<CloudUser?>((ref) async {
  final auth = await ref.watch(authServiceProvider.future);
  return auth.currentUser;
});

({BeeSyncState state, String label}) mineSyncPresentation(
        SyncDiff? diff, AppLocalizations l) =>
    switch (diff) {
      SyncDiff.notLoggedIn => (
          state: BeeSyncState.signedOut,
          label: l.mineSyncNotLoggedIn
        ),
      SyncDiff.notConfigured => (
          state: BeeSyncState.unconfigured,
          label: l.mineSyncNotConfigured
        ),
      SyncDiff.noRemote => (
          state: BeeSyncState.noCloudData,
          label: l.mineSyncNoRemote
        ),
      SyncDiff.inSync => (
          state: BeeSyncState.synced,
          label: l.mineSyncInSyncSimple
        ),
      SyncDiff.localNewer => (
          state: BeeSyncState.localNewer,
          label: l.mineSyncLocalNewerSimple
        ),
      SyncDiff.cloudNewer => (
          state: BeeSyncState.cloudNewer,
          label: l.mineSyncCloudNewerSimple
        ),
      SyncDiff.different => (
          state: BeeSyncState.conflict,
          label: l.mineSyncDifferent
        ),
      SyncDiff.error => (state: BeeSyncState.error, label: l.mineSyncError),
      null => (state: BeeSyncState.checking, label: l.mineCloudServiceLoading)
    };

class MineCloudBinding extends ConsumerWidget {
  const MineCloudBinding({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        cfg = ref.watch(activeCloudConfigProvider);
    final version = ref.watch(beecountCloudServerVersionProvider).valueOrNull;
    final auth = ref.watch(mineCloudUserProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final live = ref.watch(syncStatusProvider(ledgerId));
    final status =
        live.valueOrNull ?? ref.watch(lastSyncStatusProvider(ledgerId));
    final local = cfg.valueOrNull?.type == CloudBackendType.local;
    final canUseCloud = !local &&
        (cfg.valueOrNull?.type == CloudBackendType.icloud ||
            auth.valueOrNull != null);
    final projection =
        mineSyncPresentation(local ? SyncDiff.notConfigured : status?.diff, l);
    final error = cfg.error ?? auth.error ?? live.error;
    final state = error != null
        ? BeeSyncState.error
        : canUseCloud && live.isLoading
            ? BeeSyncState.checking
            : projection.state;
    final label = error != null ? l.mineSyncError : projection.label;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BeeMenuRow(
          title: l.mineCloudService,
          leading: const BeeLineIcon('Cloud', size: 19),
          subtitle: cfg.when(
              loading: () => l.mineCloudServiceLoading,
              error: (e, _) => '${l.commonError}: $e',
              data: (value) => switch (value.type) {
                    CloudBackendType.local => l.mineCloudServiceOffline,
                    CloudBackendType.webdav => l.mineCloudServiceWebDAV,
                    CloudBackendType.icloud => 'iCloud',
                    CloudBackendType.supabase => l.mineCloudServiceCustom,
                    CloudBackendType.s3 => 'S3',
                    CloudBackendType.beecountCloud =>
                      version?.isNotEmpty == true
                          ? 'BeeCount Cloud v$version'
                          : 'BeeCount Cloud'
                  }),
          onTap: () => open(const CloudServicePage())),
      const Divider(height: 1, indent: 12, endIndent: 12),
      Opacity(
          opacity: local ? .45 : 1,
          child: BeeSyncStatus(
              state: state,
              title: l.mineSyncTitle,
              label: label,
              detail: error?.toString(),
              onTap: local
                  ? null
                  : () => open(
                      cfg.valueOrNull?.type == CloudBackendType.beecountCloud
                          ? const BeeCountCloudSyncPage()
                          : const CloudSyncPage())))
    ]);
  }
}
