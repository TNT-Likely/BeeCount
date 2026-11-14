import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local, explicitly chosen layout. Existing installs keep the long card.
const homeCompactSummaryKey = 'v4_home_compact_summary';
final homeCompactSummaryProvider = StateProvider<bool>((ref) => false);
final homeSummaryPreferenceInitProvider = FutureProvider<void>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  ref.read(homeCompactSummaryProvider.notifier).state =
      preferences.getBool(homeCompactSummaryKey) ?? false;
});

Future<void> setHomeCompactSummary(WidgetRef ref, bool compact) async {
  // Finish restoration before a user choice, so late initialization cannot
  // overwrite the click. Startup also awaits this before preparing Home.
  await ref.read(homeSummaryPreferenceInitProvider.future);
  if (!ref.context.mounted) return;
  ref.read(homeCompactSummaryProvider.notifier).state = compact;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(homeCompactSummaryKey, compact);
}
