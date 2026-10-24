import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/budget/budget_page.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../utils/currencies.dart';
import 'budget_overview.dart';

class LiveBudgetPreview extends ConsumerWidget {
  const LiveBudgetPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(budgetOverviewProvider),
        ledger = ref.watch(currentLedgerProvider).asData?.value,
        l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('真实预算（只读） · ${ledger?.name ?? ''}'),
      const SizedBox(height: 8),
      overview.when(
          loading: () => const Text('正在读取真实预算'),
          error: (_, __) => const Text('读取预算失败'),
          data: (value) => value?.totalBudget == null
              ? Text(l.budgetEmptyHint)
              : BudgetOverviewContent(
                  overview: value!,
                  symbol: getCurrencySymbol(ledger?.currency ?? 'CNY'),
                  canEdit: false,
                  showHomeSetting: false)),
      const SizedBox(height: 12),
      BeeButton(
          label: '打开真实预算管理',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const BudgetPage())))
    ]);
  }
}
