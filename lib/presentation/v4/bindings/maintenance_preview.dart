import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/maintenance.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/maintenance_providers.dart';
import '../../../services/system/logger_service.dart';
import 'maintenance_access.dart';

/// Queries only existing SQLite rows; gallery does not scan or delete files.
final maintenanceDbPreviewProvider =
    FutureProvider.autoDispose<({int db, int sync})>((ref) async {
  final scanner = ref.read(orphanScannerProvider);
  final groups = await Future.wait([
    scanner.scanBudgetMissingLedger(),
    scanner.scanAttachmentMissingTx(),
    scanner.scanTxTagMissingTx(),
    scanner.scanTxTagMissingTag(),
    scanner.scanTxMissingAccount(),
    scanner.scanTxMissingCategory(),
    scanner.scanCategoryMissingParent(),
    scanner.scanBudgetMissingCategory(),
    scanner.scanSharedCategoryMissingParent(),
    scanner.scanTxTagOverrideMissingTx()
  ]);
  final sync = await scanner.scanLocalChangeMissingEntity();
  return (
    db: groups.fold<int>(0, (n, rows) => n + rows.length),
    sync: sync.length
  );
});

class MaintenancePreview extends ConsumerStatefulWidget {
  const MaintenancePreview({super.key});
  @override
  ConsumerState<MaintenancePreview> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<MaintenancePreview> {
  late LoggerService source;
  @override
  void initState() {
    super.initState();
    source = ref.read(maintenanceLoggerProvider);
    source.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    source.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeMaintenanceInfo(
          title: l.logCenterTitle,
          message: '${l.logCenterTotal}: ${source.logs.length}',
          icon: const BeeLineIcon('FileText', size: 22)),
      const SizedBox(height: 12),
      ref.watch(maintenanceDbPreviewProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Text(l.commonFailed),
          data: (counts) => BeeMaintenanceInfo(
              title: l.maintenanceOrphanGroupDb,
              message:
                  '${l.maintenanceOrphanSummary(counts.db)}\n${l.maintenanceOrphanGroupSync}: ${counts.sync}',
              icon: const BeeLineIcon('Database', size: 22)))
    ]);
  }
}
