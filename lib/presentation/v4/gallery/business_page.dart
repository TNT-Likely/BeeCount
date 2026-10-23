import 'package:flutter/material.dart';
import 'gallery_catalog.dart';
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
  '转账账户对'
];
const demoTags = [
  BeeTagData('work', '工作日', Color(0xffaa8b29)),
  BeeTagData('daily', '日常', Color(0xff448f5c)),
  BeeTagData('travel', '旅行', Color(0xff219c9c)),
  BeeTagData('read', '阅读', Color(0xff4a92ca)),
  BeeTagData('shop', '网购', Color(0xff826acb))
];

class BusinessAcceptancePage extends StatefulWidget {
  const BusinessAcceptancePage({super.key, this.isolatedCase, this.liveData});
  final Widget? liveData;
  final int? isolatedCase;
  @override
  State<BusinessAcceptancePage> createState() => _BusinessAcceptancePageState();
}

class _BusinessAcceptancePageState extends State<BusinessAcceptancePage> {
  int step = 0;
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
  String pin = '';
  DateTime date = DateTime(2026, 10, 23, 12, 30);
  Set<String> tags = {'work'}, expanded = {};
  Map<String, String?> mapping = {
    'amount': '金额',
    'date': '交易时间',
    'category': '类别'
  };
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
  Future<void> _openLedgerMenu(BuildContext anchorContext) async {
    final box = anchorContext.findRenderObject()! as RenderBox;
    final id = await showBeeContextMenu<String>(context,
        anchor: box.localToGlobal(Offset(box.size.width, box.size.height)),
        items: actions
            .map((a) => BeeMenuAction(
                value: a.id, label: a.label, icon: a.icon, danger: a.danger))
            .toList());
    if (!mounted || id == null) return;
    if (id == 'delete' || id == 'local') {
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
                onChanged: (v) => setState(() => brand = v))
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
                budget: const BeeProgress(
                    value: .64, label: '本月预算', trailing: '剩余 ¥1,713.50')),
            SwitchListTile(
                title: const Text('隐藏金额与折算'),
                value: hidden,
                onChanged: (v) => setState(() => hidden = v))
          ]),
        2 => Column(children: [
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
        9 => Column(
            children: ['日常生活', '家庭账本']
                .map((s) => Padding(
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
                                onMenu: () => _openLedgerMenu(cardContext),
                                actions: [
                                  BeeButton(
                                      label: '预算管理',
                                      compact: true,
                                      icon: const BeeLineIcon('ChartPie',
                                          size: 14),
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
                                      onPressed: () => record('$s 管理'))
                                ]))))
                .toList()),
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
            child: BeeOnboardingStep(
                step: step,
                total: 5,
                title: const [
                  '欢迎使用蜜蜂记账',
                  '选择语言',
                  '设置基础货币',
                  '选择主题色',
                  '准备好开始记录'
                ][step],
                description: '简单记录每一天，选项稍后也可修改',
                illustration: Image.asset('assets/logo2.png', height: 70),
                options: Column(children: [
                  BeeMenuRow(
                      title: step == 1
                          ? '简体中文'
                          : step == 2
                              ? '人民币 CNY'
                              : '沿用默认设置',
                      selected: true,
                      onTap: () => record('选择初始化选项')),
                  BeeMenuRow(
                      title: step == 1
                          ? 'English'
                          : step == 2
                              ? '美元 USD'
                              : '查看更多选项',
                      onTap: () => record('选择其他选项'))
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
                    child: const Text('已有数据？恢复备份')))),
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
            BeeDonutChart(items: const [
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
            ], centerLabel: '本月支出', onSelected: (v) => record('统计分类 $v')),
            const SizedBox(height: 20),
            const BeeTrendChart(
                values: [12, 8, 24, 16, 30, 21, 34], label: '本月开支趋势')
          ])),
        20 => BeeSurface(
              child: Column(children: [
            BeeQuickAddTrigger(
                label: '记一笔',
                menuLabel: '快捷记账菜单',
                cancelLabel: '取消',
                actions: const [
                  BeeAction(
                      id: 'ai', label: 'AI 记账', icon: BeeLineIcon('Shapes')),
                  BeeAction(
                      id: 'voice',
                      label: '语音',
                      icon: BeeLineIcon('Smartphone')),
                  BeeAction(
                      id: 'image', label: '图片', icon: BeeLineIcon('ImagePlus'))
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
        26 => BeeSurface(
              child: Column(children: [
            const Text('安全输入 · 展示与认证逻辑分离'),
            const SizedBox(height: 16),
            BeePinPad(
                length: 6,
                filled: pin.length,
                deleteLabel: '退格',
                onDigit: (v) => setState(() => pin += v),
                onDelete: () => setState(() =>
                    pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1))),
            BeeButton(
                label: '重置输入',
                kind: BeeButtonKind.quiet,
                onPressed: () => setState(() => pin = ''))
          ])),
        27 => BeeSurface(
            child: SizedBox(
                height: 430,
                child: BeeCategoryPicker(
                    items: const [
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
        32 => SizedBox(
            height: 330,
            child: BeeCategoryManagementList(
                items: const [
                  BeeManagedCategory(
                      id: 'food',
                      name: '餐饮',
                      detail: '4 个二级分类',
                      icon: BeeLineIcon('Utensils', size: 19),
                      isDefault: true,
                      children: [
                        BeeManagedCategory(
                            id: 'breakfast',
                            name: '早餐',
                            detail: '',
                            icon: BeeLineIcon('Coffee', size: 16)),
                        BeeManagedCategory(
                            id: 'lunch',
                            name: '午餐',
                            detail: '',
                            icon: BeeLineIcon('Utensils', size: 16))
                      ]),
                  BeeManagedCategory(
                      id: 'travel',
                      name: '交通',
                      detail: '3 个二级分类',
                      icon: BeeLineIcon('TrainFront', size: 19))
                ],
                onEdit: (id) => record('编辑分类 $id'),
                onManageChildren: (id) => record('管理二级分类 $id'),
                onReorder: (a, b) => record('分类排序 $a → $b'),
                manageLabel: '管理',
                footer: TextButton(
                    onPressed: () => record('分类工具弹窗'),
                    child: const Text('分类工具')))),
        _ => BeeTransferAccountPair(
            fromLabel: '转出账户',
            toLabel: '转入账户',
            fromName: '人民币现金',
            toName: '招商银行',
            onFrom: () => record('选择转出账户'),
            onTo: () => record('选择转入账户')),
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
