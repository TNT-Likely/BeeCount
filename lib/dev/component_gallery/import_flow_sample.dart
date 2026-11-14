import 'package:beecount_business_ui/transaction_import.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizations_resolver.dart';

/// Local, controlled gallery. It never opens the system picker or writes data.
class ImportFlowSample extends StatefulWidget {
  const ImportFlowSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<ImportFlowSample> createState() => _ImportFlowSampleState();
}

class _ImportFlowSampleState extends State<ImportFlowSample> {
  int source = 0, step = 0;
  int? mapped = 0, category;
  String? fileName;
  String event = '局部导入示例，不读取文件或写入账本';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeImportSteps(labels: [
        l.importChooseFile,
        l.importConfirmMapping,
        l.importCategoryMapping
      ], current: step),
      const SizedBox(height: 12),
      BeeImportSection(
          child: BeeImportSourcePicker<int>(
              label: l.importBillType,
              value: source,
              options: [
                BeeImportOption(0, l.importBillTypeGeneric),
                BeeImportOption(1, l.importBillTypeAlipay),
                BeeImportOption(2, l.importBillTypeWechat)
              ],
              onChanged: (value) => setState(() {
                    source = value;
                    event = '示例账单来源已更新';
                  }))),
      const SizedBox(height: 12),
      if (step == 0)
        BeeImportSection(
            child: BeeImportFileChoice(
                fileName: fileName ?? l.importNoFileSelected,
                chooseLabel: l.importChooseFile,
                description: 'CSV · TSV · TXT · XLSX',
                onChoose: () => setState(() {
                      fileName = 'example.csv';
                      step = 1;
                      event = '示例文件已选择';
                    }))),
      if (step == 1)
        BeeImportSection(
            title: l.importConfirmMapping,
            child: BeeImportMappingField<int>(
                label: l.importFieldDate,
                value: mapped,
                options: const [
                  BeeImportOption(0, '日期'),
                  BeeImportOption(1, '交易时间')
                ],
                onChanged: (value) => setState(() {
                      mapped = value;
                      event = '示例字段映射已更新';
                    }))),
      if (step == 2)
        BeeImportSection(
            title: l.importCategoryMapping,
            description: l.importCategoryMappingDescription,
            child: BeeImportMappingField<int?>(
                label: '餐饮 / 午餐',
                value: category,
                options: [
                  BeeImportOption(null, l.importKeepOriginalName),
                  const BeeImportOption(9, 'QA 餐饮')
                ],
                onChanged: (value) => setState(() {
                      category = value;
                      event = '示例分类映射已更新';
                    }))),
      const SizedBox(height: 12),
      BeeImportSection(
          title: l.importPreview,
          child: const BeeImportPreviewTable(rows: [
            ['日期', '类型', '金额', '分类', '币种', '标签', '附件'],
            ['2026-10-20', '支出', '32.00', '餐饮', 'CNY', '午餐', 'receipt.jpg'],
            ['2026-10-20', '转账', '200.00', '', 'CNY', '', ''],
          ])),
      if (step > 0) ...[
        const SizedBox(height: 12),
        BeeButton(
            label: step == 1 ? l.importNextStep : l.importPreviousStep,
            onPressed: () => setState(() => step = step == 1 ? 2 : 1))
      ],
      const SizedBox(height: 12),
      BeeImportSection(
          child: BeeImportStatusPanel(
              title: l.importInProgress,
              message: l.importProgressDetail(18, 1, 17, 26),
              progress: 18 / 26,
              actions: [
            BeeButton(
                label: l.importCancelImport,
                kind: BeeButtonKind.quiet,
                onPressed: () => setState(() => event = '示例取消进度展示；原服务可能继续写入'))
          ])),
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
