import 'dart:io';
import 'package:beecount_business_ui/share_posters.dart';
import 'package:beecount_ui/paper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/share_poster_types.dart';
import 'poster_projection.dart';

/// Original profile projection and image remain intact; only composition changes.
class UserProfilePoster extends StatelessWidget {
  const UserProfilePoster(
      {super.key,
      required this.data,
      required this.l10n,
      required this.primaryColor});
  final UserProfilePosterData data;
  final AppLocalizations l10n;
  final Color primaryColor;
  String get journey => data.recordDays >= 730
      ? l10n.userProfileJourneyYears((data.recordDays / 365).floor())
      : data.recordDays >= 365
          ? l10n.userProfileJourneyOneYear
          : data.recordDays >= 180
              ? l10n.userProfileJourneyHalfYear
              : data.recordDays >= 90
                  ? l10n.userProfileJourneyThreeMonths
                  : data.recordDays >= 30
                      ? l10n.userProfileJourneyOneMonth
                      : data.recordDays >= 7
                          ? l10n.userProfileJourneyOneWeek
                          : l10n.userProfileJourneyStart;
  @override
  Widget build(BuildContext context) {
    final fallback =
        const Icon(Icons.person_outline, size: 45, color: BeePaper.muted);
    return MediaQuery.withNoTextScaling(
        child: BeeProfileSharePoster(
            header: posterHeader(l10n, primaryColor, 'MY DAILY NOTES'),
            footer: posterFooter(l10n, campaign: 'user_profile'),
            accent: primaryColor,
            eyebrow: l10n.v4SharePosterProfileEyebrow,
            title: data.ledgerName,
            avatar: data.avatarPath == null
                ? fallback
                : Image.file(File(data.avatarPath!),
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
            days: NumberFormat.decimalPattern(l10n.localeName)
                .format(data.recordDays),
            daysCaption: l10n.v4SharePosterDayCaption,
            metrics: [
              BeePosterMetric(
                  l10n.userProfilePosterRecordCount,
                  NumberFormat.decimalPattern(l10n.localeName)
                      .format(data.recordCount)),
              BeePosterMetric(
                  l10n.userProfilePosterLedgerCount, '${data.ledgerCount}')
            ],
            journey: data.recordDays == 0
                ? l10n.userProfileJourneyStart
                : l10n.v4SharePosterProfileJourney,
            description: [
              if (data.firstRecordDate != null)
                l10n.userProfilePosterStartDate(DateFormat.yMd(l10n.localeName)
                    .format(data.firstRecordDate!)),
              '${l10n.v4SharePosterAverageRecords} ${(data.recordDays > 0 ? data.recordCount / data.recordDays : 0).toStringAsFixed(1)} ${l10n.sharePosterUnitCount}',
              journey
            ].join('\n')));
  }
}
