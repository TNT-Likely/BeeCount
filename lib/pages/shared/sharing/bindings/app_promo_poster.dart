import 'package:beecount_business_ui/share_posters.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'poster_projection.dart';

class AppPromoPoster extends StatelessWidget {
  const AppPromoPoster(
      {super.key, required this.l10n, required this.primaryColor});
  final AppLocalizations l10n;
  final Color primaryColor;
  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
          child: BeeAppSharePoster(
              header:
                  posterHeader(l10n, primaryColor, 'OPEN SOURCE · BEECOUNT'),
              footer: posterFooter(l10n, qr: false),
              title: l10n.sharePosterSlogan.replaceFirst('，', '，\n'),
              accent: primaryColor,
              invitation: l10n.v4SharePosterPromoInvite,
              qr: posterQr(campaign: 'app_share'),
              tags: [
            l10n.appPromoTagOpenSource,
            l10n.appPromoTagFree
          ],
              features: [
            BeePromoFeature(
                l10n.sharePosterFeature1, const Icon(Icons.shield_outlined)),
            BeePromoFeature(l10n.sharePosterFeature2, const Icon(Icons.code)),
            BeePromoFeature(l10n.sharePosterFeature3,
                const Icon(Icons.auto_awesome_outlined)),
            BeePromoFeature(l10n.sharePosterFeature4,
                const Icon(Icons.camera_alt_outlined)),
            BeePromoFeature(
                l10n.sharePosterFeature5, const Icon(Icons.dark_mode_outlined)),
            BeePromoFeature(
                l10n.sharePosterFeature6, const Icon(Icons.cloud_outlined))
          ]));
}
