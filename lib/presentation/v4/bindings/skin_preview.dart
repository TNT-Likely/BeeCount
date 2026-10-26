import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/settings/header_skin_page.dart';
import '../../../providers/theme_providers.dart';
import 'skin_choices.dart';

/// Reads production identity and preview. Writes require the explicit page entry.
class LiveSkinPreview extends ConsumerWidget {
  const LiveSkinPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('当前真实皮肤（只读）'),
      const SizedBox(height: 8),
      BeeSkinCard(
          item: skinChoice(context,
              id: ref.watch(headerSkinProvider),
              primary: ref.watch(primaryColorProvider)),
          selected: true,
          animatedLabel: l.headerSkinAnimatedBadge,
          fixedLabel: l.headerSkinFixedPalette,
          onTap: null),
      const SizedBox(height: 8),
      BeeButton(
          label: '打开真实皮肤设置',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const HeaderSkinPage()))),
    ]);
  }
}
