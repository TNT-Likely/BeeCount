import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

class RecurringBillsSample extends StatefulWidget {
  const RecurringBillsSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<RecurringBillsSample> createState() => _RecurringBillsSampleState();
}

class _RecurringBillsSampleState extends State<RecurringBillsSample> {
  bool enabled = true, transfer = false, busy = false;
  String event = '局部示例，不生成账单或修改周期配置';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeRecurringUsageNotice(
          title: l.recurringTransactionUsageTitle,
          description: l.recurringTransactionUsageContent),
      const SizedBox(height: 12),
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      BeeRecurringBillCard(
          title: 'QA 自定义咖啡分类',
          ledger: 'QA 日常账本 · CNY',
          frequency: l.recurringTransactionMonthly,
          amount: const Text('USD -12.00',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          icon: Image.asset('assets/v4_gallery/category-coffee.png',
              width: 20, height: 20, fit: BoxFit.contain),
          note: 'QA 合成订阅，不创建真实账单',
          lastGenerated: '${l.v4RecurringLastGeneratedLabel} 10/20',
          enabled: enabled,
          busy: busy,
          toggleLabel: '启用示例咖啡周期账单',
          onOpen: () => setState(() => event = '示例编辑咖啡周期账单'),
          onToggle: (value) => setState(() {
                enabled = value;
                event = '示例咖啡已${value ? '启用' : '停用'}，不写真实配置';
              })),
      const SizedBox(height: 12),
      BeeRecurringBillCard(
          title: l.transferTitle,
          ledger: 'QA 日元账本 · JPY',
          frequency: l.recurringTransactionEveryNYears(2),
          amount: const Text('5,000.00',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          icon: const BeeLineIcon('ArrowLeftRight'),
          note: 'QA 同币种账户转账模板',
          enabled: transfer,
          toggleLabel: '启用示例转账周期账单',
          onOpen: () => setState(() => event = '示例编辑转账周期账单'),
          onToggle: (value) => setState(() {
                transfer = value;
                event = '示例转账已${value ? '启用' : '停用'}，不写真实配置';
              })),
      const SizedBox(height: 12),
      BeeButton(
          label: busy ? '恢复示例开关' : '查看忙碌状态',
          kind: BeeButtonKind.secondary,
          onPressed: () => setState(() => busy = !busy)),
      const SizedBox(height: 16),
      widget.liveData ?? const Text('App读取原跨账本周期模板；示例不启动生成服务。'),
    ]);
  }
}
