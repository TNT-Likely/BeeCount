/// 桌面小组件「选择器预览图」生成器(不是回归测试)。
///
/// 用真实的 6 个 headless View + 示例数据渲染出静态 PNG,直接写入
/// `android/app/src/main/res/drawable-nodpi/widget_preview_<type>.png`,
/// 供各 `<appwidget-provider>` 的 `android:previewImage` 使用——这样 Android
/// 选择器里能看到「长得像真组件」的预览(用户拍板:假/静态预览即可),
/// 且全 Android 版本通吃(previewImage 自 API 早期即支持,不依赖 12+ 的
/// previewLayout)。
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
const _outDir = 'android/app/src/main/res/drawable-nodpi';

final bool _enabled = Platform.environment['GEN_WIDGET_PREVIEWS'] == '1';

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

Future<void> _capture(
  WidgetTester tester,
  Widget view,
  Size logical,
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
    final out = File('$_outDir/$outName.png');
    out.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List(), flush: true);
    // 供人工核对尺寸。
    // ignore: avoid_print
    print('生成 $_outDir/$outName.png (${image.width}x${image.height})');
  });
}

// ---------------------------------------------------------------------------
// 示例数据(对齐样式预览 Artifact 里的金额,亮色版)
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

List<QuickAddCategoryItem> _quickAddCategories() => const [
      QuickAddCategoryItem(categoryId: 1, name: '餐饮', icon: 'restaurant', total: 1620),
      QuickAddCategoryItem(categoryId: 2, name: '交通', icon: 'directions_car', total: 480),
      QuickAddCategoryItem(categoryId: 3, name: '购物', icon: 'shopping_cart', total: 2350),
      QuickAddCategoryItem(categoryId: 4, name: '娱乐', icon: 'movie', total: 300),
    ];

List<RecentTransactionItem> _recentItems() {
  final cafe = _category(1, '餐饮', 'local_cafe');
  final salary = _category(2, '工资', 'payments');
  final grocery = _category(3, '购物', 'shopping_cart');
  final cmb = _account(1, '招商银行');
  final alipay = _account(2, '支付宝', type: 'alipay');
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
      transaction:
          tx(id: 1, type: 'expense', amount: 32, categoryId: 1, at: DateTime(2026, 7, 20, 9, 12)),
      category: cafe,
      account: cmb,
    ),
    RecentTransactionItem(
      transaction: tx(
          id: 2, type: 'income', amount: 18500, categoryId: 2, at: DateTime(2026, 7, 19, 10, 0)),
      category: salary,
      account: cmb,
    ),
    RecentTransactionItem(
      transaction: tx(
          id: 3, type: 'expense', amount: 156.8, categoryId: 3, at: DateTime(2026, 7, 19, 18, 40)),
      category: grocery,
      account: alipay,
    ),
  ];
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
    '生成 6 张 Android 选择器预览图',
    (tester) async {
      // 1) 收支速览(中号,Android 2:1)
      await _capture(
        tester,
        const GlanceView.medium(
          todayExpense: '¥128.50',
          todayIncome: '¥0.00',
          monthExpense: '¥6,842.30',
          monthIncome: '¥18,500.00',
          themeColor: _honey,
          redForIncome: false,
          dark: false,
          appName: '蜜蜂记账',
          monthSuffix: '月',
          todayExpenseLabel: '今日支出',
          todayIncomeLabel: '今日收入',
          monthExpenseLabel: '本月支出',
          monthIncomeLabel: '本月收入',
          width: 364,
          height: 182,
        ),
        const Size(364, 182),
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
          baseCurrency: 'CNY',
          trend: _trend(),
          themeColor: _honey,
          redForIncome: false,
          dark: false,
          netWorthLabel: '净资产',
          totalAssetsLabel: '总资产',
          totalLiabilitiesLabel: '总负债',
          width: 364,
          height: 169,
        ),
        const Size(364, 169),
        'widget_preview_networth',
      );

      // 3) 快速记账(小号 2×2)
      await _capture(
        tester,
        QuickAddView(
          size: HWSize.small,
          categories: _quickAddCategories(),
          themeColor: _honey,
          dark: false,
          addLabel: '记一笔',
          width: 155,
          height: 155,
        ),
        const Size(155, 155),
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
                categoryName: '餐饮',
                usage: BudgetUsage(used: 1620, budget: 1800),
              ),
            ],
            daysRemaining: 11,
            dailyAvailable: 105.3,
          ),
          currencyCode: 'CNY',
          themeColor: _honey,
          redForIncome: false,
          dark: false,
          width: 155,
          height: 155,
        ),
        const Size(155, 155),
        'widget_preview_budget',
      );

      // 5) 最近交易(中号)
      await _capture(
        tester,
        RecentView(
          size: HWSize.medium,
          items: _recentItems(),
          defaultCurrency: 'CNY',
          themeColor: _honey,
          redForIncome: false,
          dark: false,
          width: 364,
          height: 169,
        ),
        const Size(364, 169),
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
            recent: _recentItems().take(2).toList(),
            quickAdd: _quickAddCategories().take(3).toList(),
          ),
          defaultCurrency: 'CNY',
          themeColor: _honey,
          redForIncome: false,
          dark: false,
          width: 364,
          height: 382,
        ),
        const Size(364, 382),
        'widget_preview_dashboard',
      );
    },
    // 预览图生成器:GEN_WIDGET_PREVIEWS=1 手动运行,CI 上自动跳过。
    skip: !_enabled,
  );
}
