import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show CloudBackendType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../../models/ledger_display_item.dart';
import '../../cloud/transactions_sync_manager.dart';
import '../../cloud/sync_service.dart';
import '../../cloud/sync/sync_engine.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../cloud/member_list_page.dart';
import '../cloud/member_stats_page.dart';
import '../cloud/join_shared_ledger_page.dart';
import '../budget/budget_page.dart';
import '../../utils/currencies.dart';
import '../../services/attachment_service.dart';
import '../../services/system/logger_service.dart';
import '../../utils/format_utils.dart';
import '../../services/billing/post_processor.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/budget_providers.dart';
import '../../widget/widget_manager.dart';

import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../widgets/currency/currency_picker_sheet.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';

part '../../presentation/v4/bindings/ledger_actions.dart';
part '../../presentation/v4/bindings/ledger_overview.dart';

class LedgersPageNew extends ConsumerStatefulWidget {
  const LedgersPageNew({super.key, this.autoOpenCreateDialog = false});
  final bool autoOpenCreateDialog;
  @override
  ConsumerState<LedgersPageNew> createState() => _LedgersPageNewState();
}

class _LedgersPageNewState extends ConsumerState<LedgersPageNew>
    with _LedgerActions, _LedgerOverview {
  @override
  bool _isRestoring = false;
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenCreateDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCreateLedgerDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentId = ref.watch(currentLedgerIdProvider);
    final local = ref.watch(localLedgersProvider);
    final remote = ref.watch(remoteLedgersProvider);
    ref.listen<ImportProgress>(importProgressProvider, (previous, next) {
      if (previous?.running == true &&
          next.isJustCompleted &&
          next.ledgerId != null) {
        PostProcessor.sync(ref, ledgerId: next.ledgerId!);
      }
    });
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.ledgersTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.ledgersCreate,
                icon: const BeeLineIcon('Plus'),
                onPressed: () => _showCreateLedgerDialog(context)),
            BeeIconButton(
                label: MaterialLocalizations.of(context)
                    .refreshIndicatorSemanticLabel,
                icon: const BeeLineIcon('RefreshCw'),
                onPressed: () =>
                    ref.read(ledgerListRefreshProvider.notifier).state++),
          ]),
      Expanded(
          child: _buildProgressiveList(context, ref, currentId, local, remote)),
    ]));
  }
}
