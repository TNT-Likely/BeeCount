import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

class ExecutionDepthSample extends StatefulWidget {
  const ExecutionDepthSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<ExecutionDepthSample> createState() => _ExecutionDepthSampleState();
}

class _ExecutionDepthSampleState extends State<ExecutionDepthSample> {
  int selected = 4;
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(
          child: BeeExecutionDepthPicker(
              selected: selected,
              options: [
                for (final o in [
                  (2, l.agentExecutionDepthQuick),
                  (4, l.agentExecutionDepthStandard),
                  (6, l.agentExecutionDepthDeep),
                  (8, l.agentExecutionDepthCustom)
                ])
                  BeeExecutionDepthOption(
                      turns: o.$1,
                      label: o.$2,
                      description: l.agentExecutionDepthSelected(o.$1))
              ],
              onChanged: (v) => setState(() => selected = v))),
      const SizedBox(height: 8),
      Text('示例选择 $selected 轮，不写真实执行配置'),
      const SizedBox(height: 16),
      widget.liveData ?? const Text('App读取原本地Store与当前账本；选择保存留在正式页面。')
    ]);
  }
}
