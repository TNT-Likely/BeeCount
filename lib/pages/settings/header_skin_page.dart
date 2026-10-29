import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../providers/feature_highlight_providers.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'appearance/bindings/skin_choices.dart';
import '../../styles/header_skins.dart';

class HeaderSkinPage extends ConsumerStatefulWidget {
  const HeaderSkinPage({super.key});
  @override
  ConsumerState<HeaderSkinPage> createState() => _HeaderSkinPageState();
}

class _HeaderSkinPageState extends ConsumerState<HeaderSkinPage> {
  HeaderSkinFilter filter = HeaderSkinFilter.all;
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) markAnchorVisited(ref, 'header_skin');
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        primary = ref.watch(primaryColorProvider),
        current = ref.watch(headerSkinProvider);
    final skins = kVisibleHeaderSkins
        .where((s) => switch (filter) {
              HeaderSkinFilter.all => true,
              HeaderSkinFilter.animated => s.isAnimated,
              HeaderSkinFilter.static_ => !s.isAnimated,
            })
        .toList();
    Widget grid(List<String> ids) => LayoutBuilder(
        builder: (context, box) => Wrap(spacing: 10, runSpacing: 10, children: [
              for (final id in ids)
                SizedBox(
                    width: (box.maxWidth - 10) / 2,
                    child: BeeSkinCard(
                        item: skinChoice(context, id: id, primary: primary),
                        selected: current == id,
                        animatedLabel: l.headerSkinAnimatedBadge,
                        fixedLabel: l.headerSkinFixedPalette,
                        onTap: () => applyHeaderSkin(ref, id)))
            ]));
    Widget group(String title, List<String> ids) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).hintColor))),
          grid(ids),
          const SizedBox(height: 20),
        ]);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.headerSkinTitle, leading: const BackButton()),
      Padding(
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 4),
          child: BeeSegmented<HeaderSkinFilter>(items: [
            BeeSegment(HeaderSkinFilter.all, l.headerSkinTabAll),
            BeeSegment(HeaderSkinFilter.animated, l.headerSkinTabAnimated),
            BeeSegment(HeaderSkinFilter.static_, l.headerSkinTabStatic)
          ], value: filter, onChanged: (v) => setState(() => filter = v))),
      Expanded(
          child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(17),
              children: [
            Text(l.headerSkinSubtitle,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 14),
            if (filter != HeaderSkinFilter.animated)
              group(l.headerSkinGroupBasic, [kHeaderSkinNone]),
            for (final category in kHeaderSkinGroupOrder)
              if (skins.any((s) => s.group == category))
                group(skinGroupLabel(l, category), [
                  for (final skin in skins.where((s) => s.group == category))
                    skin.id
                ]),
          ])),
    ]));
  }
}
