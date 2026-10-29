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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
              BeeMenuButton<
                  String>(label: l.commonMore, onSelected: onTool, items: [
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
                    icon: const BeeLineIcon('ChartNoAxesCombined', size: 20)),
                BeeMenuAction(
                    value: 'ledgers',
                    label: l.homeManageLedgers,
                    icon: const BeeLineIcon('BookOpen', size: 20)),
                BeeMenuAction(
                    value: 'brand',
                    label: ref.watch(homeBrandVisibleProvider)
                        ? l.v4HomeBrandHide
                        : l.v4HomeBrandShow,
                    icon: BeeIcon(
                        size: 18,
                        color: Theme.of(context).colorScheme.primary)),
                if (kDebugMode &&
                    const bool.fromEnvironment('BEECOUNT_V4_RECORDING')) ...[
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
