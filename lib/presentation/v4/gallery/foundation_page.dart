import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gallery_catalog.dart';
import 'package:beecount_ui/beecount_ui.dart';

const foundationCases = [
  '按钮',
  '切换与选择',
  '表单',
  '分组列表',
  '反馈与空态',
  '滚轮',
  '弹窗与弹层',
  '底部导航',
  '令牌与图标',
  '菜单与轻提示',
  '折叠与筛选',
  '单选与滑杆',
  '图标按钮与角标',
  '标签块与多选',
  '搜索选择',
  '输入与校验状态',
  '卡片、分隔与页头',
  '底部操作栏',
  '加载与进度状态',
  '折线图',
  '时间滚轮',
  'HSV配色与命名色板'
];

class FoundationAcceptancePage extends StatefulWidget {
  const FoundationAcceptancePage({super.key, this.isolatedCase});
  final int? isolatedCase;
  @override
  State<FoundationAcceptancePage> createState() =>
      _FoundationAcceptancePageState();
}

class _FoundationAcceptancePageState extends State<FoundationAcceptancePage> {
  int segment = 0, longSegment = 0, sort = 0, radio = 0, nav = 0, wheel = 10;
  String event = '等待操作';
  bool loading = false, toggle = true, checked = false;
  double slider = .6;
  HSVColor hsv = HSVColor.fromColor(Colors.blue);
  String filter = '本月';
  bool iconSelected = false, passwordHidden = true, demoMotion = false;
  bool statusDismissed = false, chartHidden = false;
  Set<int> choices = {0, 2};
  String pickerMode = 'data';
  int picked = 0;
  int colorChoice = 0;
  DateTime pickedDate = DateTime(2026, 10, 23, 12, 30);
  final form = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final readonlyController = TextEditingController(text: '可复制的只读内容');
  final fieldFocus = FocusNode();
  @override
  void dispose() {
    nameController.dispose();
    readonlyController.dispose();
    fieldFocus.dispose();
    super.dispose();
  }

  void record(String value) => setState(() => event = value);
  @override
  Widget build(BuildContext context) => GalleryCatalog(
      id: 'foundation',
      title: '基础组件',
      labels: foundationCases,
      event: event,
      isolatedCase: widget.isolatedCase,
      sampleBuilder: (index) => _sample(context, index));
  Widget _sample(BuildContext context, int index) => switch (index) {
        0 => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                BeeButton(
                    label: '保存',
                    icon: const BeeLineIcon('Check'),
                    onPressed: () => record('已点击保存')),
                const SizedBox(height: 8),
                BeeButton(
                    label: '次要操作',
                    kind: BeeButtonKind.secondary,
                    onPressed: () => record('次要操作')),
                const SizedBox(height: 8),
                BeeButton(
                    label: '文字操作',
                    kind: BeeButtonKind.quiet,
                    onPressed: () => record('文字操作')),
                const SizedBox(height: 8),
                BeeButton(
                    label: '紧凑操作',
                    compact: true,
                    kind: BeeButtonKind.secondary,
                    onPressed: () => record('紧凑操作')),
                const SizedBox(height: 8),
                BeeButton(label: '暂不可用', onPressed: null),
                const SizedBox(height: 8),
                BeeButton(
                    label: '删除账单',
                    kind: BeeButtonKind.danger,
                    onPressed: () => record('需二次确认')),
                const SizedBox(height: 8),
                BeeButton(
                    label: '保存中',
                    loading: loading,
                    onPressed: () => setState(() => loading = true)),
                TextButton(
                    onPressed: () => setState(() => loading = false),
                    child: const Text('结束处理中状态')),
              ])),
        1 => BeeSurface(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            BeeSegmented<int>(
                items: const [
                  BeeSegment(0, '支出'),
                  BeeSegment(1, '收入'),
                  BeeSegment(2, '转账')
                ],
                value: segment,
                onChanged: (v) => setState(() {
                      segment = v;
                      event = '切换至 ${['支出', '收入', '转账'][v]}';
                    })),
            const SizedBox(height: 12),
            const BeeSegmented<int>(items: [
              BeeSegment(0, '选中类型'),
              BeeSegment(1, '禁用类型', enabled: false)
            ], value: 0, onChanged: null),
            const SizedBox(height: 12),
            BeeSegmented<int>(
                items: const [
                  BeeSegment(0, '较长的选项名称'),
                  BeeSegment(1, '另一项完整名称'),
                  BeeSegment(2, '最后一个长选项')
                ],
                value: longSegment,
                onChanged: (v) => setState(() => longSegment = v)),
          ])),
        2 => BeeSurface(
              child: Column(children: [
            const BeeField(label: '账本名称', hint: '请输入名称', helper: '可随时修改'),
            const SizedBox(height: 16),
            const BeeField(
                label: '金额',
                error: '请输入大于 0 的金额',
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            const BeeField(label: '只读内容', hint: '日常生活', enabled: false),
            const SizedBox(height: 16),
            const BeeField(label: '备注', maxLines: 3, maxLength: 100),
            BeeSearchField(
                hint: '搜索账单',
                clearLabel: '清空搜索',
                onChanged: (v) => record('搜索 $v')),
            BeeToggleRow(
                title: '隐藏金额',
                leading: const BeeLineIcon('Eye'),
                value: toggle,
                onChanged: (v) => setState(() => toggle = v)),
            BeeCheckTile(
                label: '计入统计',
                value: checked,
                onChanged: (v) => setState(() => checked = v))
          ])),
        3 => BeeSurface(
            padding: EdgeInsets.zero,
            child: Column(children: [
              BeeMenuRow(
                  title: '个性化设置',
                  subtitle: '主题、显示和皮肤',
                  leading: const BeeLineIcon('Shapes'),
                  onTap: () => record('进入个性化'),
                  divider: true),
              BeeMenuRow(
                  title: '日常生活',
                  subtitle: '当前账本',
                  selected: true,
                  leading: const BeeLineIcon('BookOpen'),
                  onTap: () => record('选中账本')),
              BeeMenuRow(
                  title: '删除本地数据', danger: true, onTap: () => record('需要确认'))
            ])),
        4 => BeeSurface(
              child: Column(children: [
            const BeeStatus(label: '已保存', tone: BeeTone.success),
            const SizedBox(height: 16),
            const BeeStatus(
                label: '本地有更新', detail: '可以同步到云端', tone: BeeTone.warning),
            const SizedBox(height: 16),
            BeeStatus(
                label: '同步失败',
                detail: '网络暂时不可用',
                tone: BeeTone.error,
                action:
                    BeeButton(label: '重试', onPressed: () => record('重试已触发'))),
            const SizedBox(height: 16),
            if (!statusDismissed)
              BeeStatus(
                  label: '可关闭的提示',
                  action: TextButton(
                      onPressed: () => record('查看提示'), child: const Text('查看')),
                  onDismiss: () => setState(() {
                        statusDismissed = true;
                        event = '提示已关闭';
                      }))
            else
              TextButton(
                  onPressed: () => setState(() => statusDismissed = false),
                  child: const Text('恢复提示')),
            const SizedBox(height: 24),
            const BeeProgress(value: .64, label: '本月预算', trailing: '64%'),
            BeeEmptyState(
                title: '暂无账单',
                message: '记下第一笔开支',
                action:
                    BeeButton(label: '开始记账', onPressed: () => record('打开记账'))),
            const BeeEmptyState(title: '没有匹配结果', message: '试试其他关键词'),
            const BeeSkeleton(label: '正在加载列表', rows: 2)
          ])),
        5 => BeeSurface(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            BeeWheel<int>(
                values: List.generate(31, (i) => i + 1),
                value: wheel,
                label: (v) => '$v 日',
                onChanged: (v) => setState(() {
                      wheel = v;
                      event = '选择 $v 日';
                    })),
            const BeeDivider(label: '年 / 月 / 日'),
            BeeDateWheels(
                value: pickedDate,
                minYear: 2024,
                maxYear: 2030,
                onChanged: (v) => setState(() => pickedDate = v)),
          ])),
        6 => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                BeeButton(
                    label: '打开确认弹窗',
                    onPressed: () => showBeeDialog<void>(context,
                            title: '删除这笔账单？',
                            child: const Text('删除后无法恢复。'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消')),
                              BeeButton(
                                  label: '删除',
                                  kind: BeeButtonKind.danger,
                                  onPressed: () {
                                    Navigator.pop(context);
                                    record('确认删除');
                                  })
                            ])),
                const SizedBox(height: 12),
                BeeButton(
                    label: '打开底部弹层',
                    kind: BeeButtonKind.secondary,
                    onPressed: () => showBeeSheet<void>(context, title: '范围选择',
                            child: BeeActionExample(onTap: () {
                          Navigator.pop(context);
                          record('本月');
                        }))),
                const SizedBox(height: 12),
                BeeButton(
                    label: '打开编辑弹窗',
                    kind: BeeButtonKind.secondary,
                    onPressed: () => showBeeDialog<void>(context,
                        title: '编辑名称',
                        child: BeeValidatedInput(
                            label: '名称',
                            initial: '示例名称',
                            confirmLabel: '保存名称',
                            cancelLabel: '取消编辑',
                            validate: (v) => v.isEmpty ? '名称不能为空' : null,
                            onConfirm: (v) {
                              Navigator.pop(context);
                              record('编辑名称 $v');
                            },
                            onCancel: () => Navigator.pop(context)))),
              ])),
        7 => BeeBottomBar(
              items: const [
                BeeNavItem(label: '明细', icon: BeeLineIcon('ReceiptText')),
                BeeNavItem(label: '图表', icon: BeeLineIcon('Shapes')),
                BeeNavItem(label: '记账', icon: BeeLineIcon('Plus')),
                BeeNavItem(label: '资产', icon: BeeLineIcon('Wallet')),
                BeeNavItem(label: '我的', icon: BeeLineIcon('Baby'))
              ],
              index: nav,
              onChanged: (v) => setState(() {
                    nav = v;
                    event = '底栏 $v';
                  }),
              onRecordLongPress: () => record('长按记账：快捷操作')),
        21 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BeeColorPalette<int>(
                items: const [
                  BeeColorOption(value: 0, color: Colors.teal, label: '蓝绿'),
                  BeeColorOption(
                      value: 1, color: Colors.orange, label: '较长的主题颜色名称'),
                  BeeColorOption(value: 2, color: Colors.purple, label: '紫色')
                ],
                value: colorChoice,
                showLabels: true,
                onChanged: (v) => setState(() => colorChoice = v)),
            const SizedBox(height: 16),
            BeeHsvColorPicker(
                value: hsv,
                hueLabel: '色相 ${hsv.hue.round()}°',
                saturationLabel: '饱和度 ${(hsv.saturation * 100).round()}%',
                brightnessLabel: '亮度 ${(hsv.value * 100).round()}%',
                onChanged: (v) => setState(() => hsv = v)),
            const SizedBox(height: 12),
            const Text('禁用的HSV通道'),
            BeeHsvColorPicker(
                value: HSVColor.fromColor(Colors.blue),
                hueLabel: '色相 207°',
                saturationLabel: '饱和度 86%',
                brightnessLabel: '亮度 95%',
                onChanged: null),
            const SizedBox(height: 12),
            const Text('禁用的命名色板'),
            const BeeColorPalette<int>(items: [
              BeeColorOption(value: 0, color: Colors.teal, label: '蓝绿'),
              BeeColorOption(value: 1, color: Colors.orange, label: '橙色')
            ], value: 0, showLabels: true, onChanged: null),
          ]),
        8 => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const BeePageHeader(title: '组件令牌'),
                const BeeAvatar(
                    label: '示例头像', image: AssetImage('assets/logo2.png')),
                const SizedBox(height: 12),
                const Text('圆角 22 / 13 / 15 / 25；触控区 ≥ 44'),
                const SizedBox(height: 12),
                BeeColorPalette<int>(
                    items: const [
                      BeeColorOption(value: 0, color: Colors.teal, label: '蓝绿'),
                      BeeColorOption(
                          value: 1, color: Colors.orange, label: '橙色'),
                      BeeColorOption(
                          value: 2, color: Colors.purple, label: '紫色')
                    ],
                    value: colorChoice,
                    onChanged: (value) => setState(() {
                          colorChoice = value;
                          event = '选择颜色 $value';
                        })),
                const SizedBox(height: 12),
                Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      'Utensils',
                      'Coffee',
                      'TrainFront',
                      'ShoppingBasket',
                      'House',
                      'BookOpen',
                      'Tag',
                      'Wallet'
                    ].map((s) => BeeLineIcon(s, size: 24)).toList()),
                const SizedBox(height: 16),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BeeUiTokens.spaces
                        .map((s) => Container(
                            width: s,
                            height: s,
                            color: Theme.of(context).colorScheme.primary))
                        .toList()),
                BeeIconChoiceGrid<int>(
                    value: sort,
                    items: const [
                      BeeIconChoice(
                          value: 0, label: '现金', icon: BeeLineIcon('Wallet')),
                      BeeIconChoice(
                          value: 1,
                          label: '银行卡',
                          icon: BeeLineIcon('CreditCard')),
                      BeeIconChoice(
                          value: 2,
                          label: '禁用',
                          icon: BeeLineIcon('Lock'),
                          enabled: false),
                    ],
                    onChanged: (v) => setState(() => sort = v)),
                const SizedBox(height: 12),
                const Text('紧凑图标网格 · 保留语义标签'),
                BeeIconChoiceGrid<int>(
                    showLabels: false,
                    value: sort,
                    items: const [
                      BeeIconChoice(
                          value: 0, label: '现金', icon: BeeLineIcon('Wallet')),
                      BeeIconChoice(
                          value: 1,
                          label: '银行卡',
                          icon: BeeLineIcon('CreditCard'))
                    ],
                    onChanged: (v) => setState(() => sort = v)),
              ])),
        9 => BeeSurface(
              child: Column(children: [
            BeeMenuRow(
                title: '右下角操作菜单',
                subtitle: '支持禁用和危险操作',
                trailing: BeeMenuButton<String>(
                    label: '操作菜单',
                    items: const [
                      BeeMenuAction(
                          value: 'edit',
                          label: '编辑',
                          icon: BeeLineIcon('PencilLine')),
                      BeeMenuAction(
                          value: 'disabled', label: '暂无权限', enabled: false),
                      BeeMenuAction(
                          value: 'delete',
                          label: '删除',
                          danger: true,
                          icon: BeeLineIcon('Delete'))
                    ],
                    onSelected: (v) => record('菜单 $v'))),
            const SizedBox(height: 12),
            const Text('轻提示样式 · 基础组件 / 反馈', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
            const BeeToast(message: '保存成功', tone: BeeTone.success),
            const SizedBox(height: 8),
            const BeeToast(message: '网络不可用，请重试', tone: BeeTone.error),
            const SizedBox(height: 16),
            BeeButton(
                label: '显示成功提示',
                onPressed: () =>
                    showBeeToast(context, '保存成功', tone: BeeTone.success)),
            const SizedBox(height: 8),
            BeeButton(
                label: '显示失败提示',
                kind: BeeButtonKind.secondary,
                onPressed: () =>
                    showBeeToast(context, '网络不可用，请重试', tone: BeeTone.error))
          ])),
        10 => BeeSurface(
              child: Column(children: [
            BeeFilterBar(
                filters: const ['本月', '上月', '自定义时间', '仅收入', '仅支出'],
                selected: filter,
                onSelected: (v) => setState(() => filter = v)),
            const SizedBox(height: 12),
            const BeeAccordion(
                title: '更多选项',
                subtitle: '保持主要字段紧凑',
                child: BeeField(label: '备注关键词')),
            BeeSelectField<int>(
                label: '排序方式',
                items: const [BeeSegment(0, '按日期'), BeeSegment(1, '按金额')],
                value: sort,
                onChanged: (v) => setState(() => sort = v ?? 0))
          ])),
        11 => BeeSurface(
              child: Column(children: [
            BeeRadioTile<int>(
                label: '包含本地数据',
                subtitle: '单选状态由宿主持有',
                value: 0,
                groupValue: radio,
                onChanged: (v) => setState(() => radio = v)),
            BeeRadioTile<int>(
                label: '仅云端副本',
                value: 1,
                groupValue: radio,
                onChanged: (v) => setState(() => radio = v)),
            const BeeRadioTile<int>(
                label: '不可用选项', value: 2, groupValue: 0, onChanged: null),
            const BeeSliderField(
                label: '禁用滑杆', value: 0, valueLabel: '0%', onChanged: null),
            BeeSliderField(
                label: '预算提醒阈值',
                value: slider,
                valueLabel: '${(slider * 100).round()}%',
                divisions: 10,
                onChanged: (v) => setState(() => slider = v))
          ])),
        12 => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  BeeIconButton(
                      label: '新增项目',
                      icon: const BeeLineIcon('Plus'),
                      onPressed: () => record('新增项目')),
                  BeeIconButton(
                      label: '选中图标',
                      icon: const BeeLineIcon('Check'),
                      selected: iconSelected,
                      onPressed: () =>
                          setState(() => iconSelected = !iconSelected)),
                  const BeeIconButton(
                      label: '禁用图标',
                      icon: BeeLineIcon('PencilLine'),
                      onPressed: null),
                  BeeIconButton(
                      label: '危险图标',
                      icon: const BeeLineIcon('Delete'),
                      danger: true,
                      onPressed: () => record('危险操作需确认')),
                ]),
                const TickerMode(
                    enabled: false,
                    child: BeeIconButton(
                        label: '处理中图标',
                        icon: BeeLineIcon('Check'),
                        loading: true,
                        onPressed: null)),
                const BeeDivider(label: '角标 / 点击与长按提示'),
                Wrap(spacing: 16, runSpacing: 8, children: [
                  BeeBadge(
                      label: '有新功能',
                      child: BeeIconButton(
                          label: '新功能入口',
                          icon: const BeeLineIcon('Shapes'),
                          onPressed: () => record('新功能入口'))),
                  const BeeBadge(
                      label: '3 条消息',
                      count: 3,
                      child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(child: BeeLineIcon('Info')))),
                  const BeeBadge(
                      label: '超过 99 条',
                      count: 120,
                      child: SizedBox(
                          width: 48,
                          height: 44,
                          child: Center(child: BeeLineIcon('Info')))),
                  const BeeBadge(
                      label: '零条不显示',
                      count: 0,
                      child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(child: BeeLineIcon('Info')))),
                ]),
              ])),
        13 => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                        4,
                        (i) => BeeChoiceChip(
                            label: ['默认选项', '第二个选项', '带图标选项', '禁用选项'][i],
                            selected: choices.contains(i),
                            leading: i == 2
                                ? const BeeLineIcon('Shapes', size: 16)
                                : null,
                            onSelected: i == 3
                                ? null
                                : (v) => setState(() => choices = v
                                    ? {...choices, i}
                                    : ({...choices}..remove(i)))))),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  BeeChoiceChip(
                      label: '紧凑筛选',
                      selected: false,
                      compact: true,
                      trailing: const BeeLineIcon('X', size: 12),
                      onSelected: (_) => record('紧凑筛选')),
                ]),
                BeeCheckTile(
                    label: '全选可用项',
                    subtitle: '部分选中时显示半选状态',
                    value: choices.containsAll({0, 1, 2}),
                    mixed:
                        choices.isNotEmpty && !choices.containsAll({0, 1, 2}),
                    onChanged: (v) =>
                        setState(() => choices = v ? {0, 1, 2} : {})),
                const BeeCheckTile(label: '禁用复选', value: true, onChanged: null),
                const BeeToggleRow(
                    title: '禁用开关', value: false, onChanged: null),
              ])),
        14 => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                BeeSegmented<String>(
                    items: const [
                      BeeSegment('data', '列表'),
                      BeeSegment('loading', '加载'),
                      BeeSegment('error', '失败'),
                      BeeSegment('empty', '空态')
                    ],
                    value: pickerMode,
                    onChanged: (v) => setState(() => pickerMode = v)),
                const SizedBox(height: 12),
                BeeButton(
                    label: '打开搜索选择',
                    onPressed: () async {
                      final result = await showBeeSheet<int>(context,
                          title: '选择一个选项',
                          child: SizedBox(
                              height: 340,
                              child: BeeChoicePicker<int>(
                                  items: pickerMode == 'empty'
                                      ? const []
                                      : List.generate(
                                          30,
                                          (i) => BeeChoice(
                                              value: i,
                                              title:
                                                  '选项 ${i.toString().padLeft(2, '0')}',
                                              subtitle: i == 0
                                                  ? '当前选中，支持搜索与长列表'
                                                  : null)),
                                  selected: picked,
                                  searchLabel: '搜索选项',
                                  emptyLabel: '没有匹配选项',
                                  loading: pickerMode == 'loading',
                                  error: pickerMode == 'error'
                                      ? '加载失败，请返回后重试'
                                      : null,
                                  onSelected: (v) => Navigator.pop(context, v),
                                  onRetry: () {
                                    Navigator.pop(context);
                                    setState(() => pickerMode = 'data');
                                  },
                                  retryLabel: '返回重试')));
                      if (result != null && mounted) {
                        setState(() {
                          picked = result;
                          event = '选择选项 $result';
                        });
                      }
                    }),
                const SizedBox(height: 8),
                Text('当前：选项 ${picked.toString().padLeft(2, '0')}；关闭不改变选择',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                const BeeSelectField<int>(
                    label: '禁用下拉',
                    items: [BeeSegment(0, '只读选择')],
                    value: 0,
                    onChanged: null),
              ])),
        15 => BeeSurface(
            child: Form(
                key: form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BeeField(
                          label: '必填名称',
                          hint: '输入后点击校验',
                          controller: nameController,
                          focusNode: fieldFocus,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '名称不能为空' : null,
                          autovalidateMode: AutovalidateMode.onUserInteraction),
                      const SizedBox(height: 16),
                      BeeField(
                          label: '密码输入',
                          obscure: passwordHidden,
                          suffixIcon: BeeIconButton(
                              label: passwordHidden ? '显示密码' : '隐藏密码',
                              icon: BeeLineIcon(
                                  passwordHidden ? 'Eye' : 'EyeOff'),
                              onPressed: () => setState(
                                  () => passwordHidden = !passwordHidden))),
                      const SizedBox(height: 16),
                      BeeField(
                          label: '只读可复制',
                          controller: readonlyController,
                          readOnly: true),
                      const SizedBox(height: 16),
                      BeeField(
                          label: '数字过滤',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          prefixIcon: const BeeLineIcon('Hash')),
                      const SizedBox(height: 16),
                      const BeeField(
                          label: '多行与计数',
                          maxLines: 2,
                          maxLength: 20,
                          helper: '达到上限后不再接受新字符'),
                      const SizedBox(height: 16),
                      const BeeField(
                          label: '小数与输入法',
                          helper: '支持0.149与中文/全角小数点；组合输入提交后规范化。',
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [BeeDecimalInputFormatter()]),
                      const SizedBox(height: 12),
                      const BeeField(
                          label: '预算两位小数',
                          helper: '沿用预算两位输入规则，组合态提交后再限制；历史原值初始化不截断。',
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            BeeDecimalInputFormatter(maxFractionDigits: 2)
                          ]),
                      const SizedBox(height: 12),
                      BeeButton(
                          label: '校验并保存',
                          onPressed: () {
                            if (form.currentState!.validate()) {
                              form.currentState!.save();
                              record('校验通过：${nameController.text.trim()}');
                            }
                          }),
                      const SizedBox(height: 8),
                      BeeButton(
                          label: '聚焦必填名称',
                          kind: BeeButtonKind.quiet,
                          onPressed: () => fieldFocus.requestFocus()),
                    ]))),
        16 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BeePageHeader(title: '一级页面标题', actions: [
              BeeIconButton(
                  label: '标题操作',
                  icon: const BeeLineIcon('SlidersHorizontal'),
                  onPressed: () => record('标题操作'))
            ]),
            BeePageHeader(
                title: '二级页面长标题自动省略',
                compact: true,
                onBack: () => record('返回入口')),
            BeeSection(
                title: '分组标题',
                action: TextButton(
                    onPressed: () => record('查看全部'), child: const Text('查看全部')),
                child: const BeeSurface(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text('标准内容卡片', style: TextStyle(fontSize: 14)),
                      BeeDivider(),
                      Text('普通分隔线 / 内缩分隔线', style: TextStyle(fontSize: 12)),
                      BeeDivider(inset: 12),
                      Text('展示内容保持同一套留白', style: TextStyle(fontSize: 12)),
                    ]))),
            const SizedBox(height: 12),
            const SizedBox(
                height: 150,
                child: BeePageBody(children: [
                  BeeSurface(child: Text('页面分组一')),
                  BeeSurface(child: Text('页面分组二')),
                ])),
            const SizedBox(height: 12),
            const BeeSurface(
                child: Row(children: [
              BeeAvatar(label: '图片头像', image: AssetImage('assets/logo2.png')),
              SizedBox(width: 12),
              BeeAvatar(label: '默认头像')
            ])),
          ]),
        17 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('真实页面放在 Scaffold.bottomNavigationBar，键盘与安全区由宿主管理。',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            BeeActionBar(
                primaryLabel: '确认操作',
                onPrimary: () => record('主操作'),
                secondaryLabel: '取消操作',
                onSecondary: () => record('次操作'),
                safeArea: false),
            const SizedBox(height: 12),
            const BeeActionBar(
                primaryLabel: '禁用操作', onPrimary: null, safeArea: false),
          ]),
        20 => BeeSurface(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('24小时制 · 小时00–23 / 分钟00–59'),
            BeeTimeWheels(
                value: TimeOfDay.fromDateTime(pickedDate),
                onChanged: (v) => setState(() => pickedDate = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    v.hour,
                    v.minute))),
            const Text('宿主管理草稿；确认才保存，取消保持原值。'),
          ])),
        19 => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                BeeButton(
                    label: chartHidden ? '显示图中金额' : '隐藏图中金额',
                    kind: BeeButtonKind.secondary,
                    onPressed: () =>
                        setState(() => chartHidden = !chartHidden)),
                const SizedBox(height: 12),
                SizedBox(
                    height: 180,
                    child: BeeLineChart(
                        values: const [100, 0, -50, 120],
                        secondaryValues: const [20, 40, 0, 80],
                        secondaryColor: Colors.blue,
                        xLabels: const ['1月', '2月', '3月', '4月'],
                        highlightIndex: 3,
                        onSwipeLeft: () => record('下一周期'),
                        onSwipeRight: () => record('上一周期'),
                        onPrimaryLineTap: () => record('主线'),
                        onSecondaryLineTap: () => record('副线'),
                        hideAmounts: chartHidden,
                        whiteBg: false,
                        themeColor: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 12),
                const Text('负值 / 单点 / 空数据 / 内嵌图不拦截外层点击'),
                SizedBox(
                    height: 120,
                    child: BeeLineChart(
                        values: const [-40, -20, -60, -10],
                        xLabels: const ['1', '2', '3', '4'],
                        highlightIndex: 3,
                        onSwipeLeft: () {},
                        onSwipeRight: () {},
                        themeColor: Theme.of(context).colorScheme.primary,
                        minimal: true,
                        interactive: false,
                        hideAmounts: chartHidden)),
                SizedBox(
                    height: 100,
                    child: BeeLineChart(
                        values: const [30],
                        xLabels: const ['单点'],
                        highlightIndex: 0,
                        onSwipeLeft: () {},
                        onSwipeRight: () {},
                        themeColor: Theme.of(context).colorScheme.primary,
                        hideAmounts: chartHidden)),
                SizedBox(
                    height: 60,
                    child: BeeLineChart(
                        values: const [],
                        xLabels: const [],
                        highlightIndex: null,
                        onSwipeLeft: () {},
                        onSwipeRight: () {},
                        themeColor: Theme.of(context).colorScheme.primary)),
              ])),
        _ => BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                BeeButton(
                    label: demoMotion ? '暂停加载动效' : '演示加载动效',
                    kind: BeeButtonKind.secondary,
                    onPressed: () => setState(() => demoMotion = !demoMotion)),
                const SizedBox(height: 16),
                TickerMode(
                    enabled: demoMotion,
                    child:
                        const Column(mainAxisSize: MainAxisSize.min, children: [
                      BeeStatus(
                          label: '处理中',
                          detail: '进度未知，不显示虚假百分比',
                          tone: BeeTone.busy),
                      SizedBox(height: 16),
                      BeeProgress(value: null, label: '不确定进度'),
                    ])),
                const SizedBox(height: 16),
                const BeeProgress(value: 0, label: '尚未开始', trailing: '0%'),
                const SizedBox(height: 16),
                const BeeProgress(value: 1, label: '已完成', trailing: '100%'),
                const SizedBox(height: 16),
                const BeeStatus(label: '说明信息', tone: BeeTone.neutral),
                const SizedBox(height: 16),
                const BeeSkeleton(label: '内容加载占位', rows: 2),
                const SizedBox(height: 8),
                const Text('加载、失败和空结果互斥；已有内容刷新时由宿主保留。',
                    style: TextStyle(fontSize: 11)),
              ])),
      };
}

class BeeActionExample extends StatelessWidget {
  const BeeActionExample({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      BeeMenuRow(title: '本月', selected: true, onTap: onTap);
}
