import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../cloud/cloud_version_policy.dart';
import '../l10n/app_localizations.dart';

/// 统一的 BeeCount Cloud 版本匹配提示卡（用于云同步页与首页一次性提醒）。
class CloudVersionNoticeCard extends StatelessWidget {
  const CloudVersionNoticeCard({
    super.key,
    required this.compatibility,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryBusy = false,
    this.compact = false,
  });

  final CloudVersionCompatibility compatibility;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryBusy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isErr = compatibility.isBlocking;
    final bg = isErr
        ? (isDark ? const Color(0x26E5484D) : const Color(0xFFFFF1F0))
        : (isDark ? const Color(0x24F5A623) : const Color(0xFFFFF8E6));
    final border = isErr
        ? (isDark ? const Color(0x61E5484D) : const Color(0xFFF5B8B4))
        : (isDark ? const Color(0x5CF5A623) : const Color(0xFFF5D68A));
    final fg = isErr
        ? (isDark ? const Color(0xFFFF9C9E) : const Color(0xFF9C2222))
        : (isDark ? const Color(0xFFFFD679) : const Color(0xFF8C5600));
    final iconColor = isErr
        ? (isDark ? const Color(0xFFFF6B6E) : const Color(0xFFD93F3F))
        : (isDark ? const Color(0xFFFFB833) : const Color(0xFFD98200));

    final title = _title(l10n);
    final desc = _description(l10n);
    final chips = _metaChips(l10n);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: EdgeInsets.all(compact ? 13 : 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: BeeLineIcon(
                  isErr ? 'CircleAlert' : 'TriangleAlert',
                  size: 19,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        height: 1.35,
                      ),
                    ),
                    if (!compact && chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final chip in chips)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: fg.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                chip,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                  color: fg,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: fg.withValues(alpha: 0.94),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BeeButton(
                label: primaryLabel,
                loading: primaryBusy,
                onPressed: primaryBusy ? null : onPrimary,
              ),
              if (secondaryLabel != null && onSecondary != null)
                compact
                    ? TextButton(
                        onPressed: onSecondary,
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          secondaryLabel!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : BeeButton(
                        label: secondaryLabel!,
                        kind: BeeButtonKind.secondary,
                        onPressed: onSecondary,
                      ),
            ],
          ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (compatibility.status) {
        CloudVersionMatchStatus.upgradeCloudRequired => compact
            ? l10n.cloudVersionHomePauseCloudTitle
            : l10n.cloudVersionRequireCloudTitle,
        CloudVersionMatchStatus.upgradeCloudRecommended =>
          l10n.cloudVersionRecommendCloudTitle,
        CloudVersionMatchStatus.upgradeAppRequired => compact
            ? l10n.cloudVersionHomePauseAppTitle
            : l10n.cloudVersionRequireAppTitle,
        CloudVersionMatchStatus.upgradeAppRecommended =>
          l10n.cloudVersionRecommendAppTitle,
        _ => '',
      };

  String _description(AppLocalizations l10n) {
    final serverVer = compatibility.serverVersion ?? '-';
    final target = compatibility.targetVersion ?? '-';
    return switch (compatibility.status) {
      CloudVersionMatchStatus.upgradeCloudRequired => compact
          ? l10n.cloudVersionHomePauseCloudDesc(serverVer, target)
          : l10n.cloudVersionRequireCloudDesc(target),
      CloudVersionMatchStatus.upgradeCloudRecommended => compact
          ? l10n.cloudVersionHomeRecommendCloudDesc(serverVer, target)
          : l10n.cloudVersionRecommendCloudDesc(target),
      CloudVersionMatchStatus.upgradeAppRequired => compact
          ? l10n.cloudVersionHomePauseAppDesc(serverVer, target)
          : l10n.cloudVersionRequireAppDesc(serverVer, target),
      CloudVersionMatchStatus.upgradeAppRecommended => compact
          ? l10n.cloudVersionHomeRecommendAppDesc(serverVer, target)
          : l10n.cloudVersionRecommendAppDesc(target),
      _ => '',
    };
  }

  List<String> _metaChips(AppLocalizations l10n) {
    final chips = <String>[];
    if (compatibility.appVersion != null &&
        compatibility.appVersion!.isNotEmpty) {
      chips.add('App v${compatibility.appVersion}');
    }
    if (compatibility.serverVersion != null &&
        compatibility.serverVersion!.isNotEmpty) {
      chips.add('Cloud v${compatibility.serverVersion}');
    }
    final target = compatibility.targetVersion;
    if (target != null && target.isNotEmpty) {
      chips.add(switch (compatibility.status) {
        CloudVersionMatchStatus.upgradeCloudRequired =>
          l10n.cloudVersionChipMinCloud(target),
        CloudVersionMatchStatus.upgradeCloudRecommended =>
          l10n.cloudVersionChipRecCloud(target),
        CloudVersionMatchStatus.upgradeAppRequired =>
          l10n.cloudVersionChipMinApp(target),
        CloudVersionMatchStatus.upgradeAppRecommended =>
          l10n.cloudVersionChipRecApp(target),
        _ => '',
      });
    }
    return chips.where((c) => c.isNotEmpty).toList();
  }
}
