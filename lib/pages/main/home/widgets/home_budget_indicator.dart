import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/budget_providers.dart';
import '../../../../providers/theme_providers.dart';
import '../../../budget/budget_page.dart';

/// Same budget source and entry as the standard summary strip.
class HomeBudgetIndicator extends ConsumerWidget {
  const HomeBudgetIndicator({super.key, required this.diameter});
  final double diameter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final overview = ref.watch(budgetOverviewProvider);
    final hidden = ref.watch(hideAmountsProvider);
    final usage = overview.valueOrNull?.totalBudget;
    final exceeded = usage != null && usage.remaining < 0;
    final remaining = usage == null || !usage.rate.isFinite
        ? 0.0
        : (1 - usage.rate).clamp(0.0, 1.0);
    final String value, label;
    if (usage != null) {
      value = hidden
          ? '••'
          : exceeded
              ? l.v4HomeBudgetExceeded
              : NumberFormat.percentPattern(l.localeName).format(remaining);
      label = exceeded ? l.budgetTitle : l.v4HomeBudgetAvailable;
    } else if (overview.isLoading) {
      value = '—';
      label = l.budgetTitle;
    } else if (overview.hasError) {
      value = '!';
      label = l.v4RecordingRetry;
    } else {
      value = '+';
      label = l.budgetSetupAction;
    }
    return BeeHomeBudgetIndicator(
        diameter: diameter,
        value: value,
        label: label,
        progress: exceeded ? 1 : remaining,
        exceeded: exceeded,
        semanticLabel: '$value · $label',
        onTap: () {
          if (overview.hasError && usage == null) {
            ref.invalidate(budgetOverviewProvider);
          } else {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => const BudgetPage()));
          }
        });
  }
}
