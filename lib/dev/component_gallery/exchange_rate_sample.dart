import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../pages/currency/exchange_rates/bindings/exchange_rate_editor.dart';

class ExchangeRateSample extends StatefulWidget {
  const ExchangeRateSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<ExchangeRateSample> createState() => _ExchangeRateSampleState();
}

class _ExchangeRateSampleState extends State<ExchangeRateSample> {
  String rate = '7.10000000', message = '点击手动汇率编辑示例草稿，不写入真实数据';
  Future<void> edit() async {
    final result = await showDialog<ExchangeRateDraft>(
        context: context,
        builder: (_) => ExchangeRateEditor(
            quote: 'USD', base: 'CNY', hadManual: true, initialText: rate));
    if (!mounted || result == null) return;
    setState(() {
      rate = result.reset ? '7.08000' : result.rate;
      message = result.reset ? '已恢复示例自动汇率' : '示例手动值 $rate';
    });
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeSurface(
            padding: EdgeInsets.zero,
            child: Column(children: [
              BeeExchangeRateRow(
                  code: 'USD',
                  name: '美元',
                  value: '1 USD = $rate CNY',
                  source: '手动',
                  manual: true,
                  onTap: edit),
              const BeeExchangeRateRow(
                  code: 'JPY',
                  name: '日元',
                  value: '1 JPY = 0.0470000 CNY',
                  source: '自动 · 更新于2026-10-25'),
              const BeeExchangeRateRow(
                  code: 'EUR',
                  name: '欧元',
                  value: '1 EUR = 7.90000 CNY',
                  source: '自动 · 更新于2026-09-01',
                  stale: true),
              const BeeExchangeRateRow(
                  code: 'AED',
                  name: '阿联酋迪拉姆',
                  value: '—',
                  source: '未获取 · 点击设置'),
            ])),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        widget.liveData ?? const Text('从App组件验收入口读取真实汇率与主币种。')
      ]);
}
