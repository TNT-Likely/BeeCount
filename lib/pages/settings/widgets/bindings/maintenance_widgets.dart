import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../styles/tokens.dart';
import '../../../../utils/ui_scale_extensions.dart';
import '../../../../widget/widget_spec.dart';
import '../../../../widget/widget_preview.dart';
import 'package:beecount_business_ui/maintenance.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';
import '../../data/bindings/maintenance_access.dart';

/// All supported home-screen sizes, rendered with the same cards as the launcher.
class MaintenanceWidgetsControls extends ConsumerWidget {
  const MaintenanceWidgetsControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(displaySkinPrimaryColorProvider);
    final redForIncome = ref.watch(incomeExpenseColorSchemeProvider);
    final dark = BeeTokens.isDark(context);
    final android =
        ref.watch(maintenancePlatformProvider) == TargetPlatform.android;

    return V4PageScaffold(
      body: Column(
        children: [
          BeePageHeader(
            title: l10n.widgetManagement,
            subtitle: l10n.widgetManagementDesc,
            leading: const BackButton(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                _buildGalleryHeader(context, ref, l10n),
                SizedBox(height: 10.0.scaled(context, ref)),

                for (final spec in WidgetSpec.catalog) ...[
                  _galleryCard(l10n, spec,
                      android: android,
                      color: primaryColor,
                      dark: dark,
                      redForIncome: redForIncome),
                  if (spec != WidgetSpec.catalog.last)
                    SizedBox(height: 12.0.scaled(context, ref)),
                ],
                SizedBox(height: 20.0.scaled(context, ref)),

                // 添加指引
                _buildAddGuideSection(context, ref, l10n),
                SizedBox(height: 16.0.scaled(context, ref)),

                // 快捷记账说明
                _buildQuickEntrySection(context, ref, l10n),
                SizedBox(height: 16.0.scaled(context, ref)),

                // 说明文字
                _buildDescriptionSection(context, ref, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // 组件库画廊
  // -------------------------------------------------------------------

  Widget _buildGalleryHeader(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.0.scaled(context, ref)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.widgetGalleryTitle,
            style: TextStyle(
              fontSize: 18.0.scaled(context, ref),
              fontWeight: FontWeight.w700,
              color: BeeTokens.textPrimary(context),
            ),
          ),
          SizedBox(height: 4.0.scaled(context, ref)),
          Text(
            l10n.widgetGalleryDesc,
            style: TextStyle(
              fontSize: 12.5.scaled(context, ref),
              color: BeeTokens.textTertiary(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryCard(
    AppLocalizations l,
    WidgetSpec spec, {
    required bool android,
    required Color color,
    required bool dark,
    required bool redForIncome,
  }) {
    final (title, subtitle) = switch (spec.type) {
      HWType.glance => (l.widgetGalleryGlanceTitle, l.widgetGalleryGlanceDesc),
      HWType.netWorth => (l.accountTotalBalance, l.widgetGalleryNetWorthDesc),
      HWType.quickAdd => (
          l.widgetGalleryQuickAddTitle,
          l.widgetGalleryQuickAddDesc
        ),
      HWType.budget => (l.budgetMonthlyBudget, l.widgetGalleryBudgetDesc),
      HWType.recent => (l.widgetRecentTransactions, l.widgetGalleryRecentDesc),
      HWType.dashboard => (
          l.widgetGalleryDashboardTitle,
          l.widgetGalleryDashboardDesc
        ),
      HWType.consumptionRhythm => (
          l.widgetConsumptionRhythmTitle,
          l.widgetGalleryConsumptionRhythmDesc
        ),
      HWType.beeTrail => (l.widgetBeeTrailTitle, l.widgetGalleryBeeTrailDesc),
    };
    final sizeLabel = switch (spec.size) {
      HWSize.small => l.widgetSizeSmall,
      HWSize.medium => l.widgetSizeMedium,
      HWSize.large => l.widgetSizeLarge,
    };
    final size = spec.canvasSize(android: android);
    return BeeMaintenanceWidgetCard(
        title: title,
        subtitle: subtitle,
        sizeLabel: sizeLabel,
        previewSize: size,
        preview: buildWidgetPreview(
            spec: spec,
            canvas: size,
            l: l,
            dark: dark,
            themeColor: color,
            redForIncome: redForIncome));
  }

  Widget _buildAddGuideSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return BeeMaintenanceGuide(
        title: l10n.howToAddWidget,
        steps: ref.watch(maintenancePlatformProvider) == TargetPlatform.iOS
            ? [
                l10n.iosWidgetStep1,
                l10n.iosWidgetStep2,
                l10n.iosWidgetStep3,
                l10n.iosWidgetStep4
              ]
            : [
                l10n.androidWidgetStep1,
                l10n.androidWidgetStep2,
                l10n.androidWidgetStep3,
                l10n.androidWidgetStep4
              ]);
  }

  Widget _buildQuickEntrySection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return BeeMaintenanceInfo(
        title: l10n.widgetQuickEntryTitle,
        message: l10n.widgetQuickEntryDesc,
        icon: const BeeLineIcon('MousePointerClick', size: 22));
  }

  Widget _buildDescriptionSection(
          BuildContext context, WidgetRef ref, AppLocalizations l10n) =>
      BeeMaintenanceInfo(
          title: l10n.aboutWidget,
          message: l10n.widgetDescription,
          icon: const BeeLineIcon('Info', size: 22));
}
