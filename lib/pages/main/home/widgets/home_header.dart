import 'dart:async';

import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/personalize_page.dart' show headerStyleProvider;
import '../../../../providers.dart';
import '../../../shared/branding/bee_artwork.dart';
import '../../../shared/appearance/primary_header.dart';
import 'home_overview.dart';

/// App-owned availability and callbacks around the controlled home identity and
/// summary. Navigation and financial data are not moved into presentation packages.
class HomeHeaderBinding extends ConsumerWidget {
  const HomeHeaderBinding(
      {super.key,
      required this.jumping,
      required this.onMonth,
      required this.onLedger,
      required this.onAI,
      required this.onSearch,
      required this.onTool});
  final bool jumping;
  final VoidCallback onMonth, onLedger, onAI, onSearch;
  final ValueChanged<String> onTool;

  String _styleLabel(AppLocalizations l, BeeHomeSummaryStyle style) =>
      switch (style) {
        BeeHomeSummaryStyle.full => l.v4HomeSummaryFull,
        BeeHomeSummaryStyle.compact => l.v4HomeSummaryCompact,
        BeeHomeSummaryStyle.sliding => l.v4HomeSummarySliding,
      };

  Future<void> _chooseSummaryStyle(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    final current = ref.read(homeSummaryStyleProvider);
    final options = [
      (
        BeeHomeSummaryStyle.full,
        l.v4HomeSummaryFullDescription,
        'PanelsTopLeft'
      ),
      (
        BeeHomeSummaryStyle.compact,
        l.v4HomeSummaryCompactDescription,
        'ChartPie'
      ),
      (
        BeeHomeSummaryStyle.sliding,
        l.v4HomeSummarySlidingDescription,
        'Ellipsis'
      ),
    ];
    final selected = await showBeeSheet<BeeHomeSummaryStyle>(context,
        title: l.v4HomeSummaryStyle, child: Builder(builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final accent = theme.colorScheme.primary;
      final surfaces = BeeCardTheme.of(sheetContext);
      return ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemCount: options.length,
          itemBuilder: (_, index) {
            final (style, description, icon) = options[index];
            final active = style == current;
            return Material(
                borderRadius: BorderRadius.circular(12),
                color: active
                    ? Color.alphaBlend(
                        accent.withValues(alpha: .14), surfaces.overlay)
                    : Colors.transparent,
                child: BeeMenuRow(
                    title: l.v4HomeSummaryStyleOption(_styleLabel(l, style)),
                    subtitle: description,
                    selected: active,
                    leading: Container(
                        height: 32,
                        decoration: BoxDecoration(
                            color: active ? surfaces.overlay : surfaces.soft,
                            borderRadius: BorderRadius.circular(9)),
                        child: Center(child: BeeLineIcon(icon, size: 17))),
                    trailing: active
                        ? CircleAvatar(
                            radius: 10,
                            backgroundColor: accent,
                            child: BeeLineIcon('Check',
                                size: 14, color: theme.colorScheme.onPrimary))
                        : BeeLineIcon('Circle',
                            size: 20, color: theme.dividerColor),
                    onTap: () => Navigator.of(sheetContext).pop(style)));
          });
    }));
    if (selected == null || selected == current || !context.mounted) return;
    await setHomeSummaryStyle(ref, selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final style = ref.watch(homeSummaryStyleProvider);
    ref.watch(headerStyleProvider);
    final ai = ref.watch(aiAssistantEnabledProvider).valueOrNull ?? true;
    return PrimaryHeader(
        title: '',
        showTitleSection: false,
        padding: const EdgeInsets.fromLTRB(17, 6, 17, 8),
        content: HomeOverview(
            jumping: jumping,
            onMonthTap: onMonth,
            onLedgerTap: onLedger,
            actions: [
              if (ai)
                Tooltip(
                    message: l.aiChatTitle,
                    child: TextButton.icon(
                        onPressed: onAI,
                        style: TextButton.styleFrom(
                            minimumSize: const Size(40, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            foregroundColor: Color.lerp(
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.onSurface,
                                .4)),
                        icon: const BeeLineIcon('Sparkles', size: 18),
                        label: const Text('AI',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)))),
              BeeIconButton(
                  label: l.homeSearch,
                  icon: const BeeLineIcon('Search', size: 21),
                  onPressed: onSearch),
              BeeMenuButton<String>(
                  label: l.commonMore,
                  onSelected: (value) {
                    if (value == 'summary-style') {
                      unawaited(_chooseSummaryStyle(context, ref));
                    } else {
                      onTool(value);
                    }
                  },
                  items: [
                    BeeMenuAction(
                        value: 'calendar',
                        label: l.calendarTitle,
                        icon: const BeeLineIcon('CalendarDays', size: 20)),
                    BeeMenuAction(
                        value: 'share',
                        label: l.v4HomeMonthShare,
                        icon: const BeeLineIcon('Share2', size: 20)),
                    BeeMenuAction(
                        value: 'annual',
                        label: l.annualReportTitle,
                        icon:
                            const BeeLineIcon('ChartNoAxesCombined', size: 20)),
                    BeeMenuAction(
                        value: 'ledgers',
                        label: l.homeManageLedgers,
                        icon: const BeeLineIcon('BookOpen', size: 20)),
                    BeeMenuAction(
                        value: 'summary-style',
                        label: l.v4HomeSummaryStyle,
                        icon: const BeeLineIcon('PanelsTopLeft', size: 20),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_styleLabel(l, style),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor)),
                          const SizedBox(width: 3),
                          const BeeLineIcon('ChevronRight', size: 13),
                        ])),
                    BeeMenuAction(
                        value: 'brand',
                        label: ref.watch(homeBrandVisibleProvider)
                            ? l.v4HomeBrandHide
                            : l.v4HomeBrandShow,
                        icon: BeeIcon(
                            size: 18,
                            color: Theme.of(context).colorScheme.primary)),
                    if (kDebugMode &&
                        const bool.fromEnvironment(
                            'BEECOUNT_V4_RECORDING')) ...[
                      const BeeMenuAction(
                          value: 'components',
                          label: 'V4 组件验收',
                          icon: BeeLineIcon('Grid2x2', size: 20)),
                      const BeeMenuAction(
                          value: 'theme',
                          label: '切换深浅色',
                          icon: BeeLineIcon('Palette', size: 20)),
                    ],
                  ]),
            ]));
  }
}
