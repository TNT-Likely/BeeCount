import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' show Account, Category, Transaction;
import '../../data/repositories/budget_repository.dart'
    show BudgetOverview, BudgetUsage, CategoryBudgetUsage;
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widget/views/budget_view.dart';
import '../../widget/views/bee_trail_view.dart';
import '../../widget/views/consumption_rhythm_view.dart';
import '../../widget/views/dashboard_view.dart';
import '../../widget/views/glance_view.dart';
import '../../widget/views/net_worth_view.dart';
import '../../widget/views/quick_add_view.dart';
import '../../widget/views/recent_view.dart';
import '../../widget/widget_data_service.dart'
    show
        DashboardWidgetData,
        DailyWidgetActivity,
        GlanceWidgetData,
        NetWorthAccountItem,
        QuickAddCategoryItem,
        RecentTransactionItem;
import '../../widget/widget_spec.dart' show HWSize;
import '../../widgets/biz/section_card.dart';
import '../../widgets/ui/ui.dart';

/// 小组件管理页 ——「组件库」画廊。
///
/// Phase C:从单一收支速览预览升级为 6 类内容(收支速览/净资产/快速记账/
/// 预算/最近交易/综合仪表盘)各一张预览卡,每张卡直接复用对应的真实 headless
/// View(`lib/widget/views/*.dart`)渲染,配上按各 View 冒烟测试同款手法造的
/// 合理示例数据(参考 `test/widget/*_view_test.dart`),让用户在添加组件前就
/// 能直观看到每类组件长什么样、能展示哪些内容——而不是只能看到一种收支速览
/// 样式。
///
/// 示例数据是纯本地常量(见文件末尾 `_sample*` 系列函数),不查询
/// repository/数据库——这里只是"预览长什么样",不是"预览我的真实数据";真正
/// 添加到桌面后的组件由 `WidgetManager.updateAllWidgets` 取真实数据渲染。
class WidgetManagementPage extends ConsumerWidget {
  const WidgetManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final redForIncome = ref.watch(incomeExpenseColorSchemeProvider);
    final dark = BeeTokens.isDark(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.widgetManagement,
            subtitle: l10n.widgetManagementDesc,
            showBack: true,
            leadingIcon: Icons.widgets_outlined,
            leadingPlain: true,
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

                // 1. 收支速览
                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.widgetGalleryGlanceTitle,
                  subtitle: l10n.widgetGalleryGlanceDesc,
                  sizeLabel: l10n.widgetSizeMedium,
                  previewSize: const Size(364, 169),
                  preview: GlanceView.medium(
                    todayExpense: '¥88.5',
                    todayIncome: '¥0',
                    monthExpense: '¥3,200.5',
                    monthIncome: '¥8,000',
                    themeColor: primaryColor,
                    redForIncome: redForIncome,
                    dark: dark,
                    titleLabel: l10n.widgetGalleryGlanceTitle,
                    monthSuffix: l10n.widgetMonthSuffix,
                    todayLabel: l10n.widgetToday,
                    todayExpenseLabel: l10n.widgetTodayExpense,
                    todayIncomeLabel: l10n.widgetTodayIncome,
                    monthExpenseLabel: l10n.widgetMonthExpense,
                    monthIncomeLabel: l10n.widgetMonthIncome,
                    width: 364,
                    height: 169,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                // 1.5 收支速览·小号(独立可添加档位:Android 是单独的
                // provider、iOS 是同 kind 的 systemSmall family,画廊里单独
                // 露出一卡,让用户知道有这个小方块可加)
                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.widgetGalleryGlanceTitle,
                  subtitle: l10n.widgetGalleryGlanceDesc,
                  sizeLabel: l10n.widgetSizeSmall,
                  previewSize: const Size(155, 155),
                  preview: GlanceView.small(
                    todayExpense: '¥88.5',
                    monthExpense: '¥3,200.5',
                    monthIncome: '¥8,000',
                    themeColor: primaryColor,
                    redForIncome: redForIncome,
                    dark: dark,
                    todayLabel: l10n.widgetToday,
                    todayExpenseLabel: l10n.widgetTodayExpense,
                    monthExpenseLabel: l10n.widgetMonthExpense,
                    monthIncomeLabel: l10n.widgetMonthIncome,
                    width: 155,
                    height: 155,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                // 2. 净资产
                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.accountTotalBalance,
                  subtitle: l10n.widgetGalleryNetWorthDesc,
                  sizeLabel: l10n.widgetSizeLarge,
                  previewSize: const Size(364, 382),
                  preview: NetWorthView(
                    size: HWSize.large,
                    netWorth: 82345.67,
                    totalAssets: 102345.67,
                    totalLiabilities: 20000,
                    baseCurrency: 'CNY',
                    trend: _sampleNetWorthTrend(),
                    topAccounts: _sampleNetWorthAccounts(),
                    themeColor: primaryColor,
                    redForIncome: redForIncome,
                    dark: dark,
                    netWorthLabel: l10n.accountTotalBalance,
                    totalAssetsLabel: l10n.totalAssets,
                    totalLiabilitiesLabel: l10n.totalLiabilities,
                    noAccountsLabel: l10n.widgetNoAccounts,
                    width: 364,
                    height: 382,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                // 3. 快速记账
                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.widgetGalleryQuickAddTitle,
                  subtitle: l10n.widgetGalleryQuickAddDesc,
                  sizeLabel: l10n.widgetSizeMedium,
                  previewSize: const Size(364, 169),
                  preview: QuickAddView(
                    size: HWSize.medium,
                    categories: _sampleQuickAddCategories(),
                    themeColor: primaryColor,
                    dark: dark,
                    addLabel: l10n.widgetQuickAddLabel,
                    titleLabel: l10n.widgetGalleryQuickAddTitle,
                    width: 364,
                    height: 169,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                // 4. 预算进度
                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.budgetMonthlyBudget,
                  subtitle: l10n.widgetGalleryBudgetDesc,
                  sizeLabel: l10n.widgetSizeMedium,
                  previewSize: const Size(364, 169),
                  preview: BudgetView(
                    size: HWSize.medium,
                    overview: _sampleBudgetOverview(),
                    currencyCode: 'CNY',
                    themeColor: primaryColor,
                    redForIncome: redForIncome,
                    dark: dark,
                    budgetLabel: l10n.budgetMonthlyBudget,
                    usedLabel: l10n.budgetUsed,
                    totalLabel: l10n.widgetBudgetTotal,
                    remainingLabel: l10n.widgetBudgetRemaining,
                    noBudgetLabel: l10n.widgetNoBudget,
                    width: 364,
                    height: 169,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                // 5. 最近交易
                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.widgetRecentTransactions,
                  subtitle: l10n.widgetGalleryRecentDesc,
                  sizeLabel: l10n.widgetSizeLarge,
                  previewSize: const Size(364, 382),
                  preview: RecentView(
                    size: HWSize.large,
                    items: _sampleRecentItems(),
                    defaultCurrency: 'CNY',
                    themeColor: primaryColor,
                    redForIncome: redForIncome,
                    dark: dark,
                    uncategorizedLabel: l10n.commonUncategorized,
                    emptyLabel: l10n.widgetNoTransactions,
                    titleLabel: l10n.widgetRecentTransactions,
                    width: 364,
                    height: 382,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                // 6. 综合仪表盘
                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.widgetGalleryDashboardTitle,
                  subtitle: l10n.widgetGalleryDashboardDesc,
                  sizeLabel: l10n.widgetSizeLarge,
                  previewSize: const Size(364, 382),
                  preview: DashboardView(
                    data: _sampleDashboardData(),
                    defaultCurrency: 'CNY',
                    themeColor: primaryColor,
                    redForIncome: redForIncome,
                    dark: dark,
                    monthExpenseLabel: l10n.widgetMonthExpense,
                    monthIncomeLabel: l10n.widgetMonthIncome,
                    recentLabel: l10n.widgetRecentTransactions,
                    uncategorizedLabel: l10n.commonUncategorized,
                    noTransactionsLabel: l10n.widgetNoTransactions,
                    quickAddLabel: l10n.widgetQuickAddLabel,
                    titleLabel: l10n.widgetDashboardTitle,
                    width: 364,
                    height: 382,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.widgetConsumptionRhythmTitle,
                  subtitle: l10n.widgetGalleryConsumptionRhythmDesc,
                  sizeLabel: l10n.widgetSizeMedium,
                  previewSize: const Size(364, 169),
                  preview: ConsumptionRhythmView(
                    activity: _sampleDailyActivity(),
                    themeColor: primaryColor,
                    dark: dark,
                    titleLabel: l10n.widgetConsumptionRhythmTitle,
                    stableLabel: l10n.widgetConsumptionRhythmStable,
                    increaseLabel: l10n.widgetConsumptionRhythmIncrease,
                    decreaseLabel: l10n.widgetConsumptionRhythmDecrease,
                    emptyLabel: l10n.widgetConsumptionRhythmEmpty,
                    width: 364,
                    height: 169,
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                _buildGalleryCard(
                  context,
                  ref,
                  title: l10n.widgetBeeTrailTitle,
                  subtitle: l10n.widgetGalleryBeeTrailDesc,
                  sizeLabel: l10n.widgetSizeSmall,
                  previewSize: const Size(155, 155),
                  preview: BeeTrailView(
                    activity: _sampleDailyActivity(),
                    themeColor: primaryColor,
                    dark: dark,
                    titleLabel: l10n.widgetBeeTrailTitle,
                    streakSuffix: l10n.widgetBeeTrailStreakSuffix,
                    completionLabel: l10n.widgetBeeTrailCompletion,
                    emptyLabel: l10n.widgetBeeTrailEmpty,
                    width: 155,
                    height: 155,
                  ),
                ),
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

  /// 单张画廊预览卡:标题/副标题 + 代表尺寸徽章 + 用 [FittedBox] 把固定像素
  /// 尺寸([previewSize])的真实 headless View([preview])等比缩放到卡片可用
  /// 宽度——View 本身画的是矢量内容,缩放不会糊,与旧页面单一预览的做法一致。
  Widget _buildGalleryCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required String sizeLabel,
    required Size previewSize,
    required Widget preview,
  }) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.0.scaled(context, ref),
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                    SizedBox(height: 3.0.scaled(context, ref)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.0.scaled(context, ref),
                        color: BeeTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.0.scaled(context, ref)),
              _buildSizeBadge(context, ref, sizeLabel, previewSize),
            ],
          ),
          SizedBox(height: 14.0.scaled(context, ref)),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final displayWidth = constraints.maxWidth.clamp(0.0, 400.0);
                final displayHeight =
                    displayWidth * previewSize.height / previewSize.width;
                return Container(
                  width: displayWidth,
                  height: displayHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: previewSize.width,
                        height: previewSize.height,
                        child: preview,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeBadge(
    BuildContext context,
    WidgetRef ref,
    String label,
    Size size,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8.0.scaled(context, ref),
        vertical: 4.0.scaled(context, ref),
      ),
      decoration: BoxDecoration(
        color: BeeTokens.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label · ${size.width.toInt()}×${size.height.toInt()}',
        style: TextStyle(
          fontSize: 10.0.scaled(context, ref),
          fontWeight: FontWeight.w500,
          color: BeeTokens.textTertiary(context),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 添加指引 / 快捷记账说明 / 关于小组件(内容沿用旧页面,改用
  // SectionCard/BeeTokens/.scaled() 重新皮肤)
  // -------------------------------------------------------------------

  Widget _buildAddGuideSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final primaryColor = ref.watch(primaryColorProvider);
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: primaryColor,
                size: 22.0.scaled(context, ref),
              ),
              SizedBox(width: 8.0.scaled(context, ref)),
              Text(
                l10n.howToAddWidget,
                style: TextStyle(
                  fontSize: 15.0.scaled(context, ref),
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.0.scaled(context, ref)),
          if (Platform.isIOS)
            _buildStepList(context, ref, [
              l10n.iosWidgetStep1,
              l10n.iosWidgetStep2,
              l10n.iosWidgetStep3,
              l10n.iosWidgetStep4,
            ])
          else
            _buildStepList(context, ref, [
              l10n.androidWidgetStep1,
              l10n.androidWidgetStep2,
              l10n.androidWidgetStep3,
              l10n.androidWidgetStep4,
            ]),
        ],
      ),
    );
  }

  Widget _buildStepList(
    BuildContext context,
    WidgetRef ref,
    List<String> steps,
  ) {
    final primaryColor = ref.watch(primaryColorProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: 12.0.scaled(context, ref)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22.0.scaled(context, ref),
                height: 22.0.scaled(context, ref),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: BeeTokens.textOnPrimary(context),
                      fontSize: 11.0.scaled(context, ref),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.0.scaled(context, ref)),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 13.5.scaled(context, ref),
                    color: BeeTokens.textPrimary(context),
                  ),
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
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final primaryColor = ref.watch(primaryColorProvider);
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                color: primaryColor,
                size: 22.0.scaled(context, ref),
              ),
              SizedBox(width: 8.0.scaled(context, ref)),
              Text(
                l10n.widgetQuickEntryTitle,
                style: TextStyle(
                  fontSize: 15.0.scaled(context, ref),
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.0.scaled(context, ref)),
          Text(
            l10n.widgetQuickEntryDesc,
            style: TextStyle(
              fontSize: 13.0.scaled(context, ref),
              color: BeeTokens.textSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final primaryColor = ref.watch(primaryColorProvider);
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      padding: EdgeInsets.all(14.0.scaled(context, ref)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: primaryColor,
                size: 18.0.scaled(context, ref),
              ),
              SizedBox(width: 8.0.scaled(context, ref)),
              Text(
                l10n.aboutWidget,
                style: TextStyle(
                  fontSize: 13.5.scaled(context, ref),
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.0.scaled(context, ref)),
          Text(
            l10n.widgetDescription,
            style: TextStyle(
              fontSize: 12.0.scaled(context, ref),
              color: BeeTokens.textSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 示例数据 —— 仅供「组件库」画廊预览展示,不查询任何 repository/数据库。
// 构造手法与各 View 自己的 headless 冒烟测试(test/widget/*_view_test.dart)
// 一致,数值经过挑选以展示各 View 的典型状态(有进度/有趋势/有转账等),不是
// 随机生成。
// ===========================================================================

Account _sampleAccount(
  int id,
  String name, {
  String type = 'bank_card',
  String currency = 'CNY',
}) {
  return Account(
    id: id,
    ledgerId: 1,
    name: name,
    type: type,
    currency: currency,
    initialBalance: 0,
    sortOrder: id,
    hidden: false,
  );
}

Category _sampleCategory(int id, String name,
    {String? icon, String kind = 'expense'}) {
  return Category(
    id: id,
    name: name,
    kind: kind,
    icon: icon,
    sortOrder: id,
    level: 1,
    iconType: 'material',
  );
}

Transaction _sampleTransaction({
  required int id,
  required String type,
  required double amount,
  int? categoryId,
  int? accountId,
  int? toAccountId,
  required DateTime happenedAt,
}) {
  return Transaction(
    id: id,
    ledgerId: 1,
    type: type,
    amount: amount,
    categoryId: categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    happenedAt: happenedAt,
    excludeFromStats: false,
    excludeFromBudget: false,
  );
}

/// 近 30 日净值趋势(资产稳步上升、负债缓慢下降),供净资产/综合仪表盘两张
/// 卡共用。
List<({DateTime date, double assets, double liabilities, double net})>
    _sampleNetWorthTrend() {
  final base = DateTime.now().subtract(const Duration(days: 29));
  return List.generate(30, (i) {
    final assets = 96000.0 + i * 320;
    final liabilities = 24000.0 - i * 130;
    return (
      date: base.add(Duration(days: i)),
      assets: assets,
      liabilities: liabilities,
      net: assets - liabilities,
    );
  });
}

List<DailyWidgetActivity> _sampleDailyActivity() {
  final start = DateTime.now().subtract(const Duration(days: 29));
  return List.generate(
    30,
    (index) => DailyWidgetActivity(
      date: DateTime(start.year, start.month, start.day + index),
      expenseTotal: switch (index % 5) { 0 => 0, 1 => 35, 2 => 86, _ => 150 },
      hasRecord: index % 4 != 0,
    ),
  );
}

/// 净资产大号卡的账户明细:含一个正常折算 + 一个现金账户,数值与
/// net_worth_view_test.dart 的示例保持同一量级。
List<NetWorthAccountItem> _sampleNetWorthAccounts() {
  return [
    NetWorthAccountItem(
      account: _sampleAccount(1, '招商银行'),
      balance: 50000,
      convertedBalance: 50000,
    ),
    NetWorthAccountItem(
      account: _sampleAccount(2, '支付宝余额宝'),
      balance: 30000,
      convertedBalance: 30000,
    ),
    NetWorthAccountItem(
      account: _sampleAccount(3, '现金', type: 'cash'),
      balance: 2345.67,
      convertedBalance: 2345.67,
    ),
  ];
}

/// 快速记账 4 个常用分类(含一个 emoji 图标,展示 emoji/图标两种渲染路径)。
List<QuickAddCategoryItem> _sampleQuickAddCategories() {
  return const [
    QuickAddCategoryItem(
        categoryId: 1, name: '餐饮', icon: 'restaurant', total: 680),
    QuickAddCategoryItem(
        categoryId: 2, name: '交通', icon: 'directions_car', total: 210),
    QuickAddCategoryItem(
        categoryId: 3, name: '购物', icon: 'shopping_bag', total: 450),
    QuickAddCategoryItem(categoryId: 4, name: '奶茶', icon: '🧋', total: 68),
  ];
}

/// 预算总览:总预算用量 64%(normal 状态)+ 3 个分类用量(其中"购物"接近
/// warning 阈值),展示进度条 + 分类用量卡两个区块。
BudgetOverview _sampleBudgetOverview() {
  return BudgetOverview(
    totalBudget: BudgetUsage(used: 3200, budget: 5000),
    categoryBudgets: [
      CategoryBudgetUsage(
        budgetId: 1,
        categoryId: 1,
        categoryName: '餐饮',
        usage: BudgetUsage(used: 900, budget: 1200),
      ),
      CategoryBudgetUsage(
        budgetId: 2,
        categoryId: 2,
        categoryName: '交通',
        usage: BudgetUsage(used: 260, budget: 500),
      ),
      CategoryBudgetUsage(
        budgetId: 3,
        categoryId: 3,
        categoryName: '购物',
        usage: BudgetUsage(used: 620, budget: 800),
      ),
    ],
    daysRemaining: 12,
    dailyAvailable: 150,
  );
}

/// 最近交易 5 笔:支出/收入/转账混合,时间跨度从"刚刚"到两天前,展示
/// RecentView 大号的完整行样式(含转账的 swap_horiz 图标)。
List<RecentTransactionItem> _sampleRecentItems() {
  final now = DateTime.now();
  return [
    RecentTransactionItem(
      transaction: _sampleTransaction(
        id: 1,
        type: 'expense',
        amount: 32.5,
        categoryId: 1,
        accountId: 1,
        happenedAt: now,
      ),
      category: _sampleCategory(1, '餐饮', icon: 'restaurant'),
      account: _sampleAccount(1, '现金', type: 'cash'),
    ),
    RecentTransactionItem(
      transaction: _sampleTransaction(
        id: 2,
        type: 'expense',
        amount: 128,
        categoryId: 2,
        accountId: 2,
        happenedAt: now.subtract(const Duration(hours: 5)),
      ),
      category: _sampleCategory(2, '购物', icon: 'shopping_bag'),
      account: _sampleAccount(2, '招商银行'),
    ),
    RecentTransactionItem(
      transaction: _sampleTransaction(
        id: 3,
        type: 'income',
        amount: 8000,
        categoryId: 3,
        accountId: 1,
        happenedAt: now.subtract(const Duration(days: 1)),
      ),
      category: _sampleCategory(3, '工资', icon: 'attach_money', kind: 'income'),
      account: _sampleAccount(1, '现金', type: 'cash'),
    ),
    RecentTransactionItem(
      transaction: _sampleTransaction(
        id: 4,
        type: 'transfer',
        amount: 500,
        accountId: 1,
        toAccountId: 2,
        happenedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      account: _sampleAccount(1, '现金', type: 'cash'),
      toAccount: _sampleAccount(2, '招商银行'),
    ),
    RecentTransactionItem(
      transaction: _sampleTransaction(
        id: 5,
        type: 'expense',
        amount: 18,
        categoryId: 1,
        accountId: 1,
        happenedAt: now.subtract(const Duration(days: 2)),
      ),
      category: _sampleCategory(1, '餐饮', icon: 'restaurant'),
      account: _sampleAccount(1, '现金', type: 'cash'),
    ),
  ];
}

/// 综合仪表盘:组合上面的净值趋势/最近交易(取前 3,DashboardView 内部再取
/// 前 2)/快速记账分类,本月收支单独给一组独立于「今日」卡片的数值。
DashboardWidgetData _sampleDashboardData() {
  return DashboardWidgetData(
    glance: const GlanceWidgetData(
      todayExpenseTotal: 88.5,
      todayIncomeTotal: 0,
      monthExpenseTotal: 3200.5,
      monthIncomeTotal: 8000,
    ),
    netWorthTrend: _sampleNetWorthTrend(),
    recent: _sampleRecentItems().take(3).toList(),
    quickAdd: _sampleQuickAddCategories(),
  );
}
