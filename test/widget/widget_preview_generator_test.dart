/// 桌面小组件「选择器预览图」生成器(不是回归测试)。
///
/// 用真实的 6 个 headless View + 示例数据渲染出静态 PNG,**中英双语两套**:
/// - 简体中文(默认) → `android/app/src/main/res/drawable-nodpi/`
/// - 英文            → `android/app/src/main/res/drawable-en-nodpi/`
///
/// 各 `<appwidget-provider>` 的 `android:previewImage` 引用同名资源,Android
/// 按**系统语言**自动选取(与 values/values-en 的 strings 同一套资源限定符
/// 机制;其它语言回退默认简中)。这样选择器里能看到「长得像真组件」的预览
/// (用户拍板:静态预览即可),全 Android 版本通吃。
///
/// **只在本机手动运行**,CI 上自动跳过(依赖 macOS 系统中文字体与本地
/// Flutter SDK 的 MaterialIcons 字体,且产物是二进制资源不是断言):
///
/// ```bash
/// GEN_WIDGET_PREVIEWS=1 noproxy flutter test \
///     test/widget/widget_preview_generator_test.dart
/// ```
///
/// 字体说明:flutter_test 默认字体是 Ahem(所有字形都是实心方块),直接渲染
/// 出的 PNG 没法看。这里把 macOS 的冬青黑体(Hiragino Sans GB,CJK+Latin
/// 全覆盖)以 family 名 `Roboto` 载入,并用 [DefaultTextStyle] 把该 family
/// 注入 View(View 内部的 TextStyle 未指定 fontFamily,Text.merge 会继承),
/// MaterialIcons 从 Flutter SDK 缓存载入以渲染分类/装饰图标。
///
/// 英文文案与真实运行时一致:逐条镜像 `lib/l10n/app_en.arb` 里 widget 用到的
/// key(appTitle/widgetTodayExpense/.../widgetBudgetRemaining),不另造措辞;
/// 金额用 USD($)更贴近英文用户观感。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart' show Account, Category, Transaction;
import 'package:beecount/data/repositories/budget_repository.dart'
    show BudgetOverview, BudgetUsage, CategoryBudgetUsage;
import 'package:beecount/widget/views/budget_view.dart';
import 'package:beecount/widget/views/dashboard_view.dart';
import 'package:beecount/widget/views/glance_view.dart';
import 'package:beecount/widget/views/net_worth_view.dart';
import 'package:beecount/widget/views/quick_add_view.dart';
import 'package:beecount/widget/views/recent_view.dart';
import 'package:beecount/widget/widget_data_service.dart'
    show
        DashboardWidgetData,
        GlanceWidgetData,
        QuickAddCategoryItem,
        RecentTransactionItem;
import 'package:beecount/widget/widget_spec.dart' show HWSize;

const _honey = Color(0xFFF5A623);

final bool _enabled = Platform.environment['GEN_WIDGET_PREVIEWS'] == '1';

// ---------------------------------------------------------------------------
// 语言包:每种语言一套文案 + 示例数据 + 输出目录
// ---------------------------------------------------------------------------

class _Pack {
  final String name; // 日志用
  final String outDir; // Android 资源目录(语言限定符)
  final String currency; // 传给 View 的币种码(决定符号)
  final String sym; // glance 预格式化金额用的符号
  // glance
  final String appName, monthSuffix;
  final String todayLabel; // GlanceView.small「今日」徽章(widgetToday)
  final String todayExpenseLabel, todayIncomeLabel;
  final String monthExpenseLabel, monthIncomeLabel;
  // netWorth
  final String netWorthLabel, totalAssetsLabel, totalLiabilitiesLabel;
  // quickAdd / budget / recent / dashboard
  final String addLabel;
  final String budgetLabel, usedLabel, totalLabel, remainingLabel;
  final String recentLabel;
  final List<String> categoryNames; // 餐饮/交通/购物/娱乐 顺序
  final String salaryName;
  final List<String> accountNames; // 主账户 / 次账户

  const _Pack({
    required this.name,
    required this.outDir,
    required this.currency,
    required this.sym,
    required this.appName,
    required this.monthSuffix,
    required this.todayLabel,
    required this.todayExpenseLabel,
    required this.todayIncomeLabel,
    required this.monthExpenseLabel,
    required this.monthIncomeLabel,
    required this.netWorthLabel,
    required this.totalAssetsLabel,
    required this.totalLiabilitiesLabel,
    required this.addLabel,
    required this.budgetLabel,
    required this.usedLabel,
    required this.totalLabel,
    required this.remainingLabel,
    required this.recentLabel,
    required this.categoryNames,
    required this.salaryName,
    required this.accountNames,
  });
}

/// 简体中文(默认资源,文案镜像 app_zh.arb)。
const _zh = _Pack(
  name: 'zh',
  outDir: 'android/app/src/main/res/drawable-nodpi',
  currency: 'CNY',
  sym: '¥',
  appName: '蜜蜂记账',
  monthSuffix: '月',
  todayLabel: '今日',
  todayExpenseLabel: '今日支出',
  todayIncomeLabel: '今日收入',
  monthExpenseLabel: '本月支出',
  monthIncomeLabel: '本月收入',
  netWorthLabel: '净资产',
  totalAssetsLabel: '总资产',
  totalLiabilitiesLabel: '总负债',
  addLabel: '记一笔',
  budgetLabel: '本月预算',
  usedLabel: '已用',
  totalLabel: '总额',
  remainingLabel: '剩',
  recentLabel: '最近交易',
  categoryNames: ['餐饮', '交通', '购物', '娱乐'],
  salaryName: '工资',
  accountNames: ['招商银行', '支付宝'],
);

/// 英文(drawable-en,文案逐条镜像 app_en.arb 对应 key)。
const _en = _Pack(
  name: 'en',
  outDir: 'android/app/src/main/res/drawable-en-nodpi',
  currency: 'USD',
  sym: '\$',
  appName: 'Bee Accounting', // appTitle
  monthSuffix: '', // widgetMonthSuffix(en 为空,徽章只显示月份数字)
  todayLabel: 'Today', // widgetToday
  todayExpenseLabel: "Today's Expense", // widgetTodayExpense
  todayIncomeLabel: "Today's Income", // widgetTodayIncome
  monthExpenseLabel: "Month's Expense", // widgetMonthExpense
  monthIncomeLabel: "Month's Income", // widgetMonthIncome
  netWorthLabel: 'Net Assets', // accountTotalBalance
  totalAssetsLabel: 'Total Assets', // totalAssets
  totalLiabilitiesLabel: 'Total Liabilities', // totalLiabilities
  addLabel: 'Add', // widgetQuickAddLabel
  budgetLabel: 'Monthly Budget', // budgetMonthlyBudget
  usedLabel: 'Used', // budgetUsed
  totalLabel: 'Total', // widgetBudgetTotal
  remainingLabel: 'Left', // widgetBudgetRemaining
  recentLabel: 'Recent Transactions', // widgetRecentTransactions
  categoryNames: ['Dining', 'Transport', 'Shopping', 'Movies'],
  salaryName: 'Salary',
  accountNames: ['Bank Card', 'Cash'],
);

// ---------------------------------------------------------------------------
// 字体
// ---------------------------------------------------------------------------

/// 把系统 CJK 字体注册成默认 family `Roboto`;返回是否成功(失败则预览里的
/// 中文会渲染成方块,应中止检查环境而不是提交烂图)。
Future<bool> _loadCjkAsDefault() async {
  const candidates = [
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
    '/System/Library/Fonts/PingFang.ttc',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (!f.existsSync()) continue;
    try {
      final bytes = f.readAsBytesSync();
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return true;
    } catch (_) {
      // ttc 解析失败换下一个候选。
    }
  }
  return false;
}

Future<void> _loadMaterialIcons() async {
  var root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    // flutter_tester 位于 $FLUTTER_ROOT/bin/cache/artifacts/engine/<os>/,
    // 从可执行路径向上推导。
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 4; i++) {
      dir = dir.parent;
    }
    root = dir.path;
  }
  final otf =
      File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!otf.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(otf.readAsBytesSync().buffer)));
  await loader.load();
}

// ---------------------------------------------------------------------------
// 截图
// ---------------------------------------------------------------------------

Future<void> _capture(
  WidgetTester tester,
  Widget view,
  Size logical,
  String outDir,
  String outName,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        // View 内部 TextStyle 未指定 fontFamily,merge 后继承这里的
        // Roboto(已被替换为 CJK 字体,见 _loadCjkAsDefault)。
        style: const TextStyle(fontFamily: 'Roboto', color: Colors.black),
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: logical.width,
              height: logical.height,
              child: view,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '$outName 渲染抛异常');

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // @2x:预览图不需要 @3x 那么大,launcher 会缩放;2x 已足够清晰。
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('$outDir/$outName.png');
    out.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List(), flush: true);
    // 供人工核对尺寸。
    // ignore: avoid_print
    print('生成 $outDir/$outName.png (${image.width}x${image.height})');
  });
}

// ---------------------------------------------------------------------------
// 示例数据(金额对齐样式预览 Artifact,亮色版)
// ---------------------------------------------------------------------------

List<({DateTime date, double assets, double liabilities, double net})>
    _trend() {
  final base = DateTime(2026, 6, 20);
  const points = <double>[
    82000, 82300, 82100, 83000, 83400, 83200, 84100, //
    84600, 84400, 85200, 85600, 85400, 86100, 86420,
  ];
  return [
    for (var i = 0; i < points.length; i++)
      (
        date: base.add(Duration(days: i * 2)),
        assets: points[i] + 5680,
        liabilities: 5680.0,
        net: points[i],
      ),
  ];
}

Account _account(int id, String name, {String type = 'bank'}) => Account(
      id: id,
      ledgerId: 1,
      name: name,
      type: type,
      currency: 'CNY',
      initialBalance: 0,
      sortOrder: id,
      hidden: false,
    );

Category _category(int id, String name, String icon) => Category(
      id: id,
      name: name,
      kind: 'expense',
      icon: icon,
      sortOrder: id,
      level: 1,
      iconType: 'material',
    );

List<QuickAddCategoryItem> _quickAddCategories(_Pack p) => [
      QuickAddCategoryItem(
          categoryId: 1, name: p.categoryNames[0], icon: 'restaurant', total: 1620),
      QuickAddCategoryItem(
          categoryId: 2, name: p.categoryNames[1], icon: 'directions_car', total: 480),
      QuickAddCategoryItem(
          categoryId: 3, name: p.categoryNames[2], icon: 'shopping_cart', total: 2350),
      QuickAddCategoryItem(
          categoryId: 4, name: p.categoryNames[3], icon: 'movie', total: 300),
    ];

List<RecentTransactionItem> _recentItems(_Pack p) {
  final cafe = _category(1, p.categoryNames[0], 'local_cafe');
  final salary = _category(2, p.salaryName, 'payments');
  final grocery = _category(3, p.categoryNames[2], 'shopping_cart');
  final main = _account(1, p.accountNames[0]);
  final sub = _account(2, p.accountNames[1], type: 'cash');
  Transaction tx({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    required DateTime at,
  }) =>
      Transaction(
        id: id,
        ledgerId: 1,
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: 1,
        happenedAt: at,
        excludeFromStats: false,
        excludeFromBudget: false,
      );
  return [
    RecentTransactionItem(
      transaction: tx(
          id: 1, type: 'expense', amount: 32, categoryId: 1, at: DateTime(2026, 7, 20, 9, 12)),
      category: cafe,
      account: main,
    ),
    RecentTransactionItem(
      transaction: tx(
          id: 2, type: 'income', amount: 18500, categoryId: 2, at: DateTime(2026, 7, 19, 10, 0)),
      category: salary,
      account: main,
    ),
    RecentTransactionItem(
      transaction: tx(
          id: 3, type: 'expense', amount: 156.8, categoryId: 3, at: DateTime(2026, 7, 19, 18, 40)),
      category: grocery,
      account: sub,
    ),
  ];
}

Future<void> _generatePack(WidgetTester tester, _Pack p) async {
  // 0) 收支速览·小号(Android 独立 provider 的选择器预览;iOS 走 placeholder
  // 不用它,但同名资源两语都备齐)
  await _capture(
    tester,
    GlanceView.small(
      todayExpense: '${p.sym}128.50',
      // 155dp 小卡底部双栏放不下千位金额(会 ellipsis),预览样本刻意取短。
      monthExpense: '${p.sym}842.30',
      monthIncome: '${p.sym}1,850',
      themeColor: _honey,
      redForIncome: false,
      dark: false,
      todayLabel: p.todayLabel,
      todayExpenseLabel: p.todayExpenseLabel,
      monthExpenseLabel: p.monthExpenseLabel,
      monthIncomeLabel: p.monthIncomeLabel,
      width: 155,
      height: 155,
    ),
    const Size(155, 155),
    p.outDir,
    'widget_preview_glance_small',
  );

  // 1) 收支速览(中号,Android 2:1)
  await _capture(
    tester,
    GlanceView.medium(
      todayExpense: '${p.sym}128.50',
      todayIncome: '${p.sym}0.00',
      monthExpense: '${p.sym}6,842.30',
      monthIncome: '${p.sym}18,500.00',
      themeColor: _honey,
      redForIncome: false,
      dark: false,
      appName: p.appName,
      monthSuffix: p.monthSuffix,
      todayExpenseLabel: p.todayExpenseLabel,
      todayIncomeLabel: p.todayIncomeLabel,
      monthExpenseLabel: p.monthExpenseLabel,
      monthIncomeLabel: p.monthIncomeLabel,
      width: 364,
      height: 182,
    ),
    const Size(364, 182),
    p.outDir,
    'widget_preview_glance',
  );

  // 2) 净资产(中号)
  await _capture(
    tester,
    NetWorthView(
      size: HWSize.medium,
      netWorth: 86420,
      totalAssets: 92100,
      totalLiabilities: 5680,
      baseCurrency: p.currency,
      trend: _trend(),
      themeColor: _honey,
      redForIncome: false,
      dark: false,
      netWorthLabel: p.netWorthLabel,
      totalAssetsLabel: p.totalAssetsLabel,
      totalLiabilitiesLabel: p.totalLiabilitiesLabel,
      width: 364,
      height: 169,
    ),
    const Size(364, 169),
    p.outDir,
    'widget_preview_networth',
  );

  // 3) 快速记账(小号 2×2)
  await _capture(
    tester,
    QuickAddView(
      size: HWSize.small,
      categories: _quickAddCategories(p),
      themeColor: _honey,
      dark: false,
      addLabel: p.addLabel,
      width: 155,
      height: 155,
    ),
    const Size(155, 155),
    p.outDir,
    'widget_preview_quickadd',
  );

  // 4) 预算进度(小号环形)
  await _capture(
    tester,
    BudgetView(
      size: HWSize.small,
      overview: BudgetOverview(
        // 数字刻意取小:155dp 小卡底部一行「剩 ¥x / 总额 ¥y」要能完整放下,
        // 大金额会被 ellipsis 截断,预览图不好看。
        totalBudget: BudgetUsage(used: 684, budget: 800),
        categoryBudgets: [
          CategoryBudgetUsage(
            budgetId: 1,
            categoryId: 1,
            categoryName: p.categoryNames[0],
            usage: BudgetUsage(used: 162, budget: 180),
          ),
        ],
        daysRemaining: 11,
        dailyAvailable: 10.5,
      ),
      currencyCode: p.currency,
      themeColor: _honey,
      redForIncome: false,
      dark: false,
      budgetLabel: p.budgetLabel,
      usedLabel: p.usedLabel,
      totalLabel: p.totalLabel,
      remainingLabel: p.remainingLabel,
      width: 155,
      height: 155,
    ),
    const Size(155, 155),
    p.outDir,
    'widget_preview_budget',
  );

  // 5) 最近交易(中号)
  await _capture(
    tester,
    RecentView(
      size: HWSize.medium,
      items: _recentItems(p),
      defaultCurrency: p.currency,
      themeColor: _honey,
      redForIncome: false,
      dark: false,
      width: 364,
      height: 169,
    ),
    const Size(364, 169),
    p.outDir,
    'widget_preview_recent',
  );

  // 6) 综合仪表盘(大号)
  await _capture(
    tester,
    DashboardView(
      data: DashboardWidgetData(
        glance: const GlanceWidgetData(
          todayExpenseTotal: 128.5,
          todayIncomeTotal: 0,
          monthExpenseTotal: 6842.3,
          monthIncomeTotal: 18500,
        ),
        netWorthTrend: _trend(),
        recent: _recentItems(p).take(2).toList(),
        quickAdd: _quickAddCategories(p).take(3).toList(),
      ),
      defaultCurrency: p.currency,
      themeColor: _honey,
      redForIncome: false,
      dark: false,
      monthExpenseLabel: p.monthExpenseLabel,
      monthIncomeLabel: p.monthIncomeLabel,
      recentLabel: p.recentLabel,
      quickAddLabel: p.addLabel,
      width: 364,
      height: 382,
    ),
    const Size(364, 382),
    p.outDir,
    'widget_preview_dashboard',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_enabled) return;
    final cjkOk = await _loadCjkAsDefault();
    expect(cjkOk, isTrue,
        reason: '未能加载系统 CJK 字体(Hiragino/PingFang),中文会渲染成方块;'
            '请在 macOS 上运行本生成器');
    await _loadMaterialIcons();
  });

  testWidgets(
    '生成中英双语 Android 选择器预览图(6 类 × 2 语言)',
    (tester) async {
      await _generatePack(tester, _zh);
      await _generatePack(tester, _en);
    },
    // 预览图生成器:GEN_WIDGET_PREVIEWS=1 手动运行,CI 上自动跳过。
    skip: !_enabled,
  );
}
