import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const homeCompactSummaryKey = 'v4_home_compact_summary';
const homeSummaryStyleKey = 'v4_home_summary_style';
final homeSummaryStyleProvider =
    StateProvider<BeeHomeSummaryStyle>((ref) => BeeHomeSummaryStyle.full);
final homeSummaryPreferenceInitProvider = FutureProvider<void>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  final style = switch (preferences.get(homeSummaryStyleKey)) {
    'full' => BeeHomeSummaryStyle.full,
    'compact' => BeeHomeSummaryStyle.compact,
    'sliding' => BeeHomeSummaryStyle.sliding,
    _ => preferences.get(homeCompactSummaryKey) == true
        ? BeeHomeSummaryStyle.compact
        : BeeHomeSummaryStyle.full,
  };
  ref.read(homeSummaryStyleProvider.notifier).state = style;
});

Future<void> setHomeSummaryStyle(
    WidgetRef ref, BeeHomeSummaryStyle style) async {
  // Finish restoration before a user choice, so late initialization cannot
  // overwrite the click. Startup also awaits this before preparing Home.
  await ref.read(homeSummaryPreferenceInitProvider.future);
  if (!ref.context.mounted) return;
  ref.read(homeSummaryStyleProvider.notifier).state = style;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(homeSummaryStyleKey, style.name);
}
