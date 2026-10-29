import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_ui/card_frame.dart';
import 'package:beecount_ui/paper.dart';
import 'package:beecount_ui/status_pill.dart';
import 'package:flutter/material.dart';

class RefreshTabsAndChartSample extends StatefulWidget {
  const RefreshTabsAndChartSample({super.key});
  @override
  State<RefreshTabsAndChartSample> createState() => _RefreshTabsAndChartState();
}

class _RefreshTabsAndChartState extends State<RefreshTabsAndChartSample> {
  int tab = 0;
  int? selected;
  String feedback = '点选柱形或平均线';
  DateTime date = DateTime(2026, 10);
  Future<void> chooseDate() async {
    var draft = date;
    final chosen = await showBeeSheet<DateTime>(context,
        title: '时间范围',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BeeYearMonthWheel(value: date, onChanged: (value) => draft = value),
          BeeButton(
              label: '确认', onPressed: () => Navigator.pop(context, draft)),
        ]));
    if (mounted && chosen != null) {
      setState(() {
        date = chosen;
        feedback = '选择日期 ${date.year}-${date.month}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeCompactTabs(
            items: const [
              BeeSegment(0, '月'),
              BeeSegment(1, '年'),
              BeeSegment(2, '全部')
            ],
            value: tab,
            trackHeight: 32,
            tapHeight: 44,
            onChanged: (v) => setState(() => tab = v)),
        BeeDateRangeBar(
            label: '${date.year} 年 ${date.month} 月', onChoose: chooseDate),
        BeeUnderlineTabs(items: const [
          BeeSegment(0, '支出'),
          BeeSegment(1, '收入'),
          BeeSegment(2, '结余')
        ], value: tab, onChanged: (v) => setState(() => tab = v)),
        const SizedBox(height: 12),
        BeeColumnChart(
            values: const [32, -12, 64, 0],
            labels: const ['10.01', '10.02', '10.03', '10.04'],
            valueLabels: const ['32', '−12', '64', '0'],
            average: 21,
            averageLabel: '平均 21',
            selected: selected,
            onSelected: (v) => setState(() {
                  selected = v;
                  feedback = '选中第 ${v + 1} 根柱';
                }),
            onAverage: () => setState(() => feedback = '平均线：21')),
        Text(feedback,
            key: const ValueKey('refresh-chart-event'),
            style: const TextStyle(fontSize: 11)),
      ]));
}

class PaperComponentsSample extends StatelessWidget {
  const PaperComponentsSample({super.key});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BeeCardFrame(child: Text('BeeCardFrame · 描边卡片')),
        const SizedBox(height: 12),
        const BeePaper(
            radius: 16,
            padding: EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('BeePaper · 导出纸面', style: TextStyle(fontSize: 17)),
                  SizedBox(height: 12),
                  BeePaperRule(),
                  SizedBox(height: 12),
                  Text('纸面始终保持浅色；业务提供文字与数据。', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 12),
                  BeePaperRule(dashed: true)
                ])),
        const SizedBox(height: 12),
        const BeePaper(
            tearEdge: true,
            padding: EdgeInsets.all(18),
            child: Text('撕边纸面', style: TextStyle(fontSize: 15))),
        const SizedBox(height: 12),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          BeeStatusPill(label: '已同步', tone: BeeTone.success),
          BeeStatusPill(label: '有差异', tone: BeeTone.warning),
          BeeStatusPill(label: '连接失败', tone: BeeTone.error),
          BeeStatusPill(label: '等待处理'),
          TickerMode(
              enabled: false, child: BeeStatusPill(label: '检查中', busy: true))
        ]),
      ]);
}

class StartupPrimitivesSample extends StatefulWidget {
  const StartupPrimitivesSample({super.key});
  @override
  State<StartupPrimitivesSample> createState() => _StartupPrimitivesState();
}

class _StartupPrimitivesState extends State<StartupPrimitivesSample> {
  bool sheet = false, still = true;
  int replay = 0;
  @override
  Widget build(BuildContext context) {
    final query = MediaQuery.of(context),
        reduced = query.disableAnimations || !TickerMode.of(context) || still;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        BeeButton(
            label: '重播描线',
            kind: BeeButtonKind.secondary,
            onPressed: () => setState(() {
                  still = false;
                  replay++;
                })),
        BeeButton(
            label: '静态背景',
            kind: BeeButtonKind.secondary,
            onPressed: () => setState(() => still = true)),
      ]),
      const SizedBox(height: 12),
      SizedBox(
          height: 240,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ColoredBox(
                  color: BeeCardTheme.of(context).canvas,
                  child: Stack(children: [
                    Positioned.fill(
                        child: MediaQuery(
                            data: query.copyWith(disableAnimations: reduced),
                            child: BeeTrailBackdrop(
                                key: ValueKey(replay),
                                focalPoint: const Offset(160, 100)))),
                    Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('一笔成形',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 18),
                      MediaQuery(
                          data: query.copyWith(disableAnimations: reduced),
                          child: const BeeActivityIndicator()),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: () => setState(() => sheet = true),
                          child: const Text('打开局部弹层'))
                    ])),
                    if (sheet)
                      Positioned.fill(
                          child: BeeLocalSheet(
                              title: '页面所属弹层',
                              onClose: () => setState(() => sheet = false),
                              child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('关闭、遮罩、Escape 和系统返回均回到这个示例。'))))
                  ])))),
      const SizedBox(height: 8),
      const Text('减少动态效果时保留完整描线；演示不执行初始化或导航。', style: TextStyle(fontSize: 11)),
      const SizedBox(height: 12),
      BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('逐字文本', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TypewriterText(
            key: ValueKey('typewriter-$replay-$reduced'),
            text: '一笔一笔，记录生活。',
            animate: !reduced,
            speed: const Duration(milliseconds: 90)),
        const SizedBox(height: 6),
        const TypewriterText(text: '关闭动效时完整显示文本。', animate: false),
      ])),
    ]);
  }
}

class SystemBarsSample extends StatefulWidget {
  const SystemBarsSample({super.key});
  @override
  State<SystemBarsSample> createState() => _SystemBarsSampleState();
}

class _SystemBarsSampleState extends State<SystemBarsSample> {
  bool dark = false;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
            title: const Text('局部示例深色'),
            value: dark,
            onChanged: (v) => setState(() => dark = v)),
        Theme(
            data:
                beeTheme(brightness: dark ? Brightness.dark : Brightness.light),
            child: Builder(
                builder: (ctx) => BeeSystemBars(
                    child: Container(
                        height: 100,
                        padding: const EdgeInsets.all(18),
                        color: BeeCardTheme.of(ctx).canvas,
                        child: Text(dark ? '深色背景 · 浅色状态栏图标' : '浅色背景 · 深色状态栏图标',
                            style: TextStyle(
                                color:
                                    Theme.of(ctx).colorScheme.onSurface)))))),
        const Text('局部示例不覆盖整页；真实默认样式由 App 根部提供，旧页头可继续覆写。',
            style: TextStyle(fontSize: 11))
      ]);
}
