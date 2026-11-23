import 'dart:async';

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/sync/sync_engine.dart';
import '../../cloud/sync_service.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/attachment_service.dart';
import '../../utils/format_utils.dart';
import '../shared/selectors/ledger_selector_dialog.dart';

final transactionMoveAvailableProvider = FutureProvider<bool>((ref) async {
  ref.watch(syncStatusRefreshProvider);
  final config = await ref.watch(activeCloudConfigProvider.future);
  if (config.type == CloudBackendType.local) return true;
  if (config.type != CloudBackendType.beecountCloud) return false;
  final cloud = await ref.watch(beecountCloudProviderInstance.future);
  if (cloud == null) return false;
  try {
    final server = await cloud.fetchServerVersion().timeout(
          const Duration(seconds: 5),
        );
    return server.capabilities.contains('transaction_move_v1');
  } catch (_) {
    return false;
  }
});

Future<int?> showTransactionMove(
  BuildContext context,
  WidgetRef ref, {
  required int sourceLedgerId,
  required Set<int> transactionIds,
}) async {
  if (transactionIds.isEmpty) return null;
  final l = AppLocalizations.of(context);
  final repo = ref.read(repositoryProvider);
  if (repo is! LocalRepository) return null;
  try {
    final source = await repo.getLedgerById(sourceLedgerId);
    final ledgers = await repo.getAllLedgers();
    if (!context.mounted) return null;
    final targets = source == null
        ? <int>{}
        : ledgers
            .where((ledger) => canMoveTransactionsBetween(source, ledger))
            .map((ledger) => ledger.id)
            .toSet();
    if (source == null || targets.isEmpty) {
      showBeeToast(context, l.transactionMoveNoTarget, tone: BeeTone.warning);
      return null;
    }
    final targetId = await showLedgerSelector(
      context,
      candidates:
          ledgers.where((ledger) => targets.contains(ledger.id)).toList(),
      title: l.transactionMoveChooseLedger,
    );
    if (!context.mounted || targetId == null) return null;
    final target = ledgers.firstWhere((ledger) => ledger.id == targetId);
    final confirmed = await showBeeConfirm(
      context,
      title: l.transactionMoveConfirmTitle,
      message: l.transactionMoveConfirmMessage(
        transactionIds.length,
        translateLedgerName(context, source.name),
        translateLedgerName(context, target.name),
      ),
      confirmLabel: l.transactionMoveCommit,
      cancelLabel: l.commonCancel,
    );
    if (!context.mounted || !confirmed) return null;

    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: BeeDialog(
          title: Text(l.transactionMoveWorking),
          content: const LinearProgressIndicator(),
        ),
      ),
    );
    unawaited(navigator.push(progress));
    late final int count;
    try {
      final config = await ref.read(activeCloudConfigProvider.future);
      final sync = ref.read(syncServiceProvider);
      if (config.type == CloudBackendType.local &&
          sync is LocalOnlySyncService) {
        count = await repo.moveTransactionsLocally(
          sourceLedgerId: source.id,
          targetLedgerId: targetId,
          transactionIds: transactionIds,
        );
      } else if (config.type == CloudBackendType.beecountCloud &&
          sync is SyncEngine &&
          await ref.read(transactionMoveAvailableProvider.future)) {
        count = await sync.moveTransactionsInCloud(
          sourceLedgerId: source.id,
          targetLedgerId: targetId,
          transactionIds: transactionIds,
        );
      } else {
        throw TransactionMoveFailure.unsynced;
      }
    } finally {
      if (progress.isActive) navigator.removeRoute(progress);
    }
    if (!context.mounted) return targetId;
    ref.invalidate(countsForLedgerProvider(source.id));
    ref.invalidate(countsForLedgerProvider(targetId));
    ref.read(ledgerListRefreshProvider.notifier).state++;
    ref.read(statsRefreshProvider.notifier).state++;
    ref.read(budgetRefreshProvider.notifier).state++;
    ref.read(attachmentListRefreshProvider.notifier).state++;
    ref.read(tagListRefreshProvider.notifier).state++;
    updateAppWidget(ref, context);
    showBeeToast(context, l.transactionMoveDone(count), tone: BeeTone.success);
    return targetId;
  } catch (error) {
    if (!context.mounted) return null;
    final message = switch (error) {
      TransactionMoveFailure.awaitingConfirmation => l.transactionMovePending,
      TransactionMoveFailure.unsynced => l.transactionMoveUnsynced,
      TransactionMoveFailure.changed ||
      StateError() =>
        l.transactionMoveChanged,
      BeeCountCloudTransactionMoveException(statusCode: 404) =>
        l.transactionMoveUnsynced,
      BeeCountCloudTransactionMoveException(statusCode: 409) =>
        l.transactionMoveChanged,
      _ => l.transactionMoveFailed,
    };
    showBeeToast(context, message, tone: BeeTone.warning);
    return null;
  }
}
