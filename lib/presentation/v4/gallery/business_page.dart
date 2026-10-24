import 'package:flutter/material.dart';
import 'gallery_catalog.dart';
import 'exchange_rate_sample.dart';
import 'budget_sample.dart';
import '../../../utils/account_type_utils.dart';
import '../../../widgets/biz/bee_icon.dart';
import 'transaction_row_states.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';

const businessCases = [
  '首页品牌',
  '金额与预算',
  '账单行与批量操作',
  '分类与自定义图标',
  '二级分类排行',
  '计算器与记账表单',
  '标签多选',
  '币种与账户选择',
  '补充汇率',
  '账本与操作菜单',
  '同步全部状态',
  '资料与紧凑余额',
  '昵称编辑',
  '附件平铺与预览',
  '导入字段映射',
  '初始化五步',
  'AI 授权与配置',
  '滚轮日期时间',
  '小票与分享',
  '年度账单',
  '快捷记账',
  '统计图表',
  '账户卡片',
  '预算与目标',
  '详情信息',
  'AI 消息与执行',
  '安全输入',
  '分类选择器',
  '账户选择器',
  '交易行状态全集',
  '真实账本联动',
  '账本选择器',
  '分类管理列表',
  '转账账户对',
  '搜索汇总与批量操作',
  '分类账户标签详情',
  '配置选择与预览',
  '分类图标编辑',
  '账户类型选择',
  '账户余额调整',
  '资产总览与账户设置',
  '标签管理库',
  '记账提醒设置',
  '历史备注偏好',
  '皮肤预览与选择',
  '文件导入导出任务',
  '附件与图标预览库',
  '分类迁移选择对',
  '全局汇率与编辑',
  '预算概览与分类进度'
];
const demoTags = [
  BeeTagData('work', '工作日', Color(0xffaa8b29)),
  BeeTagData('daily', '日常', Color(0xff448f5c)),
  BeeTagData('travel', '旅行', Color(0xff219c9c)),
  BeeTagData('read', '阅读', Color(0xff4a92ca)),
  BeeTagData('shop', '网购', Color(0xff826acb))
];

class BusinessAcceptancePage extends StatefulWidget {
  const BusinessAcceptancePage(
      {super.key,
      this.isolatedCase,
      this.liveData,
      this.tagLibraryData,
      this.reminderData,
      this.noteHistoryData,
      this.skinData,
      this.fileWorkflowData,
      this.attachmentLibraryData,
      this.categoryMigrationData,
      this.exchangeRateData,
      this.budgetData});
  final Widget? liveData,
      tagLibraryData,
      reminderData,
      noteHistoryData,
      skinData,
      fileWorkflowData,
      attachmentLibraryData,
      categoryMigrationData,
      exchangeRateData,
      budgetData;
  final int? isolatedCase;
  @override
  State<BusinessAcceptancePage> createState() => _BusinessAcceptancePageState();
}

class _BusinessAcceptancePageState extends State<BusinessAcceptancePage> {
  String? librarySelectedId;
  bool overwriteArchive = false;
  String demoSkin = 'none';
  int historyScope = 0, historySort = 0;
  String historyLimit = '20';
  bool historyInvalid = false;
  bool reminderEnabled = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);
  int step = 0, recordingType = 0, onboardingChoice = 0;
  int ledgerMonthStart = 1;
  final ledgerNameController = TextEditingController(text: '日常生活');
  @override
  void dispose() {
    ledgerNameController.dispose();
    super.dispose();
  }

  Future<void> _reminderTime() async {
    var draft = reminderTime;
    final value = await showBeeSheet<TimeOfDay>(context,
        title: '选择时间',
        child: StatefulBuilder(
            builder: (context, update) => BeeTimeWheels(
                value: draft, onChanged: (v) => update(() => draft = v))),
        footer: BeeButton(
            label: '使用所选时间', onPressed: () => Navigator.pop(context, draft)));
    if (mounted && value != null) {
      setState(() {
        reminderTime = value;
        event = '提醒时间 ${value.format(context)}';
      });
    }
  }

  String? chosenCategory = 'lunch', chosenAccount = 'wechat';
  bool brand = true,
      hidden = false,
      selected = false,
      batch = false,
      foreign = false;
  String nickname = '小满',
      ledger = '日常生活',
      event = '等待操作',
      currency = 'CNY',
      calc = '0',
      rate = '7.20';
  String recordingNote = '午餐';
  Set<String> configScopes = {'ledgers', 'accounts', 'categories', 'tags'};
  String pin = '';
  bool balanceAdjustmentRecord = false;
  bool overviewHidden = false, accountsEnabled = true;
  int overviewChart = 0;
  int _chartSlice = -1;
  String accountType = 'cash', accountTypeGroup = 'daily';
  String categoryIcon = 'coffee';
  BeeCategoryIconSource categoryIconSource = BeeCategoryIconSource.preset;
  DateTime date = DateTime(2026, 10, 23, 12, 30);
  Set<String> tags = {'work'}, expanded = {};
  Map<String, String?> mapping = {
    'amount': '金额',
    'date': '交易时间',
    'category': '类别'
  };
  bool categoryEmpty = false;
  final categoryOrder = ['food', 'travel'];
  List<BeeManagedCategory> get demoCategoryChildren => [
        const BeeManagedCategory(
            id: 'breakfast',
            name: '早餐',
            detail: '8 笔',
            icon: BeeLineIcon('Coffee', size: 20)),
        const BeeManagedCategory(
            id: 'lunch',
            name: '午餐',
            detail: '14 笔',
            icon: BeeLineIcon('Utensils', size: 20)),
        const BeeManagedCategory(
            id: 'coffee',
            name: '咖啡',
            detail: '2 笔',
            icon: BeeLineIcon('Coffee', size: 20)),
        BeeManagedCategory(
            id: 'milk',
            name: '奶茶',
            detail: '0 笔',
            icon: Image.asset('assets/v4_gallery/category-milk-tea.png',
                fit: BoxFit.contain)),
      ];
  Future<void> demoManageChildren(String parent) => showBeeDialog<void>(context,
          title: '餐饮',
          child: BeeCategoryChildrenGrid(
              items: demoCategoryChildren,
              emptyLabel: '暂无二级分类',
              onEdit: (id) {
                Navigator.pop(context);
                record('编辑二级分类 $id');
              }),
          actions: [
            BeeButton(
                label: '新增',
                kind: BeeButtonKind.secondary,
                onPressed: () {
                  Navigator.pop(context);
                  record('新增二级分类 $parent');
                }),
            BeeButton(
                label: '编辑父分类',
                kind: BeeButtonKind.secondary,
                onPressed: () {
                  Navigator.pop(context);
                  record('编辑一级分类 $parent');
                }),
          ]);
  List<BeeAttachment> get attachments => ['payment', 'receipt', 'order']
      .map((s) => BeeAttachment(
          id: s,
          image: AssetImage('assets/v4_gallery/attachment-$s.png'),
          label: '合成凭证 $s',
          info: 'PNG · 示例图片'))
      .toList();
  void record(String value) => setState(() => event = value);
  List<BeeAction> get actions => const [
        BeeAction(id: 'edit', label: '编辑', icon: BeeLineIcon('PencilLine')),
        BeeAction(id: 'budget', label: '预算', icon: BeeLineIcon('Shapes')),
        BeeAction(id: 'members', label: '成员', icon: BeeLineIcon('Baby')),
        BeeAction(
            id: 'local',
            label: '仅删除本地',
            icon: BeeLineIcon('Trash2'),
            danger: true),
        BeeAction(
            id: 'delete',
            label: '删除账本',
            icon: BeeLineIcon('Trash2'),
            danger: true)
      ];
  Future<void> menu() => showBeeSheet<void>(context,
      title: '账本操作',
      child: BeeActionMenu(
          actions: actions,
          onSelected: (id) {
            Navigator.pop(context);
            if (id == 'delete' || id == 'local') {
              showBeeDialog<void>(context,
                  title: id == 'local' ? '仅删除本地副本？' : '删除整个账本？',
                  child: Text(id == 'local' ? '云端数据会保留。' : '此操作同时移除该账本，请谨慎确认。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    BeeButton(
                        label: '确认删除',
                        kind: BeeButtonKind.danger,
                        onPressed: () {
                          Navigator.pop(context);
                          record('确认操作 $id');
                        })
                  ]);
            } else {
              record('账本操作 $id');
            }
          }));
  Future<void> _openLedgerMenu(BuildContext _, {String? name}) async {
    final selected = name ?? ledger;
    final id = await showBeeDialog<String>(context,
        title: '账本操作',
        child: BeeLedgerActions(
            name: selected,
            subtitle: 'CNY · 48 笔',
            shared: selected == '家庭账本',
            details: const Text('ID: 1'),
            actions: actions,
            onSelected: (id) => Navigator.pop(context, id)));
    if (!mounted || id == null) return;
    if (id == 'edit') {
      await _openLedgerEditor(selected);
    } else if (id == 'delete' || id == 'local') {
      final confirmed = await showBeeConfirm(context,
          title: id == 'local' ? '仅删除本地副本？' : '删除整个账本？',
          message: id == 'local' ? '云端数据会保留。' : '此操作会移除所选账本，请确认。',
          confirmLabel: '确认删除',
          cancelLabel: '取消',
          danger: true);
      if (mounted && confirmed) record('确认操作 $id');
    } else {
      record('账本操作 $id');
    }
  }

  Future<void> _pickLedgerCurrency() async {
    final next = await showBeeSheet<String>(context,
        title: '账本本位币',
        child: SizedBox(
            height: 280,
            child: BeeCurrencyPicker(
                currencies: const [
                  BeeCurrencyChoice(code: 'CNY', name: '人民币', symbol: '¥'),
                  BeeCurrencyChoice(code: 'USD', name: '美元', symbol: 'US＄'),
                  BeeCurrencyChoice(code: 'EUR', name: '欧元', symbol: '€')
                ],
                selected: currency,
                searchLabel: '搜索币种',
                emptyLabel: '没有匹配币种',
                onSelected: (code) => Navigator.pop(context, code))));
    if (next != null && mounted) setState(() => currency = next);
  }

  Future<void> _pickLedgerDay() async {
    final day = await showBeeSheet<int>(context,
        title: '月起始日',
        child: SingleChildScrollView(
            child: BeeMonthStartDayGrid(
                value: ledgerMonthStart,
                hint: '每月1–28日，保留原账本周期范围。',
                onSelected: (day) => Navigator.pop(context, day))));
    if (day != null && mounted) setState(() => ledgerMonthStart = day);
  }

  Future<void> _openLedgerEditor(String name) async {
    ledgerNameController.text = name;
    await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .26),
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => BeeDialog(
                    title: const Text('编辑账本'),
                    content: BeeLedgerEditorForm(
                        nameController: ledgerNameController,
                        nameLabel: '名称',
                        currencyLabel: '账本本位币',
                        currency: currency,
                        periodLabel: '月起始日',
                        period: '每月 $ledgerMonthStart 日',
                        onCurrency: () async {
                          await _pickLedgerCurrency();
                          if (ctx.mounted) update(() {});
                        },
                        onPeriod: () async {
                          await _pickLedgerDay();
                          if (ctx.mounted) update(() {});
                        }),
                    actions: [
                      BeeButton(
                          label: '取消',
                          kind: BeeButtonKind.secondary,
                          onPressed: () => Navigator.pop(ctx)),
                      BeeButton(
                          label: '保存',
                          onPressed: () {
                            final name = ledgerNameController.text;
                            Navigator.pop(ctx);
                            record('账本草稿 $name');
                          })
                    ])));
  }

  @override
  Widget build(BuildContext context) => GalleryCatalog(
      id: 'business',
      title: '业务组件',
      labels: businessCases,
      event: event,
      isolatedCase: widget.isolatedCase,
      sampleBuilder: (index) => _sample(index));
  Widget _sample(int index) => switch (index) {
        0 => Column(children: [
            BeeHomeIdentity(
                name: '蜜蜂记账',
                pageTitle: '明细',
                ledger: ledger,
                logo: Image.asset('assets/logo2.png'),
                showBrand: brand,
                onLedgerTap: () => record('切换账本'),
                actions: [
                  IconButton(
                      tooltip: 'AI 记账',
                      onPressed: () => record('打开 AI'),
                      icon: const BeeLineIcon('Shapes')),
                  IconButton(
                      tooltip: '搜索账单',
                      onPressed: () => record('搜索账单'),
                      icon: const Icon(Icons.search)),
                  IconButton(
                      tooltip: '更多',
                      onPressed: menu,
                      icon: const BeeLineIcon('Ellipsis'))
                ]),
            SwitchListTile(
                title: const Text('显示品牌'),
                value: brand,
                onChanged: (v) => setState(() => brand = v)),
            const Text('紧凑屏：上滑顶部卡片，保留账单列表的滚动区域'),
            const SizedBox(height: 8),
            SizedBox(
                height: 300,
                child: BeeHomeLayout(
                    header: const Padding(
                        padding: EdgeInsets.all(16),
                        child: BeeMoney(amount: '3,286.50', prefix: '¥')),
                    reminders: const SizedBox.shrink(),
                    journal: BeeSurface(
                        child: Column(children: [
                      const BeeTransactionStreamHeader(
                          title: '全部账单', count: '3 笔', actions: []),
                      Expanded(
                          child: ListView(
                              children: [
                        '午餐 · ¥32.00',
                        '咖啡 · ¥18.00',
                        '交通 · ¥6.00'
                      ].map((text) => ListTile(title: Text(text))).toList()))
                    ])))),
          ]),
        1 => Column(children: [
            BeeSummaryCard(
                title: '2026年 10月',
                amount: '3,286.50',
                prefix: '¥',
                amountLabel: '本月支出',
                currencyLabel: '人民币 · CNY',
                privacyLabel: hidden ? '显示金额' : '隐藏金额',
                onPrivacyTap: () => setState(() => hidden = !hidden),
                incomeLabel: '本月收入',
                income: '12,000.00',
                expenseLabel: '本月结余',
                expense: '8,713.50',
                hidden: hidden,
                onContextTap: () => record('选择月份'),
                budget: BeeBudgetStrip(
                    progress: .64,
                    label: hidden ? '月预算 ••••' : '月预算 ¥5,000.00',
                    remaining: hidden ? '剩余 ••••' : '剩余 ¥1,713.50',
                    onTap: () => record('预算管理'))),
            SwitchListTile(
                title: const Text('隐藏金额与折算'),
                value: hidden,
                onChanged: (v) => setState(() => hidden = v))
          ]),
        2 => Column(children: [
            BeeTransactionStreamHeader(title: '全部明细', count: '27笔', actions: [
              BeeIconButton(
                  label: '账单日历',
                  icon: const BeeLineIcon('CalendarDays', size: 17),
                  onPressed: () => record('日历')),
              BeeIconButton(
                  label: '筛选账单',
                  icon: const BeeLineIcon('SlidersHorizontal', size: 17),
                  onPressed: () => record('筛选')),
              TextButton(
                  onPressed: () => record('批量操作'), child: const Text('批量')),
            ]),
            BeeTransactionDayHeader(
                title: '今天',
                date: '10月20日',
                totals: hidden ? const [] : const ['支出 123.20']),
            BeeSurface(
                padding: EdgeInsets.zero,
                child: BeeTransactionRow(
                    title: '午间食堂',
                    amount: foreign ? '−US\$12.00' : '−32.00',
                    converted: foreign ? '≈ ¥86.40' : null,
                    subtitle: '午餐 · 微信',
                    icon: const BeeCategoryIcon(name: 'Utensils'),
                    tags: demoTags.take(1).toList(),
                    hidden: hidden,
                    selected: batch ? selected : null,
                    onSelected: (v) => setState(() => selected = v),
                    onCategoryTap: () => record('进入分类详情'),
                    onTap: () => record('进入账单详情'),
                    onMenu: () => showBeeSheet<void>(context,
                        title: '账单操作',
                        child: BeeActionMenu(
                            actions: const [
                              BeeAction(
                                  id: 'copy',
                                  label: '复制账单',
                                  icon: BeeLineIcon('BookOpen')),
                              BeeAction(
                                  id: 'receipt',
                                  label: '生成小票',
                                  icon: BeeLineIcon('ReceiptText'))
                            ],
                            onSelected: (v) {
                              Navigator.pop(context);
                              record(v);
                            })),
                    onDeleteRequested: () async {
                      record('左滑删除：需确认');
                    },
                    deleteLabel: '删除',
                    hasAttachment: true)),
            const SizedBox(height: 12),
            BeeToggleRow(
                title: '显示外币折算',
                value: foreign,
                onChanged: (v) => setState(() => foreign = v)),
            BeeButton(
                label: '批量操作',
                kind: BeeButtonKind.secondary,
                onPressed: () => setState(() => batch = !batch)),
            if (batch)
              BeeBatchBar(
                  selectionLabel: selected ? '已选 1 笔' : '未选择',
                  total: selected ? '¥86.40' : '¥0.00',
                  actions: [
                    BeeButton(
                        label: '修改分类',
                        kind: BeeButtonKind.secondary,
                        onPressed: selected ? () => record('批量分类') : null),
                    BeeButton(
                        label: '删除',
                        kind: BeeButtonKind.danger,
                        onPressed: selected ? () => record('批量删除确认') : null)
                  ])
          ]),
        3 => BeeSurface(
              child: Wrap(spacing: 16, runSpacing: 16, children: [
            RecordingCategoryTile(
                label: '餐饮',
                icon: const BeeCategoryIcon(name: 'Utensils', size: 24),
                selected: selected,
                expanded: expanded.contains('food'),
                hasChildren: true,
                onTap: () => setState(() {
                      selected = !selected;
                      expanded.contains('food')
                          ? expanded.remove('food')
                          : expanded.add('food');
                    })),
            const BeeCategoryIcon(
                image: AssetImage('assets/logo2.png'), size: 44),
            const BeeCategoryIcon(
                image: AssetImage('assets/v4_gallery/attachment-payment.png'),
                size: 44,
                crop: true),
            const BeeCategoryIcon(label: '图片不可用时的默认图标', size: 44),
            if (expanded.contains('food'))
              ...['午餐', '晚餐'].map((s) => RecordingSubcategoryChip(
                  label: s,
                  icon: const BeeLineIcon('Utensils', size: 16),
                  selected: event == s,
                  onTap: () => record(s))),
            RecordingCategoryTile(
                label: '更多分类',
                icon: const BeeLineIcon('Grid2x2'),
                onTap: () => showBeeSheet<void>(context,
                    title: '更多分类',
                    child: BeeChoicePicker<String>(
                        items: const [
                          BeeChoice(
                              value: 'medical',
                              title: '医疗',
                              leading: BeeCategoryIcon(name: 'HeartPulse')),
                          BeeChoice(
                              value: 'pet',
                              title: '宠物',
                              leading: BeeCategoryIcon(name: 'PawPrint'))
                        ],
                        selected: null,
                        searchLabel: '搜索分类',
                        emptyLabel: '没有匹配分类',
                        onSelected: (v) {
                          Navigator.pop(context);
                          record('选择分类 $v');
                        })))
          ])),
        4 => BeeSurface(
              child: BeeCategoryRanking(
                  items: const [
                BeeRankItem(
                    id: 'food',
                    label: '餐饮',
                    amount: '1,199.57',
                    fraction: .8,
                    icon: BeeCategoryIcon(name: 'Utensils'),
                    children: [
                      BeeRankItem(
                          id: 'lunch',
                          label: '午餐',
                          amount: '680.00',
                          fraction: .5,
                          icon: BeeCategoryIcon(name: 'Utensils', size: 24)),
                      BeeRankItem(
                          id: 'dinner',
                          label: '晚餐',
                          amount: '519.57',
                          fraction: .4,
                          icon: BeeCategoryIcon(name: 'Utensils', size: 24))
                    ]),
                BeeRankItem(
                    id: 'home',
                    label: '居家',
                    amount: '640.87',
                    fraction: .4,
                    icon: BeeCategoryIcon(name: 'House'))
              ],
                  expanded: expanded,
                  onExpand: (id) => setState(() => expanded.contains(id)
                      ? expanded.remove(id)
                      : expanded.add(id)),
                  onDetail: (v) => record('分类详情 $v'))),
        5 => Column(children: [
            RecordingHeader(
                labels: const ['支出', '收入', '转账'],
                selectedIndex: recordingType,
                onChanged: (v) => setState(() => recordingType = v),
                backLabel: '返回',
                onBack: () => record('返回'),
                moreLabel: '更多选项',
                onMore: () => record('记账选项')),
            RecordingAmountCard(
                currency: Text(currency),
                ledger: Text(ledger),
                amount: calc,
                hint: '支持 + − × ÷ 四则运算',
                symbol: '¥'),
            const SizedBox(height: 12),
            RecordingDetailsCard(
                note: TextFormField(
                    initialValue: recordingNote,
                    decoration: const InputDecoration(
                        prefixIcon: BeeLineIcon('PencilLine', size: 16),
                        border: InputBorder.none,
                        isDense: true),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => recordingNote = v),
                account: TextButton.icon(
                    onPressed: () => record('选择账户'),
                    icon: const BeeLineIcon('Wallet', size: 16),
                    label: const Text('微信', style: TextStyle(fontSize: 11))),
                date: TextButton.icon(
                    onPressed: () => record('选择日期'),
                    icon: const BeeLineIcon('CalendarDays', size: 16),
                    label:
                        const Text('10月20日', style: TextStyle(fontSize: 11))),
                tags: Align(
                    alignment: Alignment.centerRight,
                    child: BeeTag(
                        tag: demoTags.first,
                        compact: true,
                        onTap: () => record('选择标签'))),
                attachment: IconButton(
                    tooltip: '添加附件',
                    onPressed: () => record('添加附件'),
                    icon: const BeeLineIcon('ImagePlus', size: 18))),
            const SizedBox(height: 8),
            RecordingKeypad(
                deleteLabel: '退格，长按清空',
                onDigit: (v) =>
                    setState(() => calc = calc == '0' ? v : '$calc$v'),
                onOperator: (v) => record('运算 $v，由页面控制器计算'),
                onBackspace: () => setState(() => calc =
                    calc.length > 1 ? calc.substring(0, calc.length - 1) : '0'),
                onClear: () => setState(() => calc = '0'))
          ]),
        6 => BeeSurface(
              child: Column(children: [
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: demoTags
                    .where((t) => tags.contains(t.id))
                    .map((t) => BeeTag(tag: t))
                    .toList()),
            const SizedBox(height: 12),
            BeeButton(
                label: '选择标签',
                onPressed: () => showBeeSheet<void>(context,
                    title: '选择标签',
                    child: BeeTagPicker(
                        tags: [
                          ...demoTags,
                          ...List.generate(
                              35,
                              (i) => BeeTagData('custom$i', '自定义标签 $i',
                                  demoTags[i % 5].color))
                        ],
                        initial: tags,
                        recent: [demoTags[0], demoTags[2]],
                        recentLabel: '最近使用',
                        allLabel: '全部标签',
                        searchLabel: '搜索标签',
                        selectionLabel: '可选择多个标签',
                        clearLabel: '清空',
                        confirmLabel: '使用所选标签',
                        countLabel: (n) => '已选 $n 个标签',
                        emptyLabel: '没有匹配标签',
                        onCreate: () => record('新建标签'),
                        createLabel: '新建标签',
                        onConfirm: (v) {
                          setState(() => tags = v);
                          Navigator.pop(context);
                          record('已选 ${v.length} 个标签');
                        })))
          ])),
        7 => BeeSurface(
              child: Column(children: [
            BeeButton(
                label: '选择币种 · $currency',
                onPressed: () => showBeeSheet<void>(context,
                    title: '选择币种',
                    child: BeeCurrencyPicker(
                        currencies: const [
                          BeeCurrencyChoice(
                              code: 'CNY',
                              name: '人民币',
                              symbol: '¥',
                              common: true),
                          BeeCurrencyChoice(
                              code: 'USD',
                              name: '美元',
                              symbol: 'US\$',
                              rateHint: '1 USD ≈ 7.20 CNY',
                              common: true),
                          BeeCurrencyChoice(
                              code: 'JPY',
                              name: '日元',
                              symbol: 'JP¥',
                              rateHint: '1 JPY ≈ 0.047 CNY')
                        ],
                        selected: currency,
                        searchLabel: '代码、名称或符号',
                        emptyLabel: '没有匹配币种',
                        onSelected: (v) {
                          setState(() => currency = v);
                          Navigator.pop(context);
                          record('已选 $v；页面控制器应重置账户');
                        }))),
            const SizedBox(height: 10),
            BeeButton(
                label: '选择账户',
                kind: BeeButtonKind.secondary,
                onPressed: () => showBeeSheet<void>(context,
                    title: '选择账户 · $currency',
                    child: BeeChoicePicker<String>(
                        items: [
                          const BeeChoice(value: 'none', title: '暂不设置'),
                          BeeChoice(
                              value: 'cash',
                              title: '$currency 现金',
                              subtitle: '余额由宿主传入',
                              leading: const BeeLineIcon('Wallet'))
                        ],
                        selected: null,
                        searchLabel: '搜索账户',
                        emptyLabel: '无账户',
                        onSelected: (v) {
                          Navigator.pop(context);
                          record('选择账户 $v');
                        })))
          ])),
        8 => BeeSurface(
              child: Column(children: [
            RecordingConversionSummary(
                label: '折合 CNY',
                value:
                    '≈ ¥${(12 * (double.tryParse(rate) ?? 7.2)).toStringAsFixed(2)}',
                onTap: _editRate),
            const SizedBox(height: 12),
            BeeStatus(
                label: '缺少本笔汇率',
                detail: '请填写有效正数后保存',
                tone: BeeTone.warning,
                action: BeeButton(label: '补充汇率', onPressed: () => _editRate())),
            const SizedBox(height: 12),
            Text('当前示例汇率 $rate')
          ])),
        9 => Column(children: [
            ...['日常生活', '家庭账本'].map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Builder(
                    builder: (cardContext) => BeeLedgerCard(
                            name: s,
                            subtitle:
                                s == '家庭账本' ? '共享账本 · 2位成员' : '个人账本 · 人民币',
                            icon: const BeeLineIcon('BookOpen', size: 18),
                            income: '¥12,000.00',
                            expense: '¥3,286.50',
                            incomeLabel: '本月收入',
                            expenseLabel: '本月支出',
                            currentLabel: '当前',
                            current: ledger == s,
                            onSelect: () => setState(() => ledger = s),
                            onMenu: () => _openLedgerMenu(cardContext, name: s),
                            actions: [
                              BeeButton(
                                  label: '预算管理',
                                  compact: true,
                                  icon: const BeeLineIcon('ChartPie', size: 14),
                                  kind: BeeButtonKind.secondary,
                                  onPressed: () => record('$s 预算')),
                              BeeButton(
                                  label: s == '家庭账本' ? '成员管理' : '编辑账本',
                                  compact: true,
                                  icon: BeeLineIcon(
                                      s == '家庭账本'
                                          ? 'Users'
                                          : 'SlidersHorizontal',
                                      size: 14),
                                  kind: BeeButtonKind.secondary,
                                  onPressed: () => _openLedgerEditor(s))
                            ])))),
            BeeSurface(
                child: BeeLedgerEditorForm(
                    nameController: ledgerNameController,
                    nameLabel: '名称',
                    currencyLabel: '账本本位币',
                    currency: currency,
                    periodLabel: '月起始日',
                    period: '每月 $ledgerMonthStart 日',
                    onCurrency: _pickLedgerCurrency,
                    onPeriod: _pickLedgerDay)),
            const SizedBox(height: 12),
            BeeSurface(
                child: BeeMonthStartDayGrid(
                    value: ledgerMonthStart,
                    hint: '月起始日：1–28，选择仅修改草稿。',
                    onSelected: (day) =>
                        setState(() => ledgerMonthStart = day))),
          ]),
        10 => BeeSurface(
            padding: EdgeInsets.zero,
            child: Column(
                children: BeeSyncState.values
                    .map((s) => BeeSyncStatus(
                        state: s,
                        title: '数据同步',
                        label: const [
                          '未登录',
                          '未配置云端',
                          '云端暂无数据',
                          '已同步',
                          '本地有更新',
                          '云端有更新',
                          '本地与云端有差异',
                          '检查中',
                          '同步中',
                          '离线',
                          '状态获取失败'
                        ][s.index],
                        detail: s == BeeSyncState.error
                            ? '网络请求失败，本地数据已保留'
                            : null,
                        progress: s == BeeSyncState.syncing ? .46 : null,
                        onTap: () => record('同步详情 ${s.name}'),
                        action:
                            s == BeeSyncState.error || s == BeeSyncState.offline
                                ? TextButton(
                                    onPressed: () => record('同步重试'),
                                    child: const Text('重试'))
                                : null))
                    .toList())),
        11 => Column(children: [
            BeeProfile(
                nickname: nickname,
                greeting: '你好，',
                subtitle: '简单记录，安心生活',
                avatar: Image.asset('assets/logo2.png'),
                onEdit: _editNickname,
                onTap: () => record('资料菜单')),
            const SizedBox(height: 16),
            BeeLedgerBalance(
                ledger: ledger,
                amount: '12,860.50',
                prefix: '¥',
                balanceLabel: '当前余额 · CNY',
                days: '268',
                daysLabel: '天',
                count: '1,268',
                countLabel: '笔',
                stats: '268 天 · 1,268 笔',
                hidden: hidden,
                onLedgerTap: menu,
                privacyLabel: hidden ? '显示金额' : '隐藏金额',
                onPrivacyTap: () => setState(() => hidden = !hidden))
          ]),
        12 => BeeSurface(
            child:
                BeeButton(label: '编辑昵称 · $nickname', onPressed: _editNickname)),
        13 => Column(children: [
            for (final n in [1, 2, 3]) ...[
              BeeSurface(
                  child: BeeAttachments(
                      items: attachments.take(n).toList(),
                      title: '附件',
                      countLabel: '$n张',
                      onOpen: (i) => showBeeSheet<void>(context,
                          title: '附件预览',
                          child: BeeAttachmentViewer(
                              items: attachments.take(n).toList(),
                              initialIndex: i)))),
              const SizedBox(height: 12)
            ],
            BeeButton(
                label: '添加示例图片',
                onPressed: () => showBeeSheet<void>(context,
                    title: '添加图片',
                    child: BeeAttachmentSources(
                        cameraLabel: '拍照',
                        galleryLabel: '从相册选择',
                        onCamera: () {
                          Navigator.pop(context);
                          record('选择拍照来源');
                        },
                        onGallery: () {
                          Navigator.pop(context);
                          record('选择相册来源');
                        }))),
            const SizedBox(height: 8),
            BeeButton(
                label: '全屏图片预览',
                kind: BeeButtonKind.secondary,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (screenContext) => Scaffold(
                            body: BeeAttachmentViewer(
                                items: attachments,
                                fullScreen: true,
                                onClose: () =>
                                    Navigator.pop(screenContext)))))),
          ]),
        14 => BeeSurface(
            child: BeeImportMapping(
                sourceLabel: '支付宝 CSV · 共 268 条 · 示例预览',
                fields: [
                  for (final id in ['amount', 'date', 'category'])
                    BeeFieldMapping(
                        id: id,
                        target: const {
                          'amount': '金额',
                          'date': '日期',
                          'category': '分类'
                        }[id]!,
                        source: mapping[id],
                        sourceOptions: const ['金额', '交易时间', '类别', '备注'],
                        required: id != 'category',
                        preview: const {
                          'amount': '−32.00',
                          'date': '2026-10-23',
                          'category': '餐饮'
                        }[id])
                ],
                onChanged: (id, v) => setState(() => mapping[id] = v),
                extraLabel: '额外字段与高级选项',
                extra: const BeeField(
                    label: '跳过前几行',
                    hint: '0',
                    keyboardType: TextInputType.number))),
        15 => BeeSurface(
              child: Column(children: [
            const Text('启动品牌 · 76', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            BeeBrandMark(
                mark: BeeIcon(
                    size: 48, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 24),
            BeeOnboardingStep(
                step: step,
                total: 5,
                brandTitle: '蜜蜂记账',
                onStep: (v) => setState(() {
                      step = v;
                      onboardingChoice = 0;
                    }),
                title: const [
                  '欢迎使用蜜蜂记账',
                  '币种',
                  '选择分类模式',
                  '可选的云同步',
                  '开源透明 · 社群驱动'
                ][step],
                description: '简单记录每一天，选项稍后也可修改',
                illustration: BeeIcon(
                    size: 27, color: Theme.of(context).colorScheme.primary),
                options: Column(children: [
                  for (var i = 0; i < (step == 2 ? 3 : 2); i++)
                    if (step == 2)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BeeOnboardingModeCard(
                              title: const ['一级分类', '二级分类', '不创建分类'][i],
                              description: const [
                                '简单直观，快速记账',
                                '精细管理，清晰明了',
                                '完全自定义，按需添加'
                              ][i],
                              icon: BeeLineIcon(
                                  const ['Grid2x2', 'Network', 'Plus'][i]),
                              preview: const Text('保留原分类模式及其说明',
                                  style: TextStyle(fontSize: 10)),
                              selected: onboardingChoice == i,
                              onTap: () => setState(() {
                                    onboardingChoice = i;
                                    event = '选择分类模式';
                                  })))
                    else
                      BeeOnboardingChoice(
                          title: const [
                            ['简体中文', 'English'],
                            ['人民币', '美元'],
                            ['一级分类', '二级分类'],
                            ['完全离线使用', '可选云同步'],
                            ['开源透明', '隐私优先']
                          ][step][i],
                          subtitle: step == 1 ? const ['CNY', 'USD'][i] : null,
                          compact: step == 1,
                          selected: onboardingChoice == i,
                          onTap: () => setState(() {
                                onboardingChoice = i;
                                event = '选择初始化选项';
                              })),
                ]),
                next: BeeButton(
                    label: step == 4 ? '完成' : '继续',
                    onPressed: () => setState(() {
                          if (step == 4) {
                            step = 0;
                            event = '初始化完成';
                          } else {
                            step++;
                          }
                        })),
                restore: TextButton(
                    onPressed: () => record('恢复已有数据'),
                    child: const Text('已有数据？恢复备份'))),
            const SizedBox(height: 20),
            BeeBackupFileCard(
                title: '配置备份',
                description: 'YAML · 账本与应用配置',
                icon: const BeeLineIcon('FileCode2'),
                actionLabel: '选择备份文件',
                fileName: event == '选择备份文件' ? 'beecount-config.yml' : null,
                onChoose: () => record('选择备份文件')),
          ])),
        16 => BeeSurface(
              child: Column(children: [
            BeeButton(
                label: '打开 AI 授权弹窗',
                onPressed: () => showBeeDialog<void>(context,
                    title: '允许 AI 辅助记账？',
                    child: BeeAuthorization(
                        description: '处理本次内容以识别账单；由你确认后保存。',
                        permissions: const ['访问本次输入内容', '读取分类与账户名称'],
                        deny: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              record('拒绝授权');
                            },
                            child: const Text('不允许')),
                        once: BeeButton(
                            label: '仅本次允许',
                            kind: BeeButtonKind.secondary,
                            onPressed: () {
                              Navigator.pop(context);
                              record('本次授权');
                            }),
                        always: BeeButton(
                            label: '始终允许',
                            onPressed: () {
                              Navigator.pop(context);
                              record('持久授权由页面处理');
                            })),
                    actions: const [])),
            const SizedBox(height: 12),
            BeeButton(
                label: '编辑 AI 配置',
                kind: BeeButtonKind.secondary,
                onPressed: () => showBeeDialog<void>(context,
                        title: 'AI 配置',
                        child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BeeField(label: '服务地址', hint: 'https://…'),
                              SizedBox(height: 12),
                              BeeField(label: 'API Key', obscure: true)
                            ]),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消')),
                          BeeButton(
                              label: '保存',
                              onPressed: () {
                                Navigator.pop(context);
                                record('保存示例配置');
                              })
                        ]))
          ])),
        17 => BeeSurface(
              child: Column(children: [
            Text('$date'),
            BeeDateWheels(
                value: date,
                onChanged: (v) => setState(() => date = v),
                showTime: true),
            BeeButton(
                label: '打开日期弹层',
                onPressed: () {
                  var draft = date;
                  showBeeSheet<void>(context,
                      title: '选择日期',
                      child: StatefulBuilder(
                          builder: (ctx, update) =>
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                BeeDateWheels(
                                    value: draft,
                                    onChanged: (v) => update(() => draft = v)),
                                BeeButton(
                                    label: '确定',
                                    onPressed: () {
                                      setState(() => date = draft);
                                      Navigator.pop(ctx);
                                    })
                              ])));
                })
          ])),
        18 => BeeReceipt(
            title: '账单小票',
            amount: '−US\$12.00',
            converted: '≈ ¥86.40',
            category: '餐饮 / 午餐',
            date: '2026年10月23日 12:30',
            brand: '蜜蜂记账 · 简单记录，安心生活',
            note: '午间食堂',
            tags: demoTags.take(1).toList()),
        19 => BeeAnnualSummary(
            year: '2026',
            title: '认真生活的每一天',
            amount: '¥38,208.50',
            metrics: const {'记账天数': '268', '账单笔数': '1,268', '储蓄率': '32%'},
            chart: BeeBarChart(
                items: const [
                  BeeChartBar('1月', 30),
                  BeeChartBar('2月', 45),
                  BeeChartBar('3月', 25),
                  BeeChartBar('4月', 60),
                  BeeChartBar('5月', 38),
                  BeeChartBar('6月', 52)
                ],
                valueLabel: (v) => '${v.toInt()}',
                onSelected: (v) => record('月份 $v')),
            footer: '蜜蜂记账 · 我的年度账单'),
        21 => BeeSurface(
              child: Column(children: [
            BeeDonutChart(
                items: const [
                  BeeChartSlice(
                      label: '餐饮',
                      value: 1199.57,
                      color: Color(0xfffacb16),
                      valueLabel: '¥1,199.57'),
                  BeeChartSlice(
                      label: '购物',
                      value: 920.22,
                      color: Color(0xff57afa2),
                      valueLabel: '¥920.22'),
                  BeeChartSlice(
                      label: '居家',
                      value: 640.87,
                      color: Color(0xff9486d4),
                      valueLabel: '¥640.87')
                ],
                centerLabel: _chartSlice < 0
                    ? '本月支出'
                    : const [
                        '餐饮\n¥1,199.57',
                        '购物\n¥920.22',
                        '居家\n¥640.87'
                      ][_chartSlice],
                selected: _chartSlice,
                onSelected: (v) {
                  setState(() => _chartSlice = v);
                  record(v < 0 ? '取消图表选中' : '统计分类 $v');
                }),
            const SizedBox(height: 20),
            const BeeTrendChart(
                values: [12, 8, 24, 16, 30, 21, 34], label: '本月开支趋势')
          ])),
        20 => BeeSurface(
              child: Column(children: [
            BeeQuickAddTrigger(
                label: '记一笔',
                menuLabel: '快捷记账菜单',
                hint: '长按后滑向目标，松手进入',
                cancelLabel: '取消',
                actions: const [
                  BeeAction(
                      id: 'camera', label: '拍照', icon: BeeLineIcon('Camera')),
                  BeeAction(
                      id: 'gallery', label: '相册', icon: BeeLineIcon('Images')),
                  BeeAction(id: 'voice', label: '语音', icon: BeeLineIcon('Mic')),
                ],
                onTap: () => record('普通记账'),
                onSelected: (v) => record('滑动选择 $v'),
                onCancel: () => record('已取消快捷菜单')),
            const SizedBox(height: 16),
            BeeQuickAdd(
                actions: const [
                  BeeAction(
                      id: 'ai', label: 'AI 记账', icon: BeeLineIcon('Shapes')),
                  BeeAction(
                      id: 'voice',
                      label: '语音',
                      icon: BeeLineIcon('Smartphone')),
                  BeeAction(
                      id: 'image', label: '图片', icon: BeeLineIcon('ImagePlus')),
                  BeeAction(
                      id: 'manual',
                      label: '手动',
                      icon: BeeLineIcon('PencilLine'))
                ],
                onSelected: (v) => record('快捷记账 $v'),
                cancelLabel: '取消',
                onCancel: () => record('取消快捷记账')),
          ])),
        22 => Column(children: [
            BeeAccountCard(
                name: '微信余额',
                currency: 'CNY',
                balance: '¥2,680.50',
                kind: '支付账户',
                icon: const BeeCategoryIcon(name: 'Wallet'),
                onTap: () => record('账户详情'),
                menuLabel: '账户操作',
                actions: const [
                  BeeMenuAction(value: 'edit', label: '编辑'),
                  BeeMenuAction(value: 'hide', label: '隐藏账户')
                ],
                onAction: (v) => record('账户 $v')),
            const SizedBox(height: 12),
            BeeAccountCard(
                name: '信用卡',
                currency: 'USD',
                balance: '−US\$268.00',
                kind: '信用账户',
                icon: const BeeCategoryIcon(name: 'Wallet'),
                liabilityLabel: '待还款',
                excludedLabel: '不计入资产总额',
                onTap: () => record('信用卡详情'),
                menuLabel: '信用卡操作',
                actions: const [BeeMenuAction(value: 'repay', label: '还款')],
                onAction: (v) => record('还款'))
          ]),
        23 => Column(children: [
            BeeBudgetCard(
                title: '本月总预算',
                spentLabel: '已支出',
                spent: '¥3,286.50',
                remainingLabel: '剩余预算',
                remaining: '¥1,713.50',
                progress: .66,
                onTap: () => record('预算详情')),
            const SizedBox(height: 12),
            BeeBudgetCard(
                title: '餐饮预算',
                spentLabel: '已支出',
                spent: '¥1,200.00',
                remainingLabel: '已超支',
                remaining: '¥200.00',
                progress: 1.2,
                overBudget: true,
                warning: '本月餐饮已超出预算',
                onTap: () => record('分类预算详情'))
          ]),
        24 => BeeDetailList(items: [
            BeeDetailItem(
                label: '分类',
                value: const Text('餐饮 / 午餐'),
                onTap: () => record('分类详情')),
            BeeDetailItem(
                label: '账户',
                value: const Text('微信'),
                onTap: () => record('账户详情')),
            const BeeDetailItem(label: '账本', value: Text('日常生活')),
            const BeeDetailItem(label: '日期', value: Text('2026-10-23 12:30')),
            const BeeDetailItem(
                label: '备注', value: Text('这是一条较长的合成备注，用于检查多行信息展示和内容自适应。')),
            BeeDetailItem(
                label: '标签',
                value: Wrap(
                    spacing: 4,
                    children:
                        demoTags.take(2).map((t) => BeeTag(tag: t)).toList()),
                onTap: () => record('标签详情'))
          ]),
        25 => Column(children: [
            const BeeChatMessage(
                author: '我', isUser: true, content: Text('午餐 32 元，微信支付')),
            const SizedBox(height: 12),
            BeeChatMessage(
                author: '蜜蜂 AI',
                content: const Text('识别到 1 笔支出，请确认后保存。'),
                status: const BeeStatus(label: '待确认', tone: BeeTone.warning),
                actions: [
                  BeeButton(label: '确认记账', onPressed: () => record('AI 账单确认')),
                  BeeButton(
                      label: '修改',
                      kind: BeeButtonKind.secondary,
                      onPressed: () => record('编辑识别结果'))
                ]),
            const SizedBox(height: 12),
            const BeeExecutionTimeline(steps: [
              BeeExecutionStep(title: '识别输入内容', tone: BeeTone.success),
              BeeExecutionStep(title: '匹配分类与账户', tone: BeeTone.success),
              BeeExecutionStep(
                  title: '等待用户确认', tone: BeeTone.warning, detail: '确认后才会保存')
            ])
          ]),
        26 => Column(children: [
            SizedBox(
                height: 580,
                child: ColoredBox(
                    color: BeeCardTheme.of(context).canvas,
                    child: BeeSecurityPanel(
                        title: '请设置新密码',
                        subtitle: 'PIN码与生物识别保护隐私',
                        inputBuilder: (compact) => BeePinPad(
                            length: 4,
                            cardKeys: true,
                            compact: compact,
                            filled: pin.length,
                            deleteLabel: '退格',
                            onDigit: (v) => setState(() => pin += v),
                            onDelete: () => setState(() => pin = pin.isEmpty
                                ? ''
                                : pin.substring(0, pin.length - 1)))))),
            BeeButton(
                label: '重置输入',
                kind: BeeButtonKind.quiet,
                onPressed: () => setState(() => pin = ''))
          ]),
        27 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BeeSurface(
                child: SizedBox(
                    height: 430,
                    child: BeeCategoryPicker(
                        items: const [
                          BeeCategoryChoice(
                              id: 'disabled',
                              label: '不可选分类',
                              icon: BeeCategoryIcon(name: 'ShoppingBasket'),
                              enabled: false,
                              detail: '8 笔'),
                          BeeCategoryChoice(
                              id: 'food',
                              label: '餐饮',
                              icon: BeeCategoryIcon(name: 'Utensils'),
                              children: [
                                BeeCategoryChoice(
                                    id: 'lunch',
                                    label: '午餐',
                                    icon: BeeLineIcon('Utensils', size: 16)),
                                BeeCategoryChoice(
                                    id: 'dinner',
                                    label: '晚餐',
                                    icon: BeeLineIcon('Utensils', size: 16))
                              ]),
                          BeeCategoryChoice(
                              id: 'drink',
                              label: '饮品',
                              icon: BeeCategoryIcon(name: 'Coffee'),
                              children: [
                                BeeCategoryChoice(
                                    id: 'coffee',
                                    label: '咖啡',
                                    icon: BeeCategoryIcon(
                                        image: AssetImage('assets/logo2.png'),
                                        size: 20)),
                                BeeCategoryChoice(
                                    id: 'tea',
                                    label: '奶茶',
                                    icon: BeeLineIcon('Coffee', size: 16))
                              ]),
                          BeeCategoryChoice(
                              id: 'travel',
                              label: '交通',
                              icon: BeeCategoryIcon(name: 'TrainFront')),
                        ],
                        selected: chosenCategory,
                        searchLabel: '搜索一级或二级分类',
                        emptyLabel: '没有匹配分类',
                        confirmLabel: '使用分类',
                        cancelLabel: '取消选择',
                        onConfirm: (v) => setState(() {
                              chosenCategory = v;
                              event = '已确认分类 $v';
                            }),
                        onCancel: () => record('分类草稿已取消')))),
            const SizedBox(height: 12),
            const Text('即时选择、笔数与禁用规则'),
            const SizedBox(height: 8),
            BeeSurface(
                child: SizedBox(
                    height: 300,
                    child: BeeCategoryPicker(
                      items: const [
                        BeeCategoryChoice(
                            id: 'home-sample',
                            label: '家居样例',
                            icon: BeeLineIcon('House'),
                            enabled: false,
                            detail: '3笔',
                            children: [
                              BeeCategoryChoice(
                                  id: 'furniture-sample',
                                  label: '家具样例',
                                  icon: BeeLineIcon('Armchair'),
                                  detail: '3笔'),
                              BeeCategoryChoice(
                                  id: 'disabled-sample',
                                  label: '停用样例',
                                  icon: BeeLineIcon('Shapes'),
                                  enabled: false),
                            ])
                      ],
                      selected: null,
                      immediate: true,
                      searchLabel: '搜索即时选择样例',
                      emptyLabel: '没有匹配分类',
                      confirmLabel: '选择',
                      cancelLabel: '取消',
                      onConfirm: (value) => record('即时选择 $value'),
                      onCancel: () => record('取消即时选择'),
                    ))),
          ]),
        28 => BeeSurface(
            child: SizedBox(
                height: 360,
                child: BeeAccountPicker(
                    accounts: const [
                      BeeAccountChoice(
                          id: 'wechat',
                          name: '微信',
                          currency: 'CNY',
                          balance: '¥2,680.00'),
                      BeeAccountChoice(
                          id: 'bank',
                          name: '招商银行',
                          currency: 'CNY',
                          balance: '¥12,800.00'),
                      BeeAccountChoice(
                          id: 'usd',
                          name: '美元账户',
                          currency: 'USD',
                          balance: 'US\$300.00')
                    ],
                    currency: 'CNY',
                    selected: chosenAccount,
                    searchLabel: '搜索账户',
                    emptyLabel: '没有可选账户',
                    unsetLabel: '暂不设置账户',
                    onSelected: (v) => setState(() {
                          chosenAccount = v;
                          event = '已选择账户 ${v ?? '无'}';
                        })))),
        29 => TransactionRowStates(onEvent: record),
        30 => widget.liveData ??
            const BeeSurface(
                child: Text('从 App 内打开组件验收，可使用当前账本数据。',
                    style: TextStyle(fontSize: 13))),
        31 => BeeSurface(
            child: SizedBox(
                height: 350,
                child: BeeLedgerPicker(
                    ledgers: const [
                      BeeLedgerChoice(
                          id: '日常生活',
                          name: '日常生活',
                          currency: 'CNY',
                          detail: '个人账本'),
                      BeeLedgerChoice(
                          id: '家庭账本',
                          name: '家庭账本',
                          currency: 'CNY',
                          detail: '共享账本 · 2 位成员'),
                      BeeLedgerChoice(
                          id: '旅行账本',
                          name: '旅行账本',
                          currency: 'USD',
                          detail: '个人账本')
                    ],
                    currentId: ledger,
                    searchLabel: '搜索账本',
                    emptyLabel: '没有匹配账本',
                    currentLabel: '当前账本',
                    onSelected: (v) => setState(() {
                          ledger = v;
                          event = '切换账本 $v';
                        })))),
        32 => Column(children: [
            BeeCheckTile(
                label: '预览空分类状态',
                value: categoryEmpty,
                onChanged: (v) => setState(() => categoryEmpty = v)),
            SizedBox(
                height: 330,
                child: BeeCategoryManagementList(
                    items: categoryEmpty
                        ? const []
                        : [
                            for (final id in categoryOrder)
                              id == 'food'
                                  ? BeeManagedCategory(
                                      id: 'food',
                                      name: '餐饮',
                                      detail: '4 个二级分类 · 24 笔',
                                      icon: const BeeLineIcon('Utensils',
                                          size: 19),
                                      isDefault: true,
                                      children: demoCategoryChildren)
                                  : const BeeManagedCategory(
                                      id: 'travel',
                                      name: '交通',
                                      detail: '3 个二级分类 · 8 笔',
                                      icon:
                                          BeeLineIcon('TrainFront', size: 19)),
                          ],
                    empty: BeeStatus(
                        label: '暂无分类',
                        action: BeeButton(
                            label: '新建分类', onPressed: () => record('新建分类'))),
                    onEdit: (id) => record('编辑分类 $id'),
                    onManageChildren: demoManageChildren,
                    onReorder: (a, b) => setState(() {
                          if (a < b) b--;
                          final item = categoryOrder.removeAt(a);
                          categoryOrder.insert(b, item);
                          event = '分类排序 $a → $b';
                        }),
                    manageLabel: '管理',
                    footer: Column(children: [
                      BeeMenuRow(
                          title: '转账分类图标',
                          leading: const BeeLineIcon('ArrowLeftRight'),
                          onTap: () => record('编辑转账分类')),
                      BeeMenuRow(
                          title: '分类工具',
                          leading: const BeeLineIcon('Settings2'),
                          onTap: () => record('分类工具弹窗')),
                    ]))),
          ]),
        33 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BeeTransferAccountPair(
                fromLabel: '转出账户',
                toLabel: '转入账户',
                fromName: '人民币现金',
                toName: '招商银行',
                onFrom: () => record('选择转出账户'),
                onTo: () => record('选择转入账户')),
            const SizedBox(height: 12),
            const Text('历史隐藏账户'),
            const SizedBox(height: 8),
            BeeTransferAccountPair(
                fromLabel: '转出账户',
                toLabel: '转入账户',
                fromName: '人民币现金',
                toName: '旧银行卡',
                toDetail: '已隐藏',
                onFrom: () => record('选择转出账户'),
                onTo: () => record('保留历史隐藏账户')),
          ]),
        34 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BeeSearchSummary(
                title: '12 笔匹配账单',
                expenseLabel: '支出合计',
                expense: '¥1,268.50',
                incomeLabel: '收入合计',
                income: '¥0.00',
                actionLabel: '批量操作',
                onAction: () => record('进入批量操作')),
            const SizedBox(height: 12),
            BeeBatchSelection(
                label: selected ? '已选择 12 笔' : '已选择 0 笔',
                total: selected ? '¥1,268.50' : '¥0.00',
                actions: ['全选', '反选', '调整范围']
                    .map((label) => BeeChoiceChip(
                        compact: true,
                        label: label,
                        selected: false,
                        onSelected: (_) {
                          setState(() => selected = !selected);
                          record(label);
                        }))
                    .toList()),
            const SizedBox(height: 12),
            BeeBatchActionBar(actions: [
              for (final action in [
                ('设置备注', 'PencilLine'),
                ('调整分类', 'Shapes'),
                ('设置标签', 'Tag'),
                ('删除', 'Trash2')
              ])
                BeeBatchAction(
                    label: action.$1,
                    icon: BeeLineIcon(action.$2, size: 19),
                    danger: action.$2 == 'Trash2',
                    onPressed: selected ? () => record(action.$1) : null)
            ]),
          ]),
        35 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const BeeResourceHero(
                title: '餐饮',
                caption: '一级分类 · 4 个二级分类 · 日常生活',
                icon: BeeLineIcon('Utensils', size: 22),
                amountLabel: '本月支出',
                prefix: '¥',
                amount: '1,199.57',
                metrics: [
                  BeeResourceMetric(label: '记录笔数', value: '38笔'),
                  BeeResourceMetric(label: '单笔均额', value: '¥31.57'),
                  BeeResourceMetric(label: '占总支出', value: '36.5%')
                ]),
            const SizedBox(height: 12),
            BeeSurface(
                child: BeeResourceBreakdown(items: const [
              BeeResourceBreakdownItem(
                  id: 'lunch',
                  label: '午餐',
                  amount: '¥620.00',
                  detail: '20笔 · 51.7%',
                  fraction: .517,
                  icon: BeeLineIcon('Utensils', size: 18)),
              BeeResourceBreakdownItem(
                  id: 'coffee',
                  label: '咖啡',
                  amount: '¥160.00',
                  detail: '8笔 · 13.3%',
                  fraction: .133,
                  icon: BeeLineIcon('Coffee', size: 18))
            ], onSelected: (id) => record('打开二级分类 $id'))),
            const SizedBox(height: 12),
            const BeeSurface(
                child: BeeResourceTrend(
                    values: [0, 280, 400, 730, 920, 1199.57],
                    label: '累计支出趋势',
                    axisLabels: ['10.01', '10.10', '10.20'])),
            const SizedBox(height: 12),
            const BeeResourceHero(
                title: '日常信用卡',
                caption: '信用卡 · CNY · 尾号8862',
                icon: BeeLineIcon('CreditCard', size: 22),
                amountLabel: '当前欠款',
                prefix: '¥',
                amount: '3,200.00',
                metrics: [
                  BeeResourceMetric(label: '信用额度', value: '¥20,000.00'),
                  BeeResourceMetric(label: '可用额度', value: '¥16,800.00')
                ]),
            const SizedBox(height: 12),
            BeeCreditCardTerms(
                usage: .16,
                estimateHint: '可用额度为估算值，以银行账单为准',
                billingLabel: '账单日12日 · 还款日28日',
                paymentLabel: '距还款日还有4天',
                repayLabel: '记一笔还款',
                onRepay: () => record('保留信用卡目标，进入转账')),
            const SizedBox(height: 12),
            BeeCreditCardTerms(
                paymentLabel: '今天是还款日 · 未设置额度',
                repayLabel: '记一笔还款',
                onRepay: () => record('未设置额度也可还款')),
            const SizedBox(height: 12),
            const BeeResourceHero(
                title: '旅行',
                titleWidget: Align(
                    alignment: Alignment.centerLeft,
                    child: BeeTag(
                        tag: BeeTagData('travel', '旅行', Color(0xff219c9c)),
                        compact: true)),
                caption: '日常生活',
                icon: BeeLineIcon('Tag', color: Color(0xff219c9c)),
                amountLabel: '总支出',
                prefix: '¥',
                amount: '85.20',
                metrics: [
                  BeeResourceMetric(label: '总收入', value: '¥9.00'),
                  BeeResourceMetric(label: '关联分类', value: '3'),
                  BeeResourceMetric(label: '交易笔数', value: '4笔')
                ]),
            const SizedBox(height: 12),
            const BeeResourceHero(
                title: '净资产',
                caption: 'CNY · 12个月 · 高额单行适配',
                icon: BeeLineIcon('ChartNoAxesCombined'),
                amountLabel: '期末金额',
                amount: '¥125,000,370',
                fitMetricValues: true,
                metrics: [
                  BeeResourceMetric(label: '期初金额', value: '¥125,000,400'),
                  BeeResourceMetric(label: '期间变化', value: '¥-30'),
                  BeeResourceMetric(label: '变化比例', value: '-0.0%'),
                ]),
          ]),
        36 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BeeConfigurationOptions(
                items: const [
                  BeeConfigurationChoice(id: 'ledgers', label: '账本'),
                  BeeConfigurationChoice(id: 'accounts', label: '账户'),
                  BeeConfigurationChoice(id: 'categories', label: '分类'),
                  BeeConfigurationChoice(id: 'tags', label: '标签')
                ],
                selected: configScopes,
                onChanged: (v) => setState(() => configScopes = v)),
            const SizedBox(height: 12),
            const BeeConfigurationPreview(
                content:
                    'version: 1\nledgers:\n  items:\n    - name: 日常生活\n      currency: CNY',
                label: 'YAML 配置预览'),
          ]),
        37 => BeeSurface(
            child: BeeCategoryIconEditor(
                source: categoryIconSource,
                value: categoryIcon,
                presetLabel: '预设图标',
                customLabel: '自定义图标',
                commonLabel: '常用',
                imageHint: '保留图片原色与透明背景，选择后裁剪为正方形。',
                chooseImageLabel: '选择图片',
                preview: Image.asset('assets/logo2.png', fit: BoxFit.contain),
                commonItems: const [
                  BeeIconChoice(
                      value: 'food',
                      label: '餐饮',
                      icon: BeeLineIcon('Utensils')),
                  BeeIconChoice(
                      value: 'coffee', label: '咖啡', icon: BeeLineIcon('Coffee'))
                ],
                groups: const [
                  BeeCategoryIconGroup(id: 'travel', label: '出行', items: [
                    BeeIconChoice(
                        value: 'train',
                        label: '地铁',
                        icon: BeeLineIcon('TrainFront')),
                    BeeIconChoice(
                        value: 'plane', label: '飞机', icon: BeeLineIcon('Plane'))
                  ])
                ],
                onSourceChanged: (v) => setState(() => categoryIconSource = v),
                onChanged: (v) => setState(() {
                      categoryIcon = v;
                      record('选择分类图标 $v');
                    }),
                onChooseImage: () => record('图片选择由 App 调用系统相册并裁剪'))),
        38 => BeeSurface(
              child: BeeAccountTypePicker(
                  groups: [
                for (final group in ['daily', 'valuation'])
                  BeeAccountTypeGroup(
                      id: group,
                      label: group == 'daily' ? '日常账户' : '估值账户',
                      choices: accountTypeOrder
                          .where((type) =>
                              isValuationOnlyType(type) ==
                              (group == 'valuation'))
                          .map((type) => BeeIconChoice(
                              value: type,
                              label: const {
                                'cash': '现金',
                                'bank_card': '银行卡',
                                'credit_card': '信用卡',
                                'alipay': '支付宝',
                                'wechat': '微信',
                                'other': '其他',
                                'real_estate': '房产',
                                'vehicle': '车辆',
                                'investment': '投资',
                                'insurance': '保险',
                                'social_fund': '社保公积金',
                                'loan': '贷款',
                              }[type]!,
                              icon: AccountTypeIcon(type: type, size: 24)))
                          .toList())
              ],
                  group: accountTypeGroup,
                  value: accountType,
                  onGroupChanged: (value) =>
                      setState(() => accountTypeGroup = value),
                  onChanged: (value) => setState(() {
                        accountType = value;
                        record('选择账户类型 $value');
                      }))),
        39 => BeeSurface(
            child: BeeAccountBalanceAdjustment(
                currentLabel: '当前余额',
                currentAmount: '¥50.00',
                targetLabel: '调整后余额',
                targetAmount: '¥60.00',
                differenceLabel: '调整差额',
                differenceAmount: '+¥10.00',
                differenceColor: const Color(0xff25856d),
                options: const [
                  BeeBalanceAdjustmentOption(
                      createTransaction: false,
                      title: '只修改余额',
                      description: '调整期初余额，不新增收支记录。',
                      confirmLabel: '确认修改余额'),
                  BeeBalanceAdjustmentOption(
                      createTransaction: true,
                      title: '新增平账记录',
                      description: '在当前账本生成一笔平账收支记录。',
                      confirmLabel: '确认新增平账记录'),
                ],
                createTransaction: balanceAdjustmentRecord,
                onModeChanged: (v) =>
                    setState(() => balanceAdjustmentRecord = v),
                onConfirm: (v) => record(v ? '确认新增平账记录' : '确认仅修改余额'))),
        40 => Column(mainAxisSize: MainAxisSize.min, children: [
            BeeAssetSummary(
                title: '净资产（折 CNY）',
                balances: const [
                  BeeAssetAmount('¥30,890.00', approximate: true)
                ],
                assetsLabel: '总资产',
                assets: const ['¥32,750.82'],
                liabilitiesLabel: '总负债',
                liabilities: const ['¥1,860.82'],
                hidden: overviewHidden,
                privacyLabel: overviewHidden ? '显示资产金额' : '隐藏资产金额',
                onPrivacy: () =>
                    setState(() => overviewHidden = !overviewHidden),
                detailLabel: '查看折算明细',
                onDetails: () => record('查看折算明细')),
            const SizedBox(height: 12),
            BeeAssetChartSection<int>(
                title: overviewChart == 0 ? '净值趋势' : '资产构成',
                segments: const [BeeSegment(0, '净值趋势'), BeeSegment(1, '资产构成')],
                selected: overviewChart,
                onSelected: (v) => setState(() => overviewChart = v),
                detailLabel: '查看详情',
                onDetails: () => record('查看净值详情'),
                child: overviewChart == 0
                    ? const BeeTrendChart(
                        values: [12, 18, 16, 24, 29, 31], label: '最近六个月净资产')
                    : BeeDonutChart(items: [
                        BeeChartSlice(
                            label: '现金',
                            value: 30,
                            color: const Color(0xfffacb16),
                            valueLabel: overviewHidden ? '••••' : '¥3,000'),
                        BeeChartSlice(
                            label: '银行卡',
                            value: 70,
                            color: const Color(0xff26a69a),
                            valueLabel: overviewHidden ? '••••' : '¥7,000'),
                      ], centerLabel: overviewHidden ? '****' : '¥10,000')),
            const SizedBox(height: 12),
            BeeSurface(
                child: Column(children: [
              BeeAccountConversionRow(
                  code: 'USD',
                  currencyName: '美元',
                  original: '\$-12.50',
                  converted: '≈ ¥-88.75',
                  hidden: overviewHidden),
              BeeAccountConversionRow(
                  code: 'EUR',
                  currencyName: '欧元',
                  original: '€50.00',
                  missingLabel: '未折算',
                  hidden: overviewHidden),
            ])),
            const SizedBox(height: 12),
            BeeSurface(
                child: BeeAccountPreferences(
                    enabled: accountsEnabled,
                    enableLabel: '启用账户功能',
                    onEnabled: (v) => setState(() => accountsEnabled = v),
                    expenseLabel: '默认支出账户',
                    expenseAccount: '微信',
                    onExpenseAccount: () => record('选择默认支出账户'),
                    incomeLabel: '默认收入账户',
                    incomeAccount: '人民币现金',
                    onIncomeAccount: () => record('选择默认收入账户'),
                    rateLabel: '汇率管理',
                    onRates: () => record('管理汇率'))),
          ]),
        49 => BudgetSample(
            liveData: widget.budgetData, onEdit: () => record('选择预算编辑')),
        48 => ExchangeRateSample(liveData: widget.exchangeRateData),
        47 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('受控样例：空、单边选择、就绪与禁用'),
            for (final state in [0, 1, 2, 3]) ...[
              const SizedBox(height: 16),
              BeeCategoryMigrationPair(
                  fromLabel: '迁出分类',
                  toLabel: '迁入分类',
                  fromHint: '选择要迁出的分类',
                  toHint: state == 0 ? '请先选择迁出分类' : '选择迁入的分类',
                  fromName: state == 0 ? null : '饮品 / 自定义咖啡',
                  toName: state < 2 ? null : '餐饮 / 午餐',
                  fromIcon: state == 0
                      ? null
                      : Image.asset('assets/v4_gallery/category-coffee.png',
                          width: 24, height: 24, fit: BoxFit.contain),
                  toIcon: state < 2
                      ? null
                      : const BeeLineIcon('Utensils', size: 24),
                  onFrom: state == 3 ? null : () => record('选择迁出分类'),
                  onTo:
                      state == 0 || state == 3 ? null : () => record('选择迁入分类')),
            ],
            const SizedBox(height: 20),
            widget.categoryMigrationData ??
                const Text('从 App 内组件验收读取实际分类与迁移信息。'),
          ]),
        46 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('受控展示：预览、尺寸/大小与选中态'),
            SizedBox(
                height: 220,
                child: BeeAttachmentLibrary(
                    items: const [
                      BeeAttachment(
                          id: 'receipt',
                          image: AssetImage('assets/logo2.png'),
                          label: 'receipt.png',
                          info: '320 × 480 · 12.00 KB'),
                      BeeAttachment(
                          id: 'icon',
                          image: AssetImage('assets/logo2.png'),
                          label: 'custom-icon.png',
                          info: '216 × 216 · 4.50 KB')
                    ],
                    emptyLabel: '暂无附件',
                    selectedId: librarySelectedId,
                    onOpen: (i) => setState(() =>
                        librarySelectedId = i == 0 ? 'receipt' : 'icon'))),
            const Text('空态'),
            const SizedBox(
                height: 180,
                child: BeeAttachmentLibrary(
                    items: [], emptyLabel: '暂无附件', onOpen: null)),
            const Text('加载中'),
            const SizedBox(
                height: 120,
                child: BeeAttachmentLibrary(
                    items: [],
                    emptyLabel: '暂无附件',
                    onOpen: null,
                    loading: true,
                    loadingLabel: '正在读取图片')),
            const Text('图片加载失败'),
            SizedBox(
                height: 150,
                child: BeeAttachmentLibrary(
                    items: [
                      BeeAttachment(
                          id: 'bad',
                          image: const AssetImage('assets/logo2.png'),
                          label: 'bad-image.png',
                          info: '3 B')
                    ],
                    imageBuilder: (_) =>
                        const Center(child: BeeLineIcon('ImageOff', size: 28)),
                    emptyLabel: '暂无附件',
                    onOpen: (_) => record('图片加载失败示例'))),
            const Text('不可操作预览'),
            const SizedBox(
                height: 150,
                child: BeeAttachmentLibrary(items: [
                  BeeAttachment(
                      id: 'readonly',
                      image: AssetImage('assets/logo2.png'),
                      label: 'readonly.png',
                      info: '216 × 216 · 4.50 KB')
                ], emptyLabel: '暂无附件', onOpen: null)),
            const SizedBox(height: 16),
            widget.attachmentLibraryData ?? const Text('从App组件验收读取真实附件与图标。'),
          ]),
        45 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('受控示例：不读写文件、不运行导入'),
            for (final state in BeeFileTaskState.values)
              BeeSurface(
                  child: BeeFileTransferStatus(
                      title: switch (state) {
                        BeeFileTaskState.ready => '导出附件',
                        BeeFileTaskState.running => '正在导入',
                        BeeFileTaskState.success => '导入完成',
                        BeeFileTaskState.partial => '导入部分失败',
                        BeeFileTaskState.error => '导入失败'
                      },
                      state: state,
                      subtitle: '附件与自定义图标',
                      progress: state == BeeFileTaskState.running ? 0.4 : 1,
                      progressLabel: state == BeeFileTaskState.running
                          ? '已处理4/10'
                          : state == BeeFileTaskState.partial
                              ? '成功8 · 失败2'
                              : state == BeeFileTaskState.error
                                  ? '请检查归档后重试'
                                  : '准备就绪',
                      onTap: state == BeeFileTaskState.ready
                          ? () => record('演示导出附件')
                          : null,
                      onPreview: state == BeeFileTaskState.ready
                          ? () => record('演示附件预览')
                          : null,
                      previewLabel: '预览附件')),
            const SizedBox(height: 12),
            BeeArchiveSummary(
                fileName: 'beecount_attachments_20261025.tar.gz',
                details: const ['5张附件 · 2026-10-25 09:41', '自定义图标: 2个', '包含头像'],
                strategyLabel: '文件冲突时',
                skipLabel: '跳过已有文件',
                overwriteLabel: '覆盖已有文件',
                overwrite: overwriteArchive,
                onOverwrite: (v) => setState(() => overwriteArchive = v)),
            const SizedBox(height: 16),
            widget.fileWorkflowData ?? const Text('从App组件验收入口读取真实文件和后台任务。')
          ]),
        44 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('受控展示示例：只改变演示选中态，不写入真实皮肤'),
            const SizedBox(height: 12),
            LayoutBuilder(
                builder: (context, box) =>
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      for (final item in const [
                        BeeSkinChoice(
                            id: 'none',
                            name: '纯色',
                            preview: ColoredBox(color: Color(0xfff8c91c))),
                        BeeSkinChoice(
                            id: 'animated',
                            name: '动态皮肤与固定配色',
                            animated: true,
                            fixedPalette: true,
                            cornerBadge: '1st',
                            preview: ColoredBox(color: Color(0xffff7a45))),
                      ])
                        SizedBox(
                            width: (box.maxWidth - 10) / 2,
                            child: BeeSkinCard(
                                item: item,
                                selected: demoSkin == item.id,
                                animatedLabel: '动态',
                                fixedLabel: '固定配色',
                                onTap: () =>
                                    setState(() => demoSkin = item.id)))
                    ])),
            const SizedBox(height: 12),
            const Text('只读 / 处理中'),
            const BeeSkinCard(
                item: BeeSkinChoice(
                    id: 'readonly',
                    name: '只读皮肤预览',
                    animated: true,
                    fixedPalette: true,
                    preview: ColoredBox(color: Color(0xff7e57c2))),
                selected: true,
                animatedLabel: '动态',
                fixedLabel: '固定配色',
                onTap: null),
            const SizedBox(height: 16),
            widget.skinData ?? const Text('从App组件验收入口读取当前真实皮肤。'),
          ]),
        43 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('受控展示示例：不写入真实偏好'),
            const SizedBox(height: 12),
            BeeNoteHistoryPreferences(
                scopeLabel: '查询范围',
                scopeOptions: const ['全部分类', '当前分类'],
                selectedScope: historyScope,
                onScope: (v) => setState(() => historyScope = v),
                sortLabel: '排序方式',
                sortOptions: const ['使用频次', '最近使用'],
                selectedSort: historySort,
                onSort: (v) => setState(() => historySort = v),
                limitLabel: '展示数量',
                limitHint: '有效范围为1–100条',
                limit: historyLimit,
                limitError: historyInvalid ? '请输入1–100的整数' : null,
                onLimit: (v) => setState(() {
                      final n = int.tryParse(v);
                      historyInvalid = n == null || n < 1 || n > 100;
                      if (!historyInvalid) historyLimit = v;
                    })),
            const SizedBox(height: 16),
            widget.noteHistoryData ?? const Text('从App组件验收入口读取真实历史备注偏好。'),
          ]),
        42 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('受控展示示例：不调度系统通知'),
            const SizedBox(height: 12),
            BeeReminderPreferences(
                enabled: reminderEnabled,
                enabledLabel: '每日记账提醒',
                enabledDescription: '开启后将在指定时间提醒您记账',
                timeLabel: '提醒时间',
                time: reminderTime.format(context),
                onEnabled: (v) => setState(() {
                      reminderEnabled = v;
                      event = v ? '演示开启' : '演示关闭';
                    }),
                onTime: _reminderTime),
            const SizedBox(height: 12),
            const Text('处理中 / 只读状态'),
            const BeeReminderPreferences(
                enabled: true,
                enabledLabel: '每日记账提醒',
                enabledDescription: '等待宿主完成操作',
                timeLabel: '提醒时间',
                time: '21:00',
                onEnabled: null,
                onTime: null),
            const SizedBox(height: 12),
            widget.reminderData ?? const Text('从App组件验收入口读取真实提醒偏好并进入真实设置。'),
          ]),
        41 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
                height: 300,
                child: BeeTagLibrary(
                    items: const [
                      BeeTagLibraryItem(
                          tag: BeeTagData('work', '工作日', Color(0xffaa8b29)),
                          count: '31笔'),
                      BeeTagLibraryItem(
                          tag: BeeTagData('travel', '旅行', Color(0xff219c9c)),
                          count: '17笔'),
                      BeeTagLibraryItem(
                          tag:
                              BeeTagData('unused', '未使用的标签', Color(0xff826acb)),
                          count: '0笔')
                    ],
                    deleteLabel: '删除',
                    onOpen: (id) => record('查看标签 $id'),
                    onDelete: (id) => record('删除前确认 $id'))),
            const Text('上方为受控组件样例；实际写入从真实标签管理页面确认。',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            widget.tagLibraryData ?? const Text('从 App 的组件验收入口查看真实标签库。')
          ]),
        _ => const SizedBox.shrink(),
      };
  void _editRate() => showBeeDialog<void>(context,
      title: '补充本笔汇率',
      child: BeeValidatedInput(
          label: '1 USD = ? CNY',
          initial: rate,
          helper: '仅用于本笔账单，不修改历史汇率',
          confirmLabel: '确定',
          cancelLabel: '取消',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validate: (v) {
            final n = double.tryParse(v);
            return n == null || !n.isFinite || n <= 0 ? '请输入有效正数' : null;
          },
          onConfirm: (v) {
            setState(() => rate = v);
            Navigator.pop(context);
            record('汇率 $v');
          },
          onCancel: () => Navigator.pop(context)),
      actions: const []);
  void _editNickname() => showBeeDialog<void>(context,
      title: '编辑昵称',
      child: BeeValidatedInput(
          label: '昵称',
          initial: nickname,
          maxLength: 20,
          confirmLabel: '保存',
          cancelLabel: '取消',
          validate: (v) => v.isEmpty
              ? '昵称不能为空'
              : v.characters.length > 20
                  ? '最多 20 个字'
                  : null,
          onConfirm: (v) {
            setState(() => nickname = v);
            Navigator.pop(context);
            record('昵称已保存');
          },
          onCancel: () => Navigator.pop(context)),
      actions: const []);
}
