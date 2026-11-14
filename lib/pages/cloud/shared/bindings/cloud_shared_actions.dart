import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/shared_ledger_providers.dart';
import '../../../../providers/sync_providers.dart';
import '../../../../providers/database_providers.dart';

/// Same service requests and refreshes as the original shared-ledger helpers.
/// A route may disappear while a request completes; only its UI work is cancelled.
Future<BeeCountCloudInvite> cloudSharedCreateInvite(WidgetRef ref,
    {required String ledgerId,
    required int expiresInHours,
    required bool Function() active}) async {
  final cloud = await ref.read(beecountCloudProviderInstance.future);
  if (cloud == null) throw StateError('BeeCount Cloud not configured');
  final invite = await cloud.createInvite(
      ledgerId: ledgerId, role: 'editor', expiresInHours: expiresInHours);
  if (active()) ref.invalidate(ledgerInvitesProvider(ledgerId));
  return invite;
}

Future<void> cloudSharedRemoveMember(WidgetRef ref,
    {required String ledgerId,
    required String userId,
    required bool Function() active}) async {
  final cloud = await ref.read(beecountCloudProviderInstance.future);
  if (cloud == null) throw StateError('BeeCount Cloud not configured');
  await cloud.removeMember(ledgerId: ledgerId, userId: userId);
  if (!active()) return;
  ref.invalidate(ledgerMembersProvider(ledgerId));
  try {
    final runtime = await ref.read(activeCloudRuntimeProvider.future);
    await runtime?.syncEngine?.syncLedgersFromServer();
  } catch (_) {
    // Same original recovery: next sync reconciles ledger metadata.
  }
  if (!active()) return;
  ref.invalidate(localLedgersProvider);
  ref.read(ledgerListRefreshProvider.notifier).state++;
  ref.invalidate(currentLedgerProvider);
}
