import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/feature_highlight_providers.dart';
import '../../providers/theme_providers.dart';
import '../../skins/premium_skins.dart';
import '../../styles/header_skins.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'appearance/bindings/skin_choices.dart';
import 'appearance/skin_editor.dart';
import 'appearance/skin_store_actions.dart';

class HeaderSkinPage extends ConsumerStatefulWidget {
  const HeaderSkinPage({super.key});

  @override
  ConsumerState<HeaderSkinPage> createState() => _HeaderSkinPageState();
}

class _HeaderSkinPageState extends ConsumerState<HeaderSkinPage> {
  final _selected = GlobalKey();
  var _filter = HeaderSkinFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      markAnchorVisited(ref, 'header_skin');
      final selected = _selected.currentContext;
      if (selected != null) {
        Scrollable.ensureVisible(selected,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      }
    });
  }

  List<HeaderSkin> _freeInGroup(HeaderSkinGroup group) => kVisibleHeaderSkins
      .where((skin) =>
          skin.group == group &&
          switch (_filter) {
            HeaderSkinFilter.all => true,
            HeaderSkinFilter.animated => skin.isAnimated,
            HeaderSkinFilter.static_ => !skin.isAnimated,
          })
      .toList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final runtime = ref.watch(premiumSkinsProvider);
    final header =
        BeePageHeader(title: l.headerSkinTitle, leading: const BackButton());
    if (!ref.watch(headerSkinsEnabledProvider)) {
      return V4PageScaffold(body: header);
    }
    final active = activeSkinId(ref.watch(headerSkinProvider), runtime);
    final primary = ref.watch(primaryColorProvider);
    final paidSkins = runtime.skins;
    final showAutumn =
        paidSkins.isNotEmpty && _filter != HeaderSkinFilter.static_;
    final today = Theme.of(context);
    final price = runtime.price;
    final autumnCaption = runtime.owned
        ? skinText(context, '已购 · 6 款', 'Owned · 6 skins')
        : skinText(context, '6 款合集', '6-skin collection');
    final caption = !runtime.owned && price != null && runtime.salesEnabled
        ? '$autumnCaption · $price'
        : autumnCaption;

    Widget grid(Iterable<BeeSkinChoice> items, {bool locked = false}) =>
        LayoutBuilder(builder: (_, bounds) {
          final width = (bounds.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final item in items)
              SizedBox(
                key: item.id == active ? _selected : null,
                width: width,
                child: _SkinTile(
                  key: ValueKey('skin-card-${item.id}'),
                  item: item,
                  selected: item.id == active,
                  locked: locked,
                  onTap: () => showSkinEditor(context, item.id,
                      editingActive: item.id == active),
                ),
              ),
          ]);
        });

    Widget freeGroup(String title, Iterable<String> ids) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeeSectionLabel(title),
            grid(
                ids.map((id) => skinChoice(context, id: id, primary: primary))),
            const SizedBox(height: 16),
          ],
        );

    Widget autumnGroup() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(skinText(context, '秋日手记', 'Autumn Journal'),
                          key: const ValueKey('autumn-collection-title'),
                          style: today.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(caption, style: today.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SkinStoreActions(),
              ],
            ),
            grid(
              paidSkins.map((skin) => BeeSkinChoice(
                  id: skin.id,
                  name: premiumSkinName(context, skin),
                  preview: skin.preview(context))),
              locked: !runtime.owned,
            ),
            const SizedBox(height: 16),
          ],
        );

    return V4PageScaffold(
      body: Column(children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 4),
          child: BeeSegmented<HeaderSkinFilter>(
            items: [
              BeeSegment(HeaderSkinFilter.all, l.headerSkinTabAll),
              BeeSegment(HeaderSkinFilter.animated, l.headerSkinTabAnimated),
              BeeSegment(HeaderSkinFilter.static_, l.headerSkinTabStatic),
            ],
            value: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('skin-picker-scroll'),
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_filter != HeaderSkinFilter.animated)
                  freeGroup(l.headerSkinGroupBasic, const [kHeaderSkinNone]),
                for (final group in kHeaderSkinGroupOrder) ...[
                  if (_freeInGroup(group).isNotEmpty)
                    freeGroup(skinGroupLabel(l, group),
                        _freeInGroup(group).map((skin) => skin.id)),
                  if (showAutumn && group == HeaderSkinGroup.anniversary)
                    autumnGroup(),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    super.key,
    required this.item,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final BeeSkinChoice item;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final card = BeeCardTheme.of(context);
    final inUse = skinText(context, '使用中', 'In use');
    final edit = skinText(context, '调节', 'Adjust');
    final label = [
      item.name,
      if (selected) ...[inUse, edit],
      if (locked) skinText(context, '未购买，可试穿', 'Locked, preview available'),
    ].join(' · ');
    Widget badge(String title) => DecoratedBox(
          decoration: BoxDecoration(
              color: card.soft.withValues(alpha: 1),
              borderRadius: BorderRadius.circular(7)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(title, style: theme.textTheme.labelSmall),
          ),
        );
    final radius = BorderRadius.circular(17);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: card.overlay,
        shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: selected ? colors.primary : card.divider)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.76,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(fit: StackFit.expand, children: [
                      item.preview,
                      if (item.cornerBadge != null)
                        Positioned(
                            top: 6, left: 6, child: badge(item.cornerBadge!)),
                      if (selected || locked)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: selected
                              ? badge(inUse)
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: card.overlay,
                                      shape: BoxShape.circle),
                                  child: const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Icon(Icons.lock_outline, size: 13),
                                  ),
                                ),
                        ),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 3, 5),
                  child: Row(children: [
                    Expanded(
                      child: Text(item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 3),
                      const BeeLineIcon('SlidersHorizontal', size: 13),
                      const SizedBox(width: 3),
                      Text(edit, style: theme.textTheme.labelSmall),
                    ],
                  ]),
                ),
                if (item.animated || item.fixedPalette)
                  Wrap(spacing: 4, runSpacing: 3, children: [
                    if (item.animated) badge(l.headerSkinAnimatedBadge),
                    if (item.fixedPalette) badge(l.headerSkinFixedPalette),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
