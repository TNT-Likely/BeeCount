import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../widget/home_widget_view.dart';
import '../../widgets/ui/primary_header.dart';
import '../../providers.dart';

/// 小组件管理页面
class WidgetManagementPage extends ConsumerWidget {
  const WidgetManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.widgetManagement,
            showBack: true,
            leadingIcon: Icons.widgets_outlined,
            leadingPlain: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 预览区域
                _buildPreviewSection(context, ref, l10n, primaryColor),
                const SizedBox(height: 24),

                // 添加指引
                _buildAddGuideSection(context, l10n, theme),
                const SizedBox(height: 24),

                // 快捷记账说明
                _buildQuickEntrySection(context, l10n, theme),
                const SizedBox(height: 24),

                // 说明文字
                _buildDescriptionSection(context, l10n, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Color primaryColor,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.widgetPreview,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // 小组件预览
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 计算合适的显示尺寸，确保不溢出
                  // iOS: 364x169 (2.15:1), Android: 364x182 (2:1)
                  final maxWidth = constraints.maxWidth - 32;
                  final widgetWidth = 364.0;
                  final widgetHeight = Platform.isIOS ? 169.0 : 182.0;
                  final targetRatio = widgetWidth / widgetHeight;
                  final displayWidth = maxWidth.clamp(0.0, 400.0);
                  final displayHeight = displayWidth / targetRatio;

                  return Container(
                    width: displayWidth,
                    height: displayHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: widgetWidth,
                          height: widgetHeight,
                          child: HomeWidgetView(
                            todayExpense: '¥827.55',
                            todayIncome: '¥1,255.44',
                            monthExpense: '¥15,671.82',
                            monthIncome: '¥26,638.57',
                            themeColor: primaryColor,
                            redForIncome:
                                ref.watch(incomeExpenseColorSchemeProvider),
                            appName: l10n.appName,
                            monthSuffix: l10n.monthSuffix,
                            todayExpenseLabel: l10n.todayExpense,
                            todayIncomeLabel: l10n.todayIncome,
                            monthExpenseLabel: l10n.monthExpense,
                            monthIncomeLabel: l10n.monthIncome,
                            width: widgetWidth,
                            height: widgetHeight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.widgetPreviewDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddGuideSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.howToAddWidget,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (Platform.isIOS)
              _buildIOSGuide(context, l10n, theme)
            else
              _buildAndroidGuide(context, l10n, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSGuide(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final steps = [
      l10n.iosWidgetStep1,
      l10n.iosWidgetStep2,
      l10n.iosWidgetStep3,
      l10n.iosWidgetStep4,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAndroidGuide(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final steps = [
      l10n.androidWidgetStep1,
      l10n.androidWidgetStep2,
      l10n.androidWidgetStep3,
      l10n.androidWidgetStep4,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickEntrySection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.widgetQuickEntryTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.widgetQuickEntryDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.aboutWidget,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.widgetDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
