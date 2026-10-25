import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../services/export/share_poster_data_service.dart';
import '../../../services/export/share_poster_types.dart';
import '../../../widgets/posters/app_promo_poster.dart';
import '../../../widgets/posters/ledger_summary_poster.dart';
import '../../../widgets/posters/month_summary_poster.dart';
import '../../../widgets/posters/user_profile_poster.dart';
import '../../../widgets/posters/year_summary_poster.dart';

final shareCardRendererProvider =
    Provider<ShareCardRenderer>((ref) => const ShareCardRenderer());

/// Reads the original poster projection and paints the original fixed-size art.
class ShareCardRenderer {
  const ShareCardRenderer();

  Future<Uint8List?> generate(
    BuildContext context,
    WidgetRef ref, {
    required PosterType type,
    required bool hideIncome,
    required int ledgerId,
    int? year,
    int? month,
  }) async {
    final data = SharePosterDataService(ref.read(repositoryProvider));
    final color = ref.read(primaryColorProvider);
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final Widget poster;
    switch (type) {
      case PosterType.appPromo:
        poster = AppPromoPoster(l10n: l, primaryColor: color);
      case PosterType.userProfile:
        final value = await data.calculateUserProfile(ledgerId: ledgerId);
        poster = UserProfilePoster(data: value, l10n: l, primaryColor: color);
      case PosterType.yearSummary:
        final value = await data.calculateYearSummary(
            ledgerId: ledgerId, year: year ?? now.year);
        poster = YearSummaryPoster(
            data: value, primaryColor: color, hideIncome: hideIncome);
      case PosterType.monthSummary:
        final value = await data.calculateMonthSummary(
            ledgerId: ledgerId,
            year: year ?? now.year,
            month: month ?? now.month);
        poster = MonthSummaryPoster(
            data: value, primaryColor: color, hideIncome: hideIncome);
      case PosterType.ledgerSummary:
        final value = await data.calculateLedgerSummary(ledgerId: ledgerId);
        poster = LedgerSummaryPoster(
            data: value, primaryColor: color, hideIncome: hideIncome);
    }
    if (!context.mounted) return null;
    return capture(context, poster);
  }

  /// The fixed export canvas is independent of UI text scaling and safe insets.
  /// Every exit removes the private overlay and disposes the native image.
  Future<Uint8List?> capture(BuildContext context, Widget poster,
      {double pixelRatio = 3}) async {
    final key = GlobalKey();
    final media = MediaQuery.of(context).copyWith(
      size: const Size(750, 1334),
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      textScaler: TextScaler.noScaling,
    );
    final entry = OverlayEntry(
        builder: (_) => Positioned(
              left: -10000,
              top: -10000,
              width: 750,
              height: 1334,
              child: MediaQuery(
                  data: media,
                  child: Material(
                      color: Colors.transparent,
                      child: RepaintBoundary(key: key, child: poster))),
            ));
    ui.Image? image;
    Overlay.of(context).insert(entry);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!context.mounted) return null;
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      image = await boundary.toImage(pixelRatio: pixelRatio);
      return (await image.toByteData(format: ui.ImageByteFormat.png))
          ?.buffer
          .asUint8List();
    } finally {
      image?.dispose();
      entry.remove();
      entry.dispose();
    }
  }
}
