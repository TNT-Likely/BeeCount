import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/maintenance.dart';
import '../../utils/app_localizations_resolver.dart';

class MaintenanceSample extends StatefulWidget {
  const MaintenanceSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<MaintenanceSample> createState() => _SampleState();
}

class _SampleState extends State<MaintenanceSample> {
  final selected = <String>{'INFO', 'WARN'};
  String event = '受控维护示例，不清理实际日志、数据库或文件';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeMaintenanceLogFilters(
          levelLabel: l.logCenterFilterLevel,
          sourceLabel: l.logCenterFilterPlatform,
          levels: [
            for (final level in ['DEBUG', 'INFO', 'WARN', 'ERROR'])
              BeeMaintenanceFilterChoice(
                  label: level,
                  selected: selected.contains(level),
                  onSelected: (value) => setState(() {
                        if (value) {
                          selected.add(level);
                        } else {
                          selected.remove(level);
                        }
                      }))
          ],
          sources: [
            BeeMaintenanceFilterChoice(
                label: 'Flutter',
                selected: true,
                onSelected: (_) => setState(() => event = '示例来源筛选'))
          ]),
      const SizedBox(height: 12),
      BeeMaintenanceLogCard(
          level: 'INFO',
          source: 'Flutter',
          time: '09:41:00.000',
          tag: 'Owned sample',
          message: '示例诊断记录',
          tone: BeeTone.neutral,
          onDetails: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                      title: const Text('[Owned sample]'),
                      content: const Text('示例诊断记录'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l.commonOk))
                      ])),
          onCopy: () => setState(() => event = '示例复制回调')),
      const SizedBox(height: 12),
      BeeMaintenanceAction(
          title: l.storageAIModels,
          subtitle: '2 ${l.storageFiles}',
          value: '12.50 MB',
          icon: const BeeLineIcon('Brain', size: 22),
          onTap: () => setState(() => event = '示例清理入口；真实页面保留确认')),
      const SizedBox(height: 12),
      BeeMaintenanceWidgetCard(
          title: l.widgetGalleryGlanceTitle,
          subtitle: l.widgetGalleryGlanceDesc,
          sizeLabel: l.widgetSizeSmall,
          previewSize: const Size(155, 155),
          preview: ColoredBox(
              color: BeeCardTheme.of(context).soft,
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BeeLineIcon('ChartNoAxesCombined', size: 28),
                const SizedBox(height: 10),
                Text(l.widgetTodayExpense,
                    style: const TextStyle(fontSize: 11)),
                const Text('¥88.5',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))
              ])))),
      const SizedBox(height: 12),
      Text(event,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      if (widget.liveData != null) ...[
        const SizedBox(height: 12),
        widget.liveData!
      ],
    ]);
  }
}
