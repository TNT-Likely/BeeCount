import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/header_skins.dart';

BeeSkinChoice skinChoice(BuildContext context,
    {required String id, required Color primary}) {
  final l = AppLocalizations.of(context),
      skin = headerSkinById(id),
      dark = Theme.of(context).brightness == Brightness.dark;
  final previewColor = skin?.boundPrimary ?? primary;
  return BeeSkinChoice(
      id: id,
      name: skin?.nameOf(l) ?? l.headerSkinNone,
      animated: skin?.isAnimated ?? false,
      fixedPalette: skin?.hasFixedPalette ?? false,
      cornerBadge: skin?.badge,
      preview: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: ColoredBox(
              color: dark ? Colors.black : previewColor,
              child: skin?.builder(previewColor, dark) ??
                  const SizedBox.expand())));
}

String skinGroupLabel(AppLocalizations l, HeaderSkinGroup group) =>
    switch (group) {
      HeaderSkinGroup.anniversary => l.headerSkinGroupAnniversary,
      HeaderSkinGroup.gradient => l.headerSkinGroupGradient,
      HeaderSkinGroup.scene => l.headerSkinGroupScene,
      HeaderSkinGroup.pattern => l.headerSkinGroupPattern,
      HeaderSkinGroup.geometric => l.headerSkinGroupGeometric,
    };
