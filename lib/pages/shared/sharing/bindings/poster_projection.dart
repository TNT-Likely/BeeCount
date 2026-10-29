import 'package:beecount_business_ui/share_posters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/export/share_poster_types.dart';
import '../../../../services/data/category_service.dart';
import '../../../../utils/category_utils.dart';
import '../../../../utils/currencies.dart';
import '../../branding/bee_artwork.dart';

/// Formatting and original project links live at the App boundary, not in UI.
String posterMoney(double value, AppLocalizations l,
        {String currency = 'CNY', bool hidden = false}) =>
    hidden
        ? '**'
        : '${getCurrencySymbol(currency)}${NumberFormat('#,##0.00', l.localeName).format(value)}';

Widget posterQr({String? campaign}) => ColoredBox(
    color: Colors.white,
    child: QrImageView(
        data: campaign == null
            ? 'https://github.com/TNT-Likely/BeeCount'
            : 'https://github.com/TNT-Likely/BeeCount?utm_source=share_poster&utm_medium=qr_code&utm_campaign=$campaign',
        backgroundColor: Colors.white,
        padding: const EdgeInsets.all(5)));

Widget posterBrand(AppLocalizations l, Color accent,
        {double size = 54,
        bool centered = false,
        double? nameSize,
        double? captionSize}) =>
    BeePosterBrand(
        logo: Builder(
            builder: (context) => Theme(
                data: Theme.of(context).copyWith(brightness: Brightness.light),
                child: BeeIcon(color: accent, size: size))),
        name: l.sharePosterAppName,
        size: size,
        centered: centered,
        nameSize: nameSize,
        captionSize: captionSize);
Widget posterHeader(AppLocalizations l, Color accent, String caption) =>
    BeePosterHeader(brand: posterBrand(l, accent), caption: caption);
Widget posterFooter(AppLocalizations l, {String? campaign, bool qr = true}) =>
    BeePosterFooter(
        slogan: l.sharePosterSlogan,
        caption: l.appPromoFooterText,
        qr: qr ? posterQr(campaign: campaign) : null);

List<BeePosterCategory> posterCategories(
        BuildContext context, List<CategoryTotal> items, AppLocalizations l,
        {String currency = 'CNY',
        bool hidden = false,
        String kind = 'expense'}) =>
    items
        .map((item) => BeePosterCategory(
            name: CategoryUtils.getDisplayName(item.name, context, kind: kind),
            amount:
                posterMoney(item.total, l, currency: currency, hidden: hidden),
            percent: '${(item.percentage * 100).toStringAsFixed(1)}%',
            ratio: item.percentage,
            icon: Icon(CategoryService.getCategoryIcon(item.icon))))
        .toList();

String posterUnit(int value, String unit, AppLocalizations l) =>
    '$value${l.localeName.startsWith('zh') ? '' : ' '}$unit';
