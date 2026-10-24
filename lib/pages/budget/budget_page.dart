import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/budget_overview.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../utils/currencies.dart';

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        overview = ref.watch(budgetOverviewProvider),
        ledger = ref.watch(currentLedgerProvider).asData?.value;
    final canEdit =
        ledger == null || !ledger.isShared || ledger.myRole == 'owner';
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.budgetTitle,
          leading: const BackButton(),
          actions: [
            if (canEdit)
              BeeIconButton(
                  label: l.commonAdd,
                  icon: const BeeLineIcon('Plus'),
                  onPressed: () => openBudgetEditor(context, ref))
          ]),
      Expanded(
          child: overview.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => BeeEmptyState(
                  title: 'Error: $error',
                  icon: const BeeLineIcon('CircleAlert', size: 36),
                  action: BeeButton(
                      label: l.v4RecordingRetry,
                      onPressed: () => ref.invalidate(budgetOverviewProvider))),
              data: (data) {
                if (data == null || data.totalBudget == null) {
                  return BeeEmptyState(
                      title: l.budgetEmptyHint,
                      icon: const BeeLineIcon('Wallet', size: 48),
                      action: canEdit
                          ? BeeButton(
                              label: l.budgetAddTotal,
                              icon: const BeeLineIcon('Plus', size: 18),
                              onPressed: () => openBudgetEditor(context, ref))
                          : null);
                }
                return BeePageBody(eager: true, children: [
                  BudgetOverviewContent(
                      overview: data,
                      symbol: getCurrencySymbol(ledger?.currency ?? 'CNY'),
                      canEdit: canEdit)
                ]);
              }))
    ]));
  }
}
