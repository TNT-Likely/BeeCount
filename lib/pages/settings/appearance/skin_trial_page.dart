import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../skins/premium_skins.dart';
import '../../shared/branding/bee_artwork.dart';

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
              aspectRatio: 390 / 844,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: SizedBox(
                height: 75,
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
        const SizedBox(height: 7),
        const _TrialDock(),
      ]),
    );
  }
}

class _TrialDock extends ConsumerWidget {
  const _TrialDock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final runtime = ref.watch(premiumSkinsProvider);
    final artwork = runtime.navigationArtwork(context);
    final height = runtime.navigationDecorationHeight(context);
    final colors = Theme.of(context).colorScheme;
    final tabs = [
      (Icons.receipt_long_outlined, l.tabHome),
      (Icons.pie_chart_outline_rounded, l.tabInsights),
      (Icons.add_circle_outline, l.tabRecord),
      (Icons.account_balance_wallet_outlined, l.tabAssets),
      (Icons.person_outline, l.tabMine),
    ];
    return ClipRRect(
      key: const ValueKey('skin-preview-dock'),
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: Color.alphaBlend(
            colors.primary.withValues(alpha: .07), colors.surface),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 50,
            child: Stack(fit: StackFit.expand, children: [
              if (height == 0 && artwork != null) IgnorePointer(child: artwork),
              Row(children: [
                for (final tab in tabs)
                  Expanded(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(tab.$1,
                            size: 18,
                            color: tab == tabs.first
                                ? colors.primary
                                : colors.onSurfaceVariant),
                        Text(tab.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: colors.onSurface)),
                      ])),
              ]),
            ]),
          ),
          if (height > 0 && artwork != null)
            SizedBox(
              key: const ValueKey('skin-preview-decoration'),
              height: height,
              width: double.infinity,
              child: IgnorePointer(child: artwork),
            ),
        ]),
      ),
    );
  }
}
