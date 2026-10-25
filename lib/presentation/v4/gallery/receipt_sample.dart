import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

class ReceiptSample extends StatefulWidget {
  const ReceiptSample({super.key});
  @override
  State<ReceiptSample> createState() => _ReceiptSampleState();
}

class _ReceiptSampleState extends State<ReceiptSample> {
  Set<String> selected = {'note', 'tags'};
  String event = '合成小票示例；在弹窗内调整公开字段';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      BeeButton(
          label: l.transactionReceiptTitle,
          onPressed: () async {
            await showDialog<void>(
                context: context,
                builder: (dialogContext) => StatefulBuilder(
                    builder: (context, update) => Dialog(
                        backgroundColor: BeeCardTheme.of(context).surface,
                        surfaceTintColor: Colors.transparent,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23)),
                        child: SizedBox(
                            width: 420,
                            height: MediaQuery.sizeOf(context).height * .82,
                            child: BeeReceiptComposer(
                              title: l.transactionReceiptTitle,
                              closeLabel: l.commonClose,
                              fieldsLabel: l.transactionReceiptFields,
                              saveLabel: l.sharePosterSave,
                              shareLabel: l.sharePosterShare,
                              preview: ColoredBox(
                                  color: const Color(0xfffffdf7),
                                  child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: DefaultTextStyle(
                                          style: const TextStyle(
                                              color: Color(0xff302d27),
                                              height: 1.7,
                                              fontSize: 12),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(l.sharePosterAppName,
                                                    textAlign:
                                                        TextAlign.center),
                                                const Divider(),
                                                const Text('−1,234.56',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontSize: 35)),
                                                const Text('USD',
                                                    textAlign:
                                                        TextAlign.center),
                                                const Divider(),
                                                const Text('2026.10.20 12:30'),
                                                if (selected.contains('note'))
                                                  const Text('QA 一顿简单的午餐'),
                                                if (selected.contains('tags'))
                                                  const Text('#QA 合成标签'),
                                                if (selected
                                                    .contains('account'))
                                                  const Text('QA 现金账户'),
                                                if (selected.contains('ledger'))
                                                  const Text('QA 日常账本'),
                                                const Divider(),
                                                Text(l.transactionReceiptFooter,
                                                    textAlign: TextAlign.center)
                                              ])))),
                              fields: [
                                BeeReceiptField(
                                    value: 'note', label: l.importFieldNote),
                                BeeReceiptField(
                                    value: 'tags',
                                    label: l.transactionReceiptTags),
                                BeeReceiptField(
                                    value: 'account',
                                    label: l.importFieldAccount),
                                BeeReceiptField(
                                    value: 'ledger',
                                    label: l.transactionReceiptLedger)
                              ],
                              selected: selected,
                              onChanged: (values) =>
                                  update(() => selected = values),
                              onClose: () => Navigator.pop(dialogContext),
                              onSave: () =>
                                  setState(() => event = '保存回调已触发；不调用相册'),
                              onShare: (_) =>
                                  setState(() => event = '分享回调已触发；不调用系统分享'),
                            )))));
            if (mounted) setState(() {});
          }),
    ]);
  }
}
