import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../skins/premium_skins.dart';
import '../../shared/branding/bee_artwork.dart';
import '../../shared/navigation/ledger_tab_bar.dart';

/// A sample ledger inside the same scene and navigation painters used by the App.
class SkinTrialPage extends StatefulWidget {
  const SkinTrialPage({
    super.key,
    required this.skin,
    required this.appearance,
    required this.initialTone,
    required this.onToneChanged,
  });

  final PremiumSkin skin;
  final SkinAppearance appearance;
  final Brightness initialTone;
  final ValueChanged<Brightness> onToneChanged;

  @override
  State<SkinTrialPage> createState() => _SkinTrialPageState();
}

class _SkinTrialPageState extends State<SkinTrialPage> {
  static const _ledgerSize = Size(390, 844);
  late Brightness _tone = widget.initialTone;

  void _switchTone(Brightness value) {
    setState(() => _tone = value);
    widget.onToneChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final base =
        _tone == Brightness.light ? ThemeData.light() : ThemeData.dark();
    return Scaffold(
      key: const ValueKey('skin-preview-full'),
      appBar: AppBar(
        leading: const CloseButton(key: ValueKey('skin-preview-close')),
        title: Text(premiumSkinName(context, widget.skin)),
        actions: [
          for (final tone in Brightness.values)
            IconButton(
              key: ValueKey('skin-preview-${tone.name}'),
              tooltip: tone == Brightness.light
                  ? l.skinPreviewLight
                  : l.skinPreviewDark,
              isSelected: _tone == tone,
              onPressed: () => _switchTone(tone),
              icon: Icon(tone == Brightness.light
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              selectedIcon: Icon(tone == Brightness.light
                  ? Icons.light_mode
                  : Icons.dark_mode),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
          child: Center(
            child: AspectRatio(
              aspectRatio: _ledgerSize.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: _ledgerSize,
                    child: Theme(
                      data: base,
                      child: Builder(
                          builder: (context) => widget.skin.scene(
                                context,
                                widget.appearance,
                                const _TrialLedger(),
                                0,
                              )),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrialLedger extends StatelessWidget {
  const _TrialLedger();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = [
      (Icons.restaurant_outlined, l.skinPreviewLunch, '−28.00'),
      (Icons.train_outlined, l.skinPreviewMetro, '−4.00'),
      (Icons.coffee_outlined, l.skinPreviewCoffee, '−18.50'),
      (Icons.work_outline, l.skinPreviewIncome, '+3,000.00'),
    ];
    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 75),
                child: Row(children: [
                  BeeIcon(size: 27, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.homeAppTitle, style: theme.textTheme.titleMedium),
                      Text(l.skinPreviewLedger,
                          style: theme.textTheme.bodySmall),
                    ],
                  )),
                  const Icon(Icons.search, size: 21),
                  const SizedBox(width: 9),
                  const Icon(Icons.more_horiz, size: 21),
                ]),
              )),
              SliverToBoxAdapter(
                  child: BeeSummaryCard(
                title: '${l.homeYear(2026)} ${l.homeMonth('12')}',
                amountLabel: l.v4HomeMonthExpense,
                amount: '50.50',
                prefix: '¥',
                incomeLabel: l.v4HomeMonthIncome,
                income: '3,000.00',
                expenseLabel: l.v4HomeMonthBalance,
                expense: '2,949.50',
                hidden: false,
                budget: BeeBudgetStrip(
                  label: '${l.budgetMonthlyBudget} ¥500.00',
                  remaining: '${l.budgetRemaining} ¥449.50',
                  progress: 50.50 / 500,
                ),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 9)),
              SliverFillRemaining(
                  hasScrollBody: false,
                  child: BeeSurface(
                    padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.v4HomeAllTransactions,
                              style: theme.textTheme.titleMedium),
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                Icon(row.$1,
                                    size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 9),
                                Expanded(child: Text(row.$2)),
                                Text(row.$3,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                        ]),
                  )),
            ],
          ),
        ),
      ),
      const SizedBox(height: 7),
      LedgerTabBar(
        key: const ValueKey('skin-preview-dock'),
        currentIndex: 0,
        primaryColor: theme.colorScheme.primary,
        isDark: theme.brightness == Brightness.dark,
        bottomPadding: 0,
        l10n: l,
        previewPaidSkin: true,
      ),
    ]);
  }
}
