import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/ui/ui.dart';
import '../../../utils/xlsx_reader.dart';
import '../../../services/import/file_reader.dart';
import '../../../pages/data/import_confirm_page.dart';
import 'import_source.dart';
import 'page_scaffold.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/transaction_import.dart';

class ImportControls extends ConsumerStatefulWidget {
  const ImportControls({super.key});

  @override
  ConsumerState<ImportControls> createState() => _ImportControlsState();
}

class _ImportControlsState extends ConsumerState<ImportControls> {
  final _controller = TextEditingController();
  final bool _hasHeader = true;
  PlatformFile? _picked;
  bool _reading = false;
  double? _readProgress; // 0~1
  bool _cancelRead = false;
  BillSourceType _billType = BillSourceType.generic; // 默认通用CSV

  @override
  void initState() {
    super.initState();
    // 访问一次平台通道，促使插件在部分场景下完成注册（修复热重载后 MissingPluginException 的偶现）
    // ignore: unawaited_futures
    FilePicker.platform.clearTemporaryFiles();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.importTitle, leading: const BackButton()),
      Expanded(
          child: Stack(children: [
        BeePageBody(children: [
          BeeImportSteps(labels: [
            l.importChooseFile,
            l.importConfirmMapping,
            l.importCategoryMapping
          ], current: 0),
          BeeImportSection(
              description: l.importSelectCsvFile,
              child: BeeImportSourcePicker<BillSourceType>(
                  label: l.importBillType,
                  value: _billType,
                  options: [
                    BeeImportOption(
                        BillSourceType.generic, l.importBillTypeGeneric),
                    BeeImportOption(
                        BillSourceType.alipay, l.importBillTypeAlipay),
                    BeeImportOption(
                        BillSourceType.wechat, l.importBillTypeWechat),
                  ],
                  onChanged: _reading
                      ? null
                      : (value) => setState(() => _billType = value))),
          BeeImportSection(
              child: BeeImportFileChoice(
                  fileName: _picked?.name ?? l.importNoFileSelected,
                  chooseLabel: l.importChooseFile,
                  description: 'CSV · TSV · TXT · XLSX',
                  onChoose: _reading ? null : _pickFile)),
          if (_picked == null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(l.importHint,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Theme.of(context).hintColor))),
        ]),
        if (_reading)
          Positioned.fill(
              child: ColoredBox(
                  color: Colors.black.withValues(alpha: .4),
                  child: Center(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: BeeSurface(
                                  child: BeeImportStatusPanel(
                                      title: l.importReading,
                                      message: _readProgress == null
                                          ? l.importPreparing
                                          : '${((_readProgress ?? 0) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                      progress: _readProgress,
                                      actions: [
                                    BeeButton(
                                        label: l.commonCancel,
                                        kind: BeeButtonKind.quiet,
                                        onPressed: () =>
                                            setState(() => _cancelRead = true))
                                  ]))))))),
      ])),
    ]));
  }

  Future<void> _onImport() async {
    String csvText = _controller.text.trim();
    if (_picked != null) {
      csvText = await _readFileStreaming(_picked!);
      if (!mounted) return;
    }
    if (csvText.isEmpty) return; // 可能读取被取消
    if (!mounted) return;
    // 跳转到确认映射页，批量导入在新页面执行
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportConfirmPage(
          csvText: csvText,
          hasHeader: _hasHeader,
          billType: _billType,
        ),
      ),
    );
    if (!mounted) return;
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt', 'xlsx'],
        allowMultiple: false,
        withData: true, // iOS 模拟器/沙盒下读取 bytes
      );
      if (!context.mounted) return;
      if (res != null && res.files.isNotEmpty) {
        setState(() => _picked = res.files.first);
        // 选中即进入确认页
        await _onImport();
        if (!context.mounted) return;
      }
    } on Exception catch (e) {
      if (!mounted) return;
      showToast(context,
          AppLocalizations.of(context).importFileOpenError(e.toString()));
    }
  }

  // 流式读取文件并显示进度（State 内部方法，可使用 setState）
  Future<String> _readFileStreaming(PlatformFile picked) async {
    if (!mounted) return '';

    setState(() {
      _reading = true;
      _readProgress = 0;
      _cancelRead = false;
    });

    try {
      final text = await FileReaderService.readFile(
        picked,
        onProgress: (progress) {
          if (_cancelRead) return;
          if (mounted) {
            setState(() {
              _readProgress = progress;
            });
          }
        },
        xlsxConverter: (bytes) {
          try {
            return XlsxReader.convertXlsxToCSV(bytes);
          } catch (e) {
            if (mounted) {
              showToast(
                context,
                AppLocalizations.of(context).importFileOpenError(e.toString()),
              );
            }
            return '';
          }
        },
      );

      if (mounted) {
        setState(() {
          _reading = false;
          _readProgress = null;
        });
      }

      return text;
    } catch (e) {
      if (mounted) {
        setState(() {
          _reading = false;
          _readProgress = null;
        });
        showToast(
          context,
          AppLocalizations.of(context).importFileOpenError(e.toString()),
        );
      }
      return '';
    }
  }
}

// 预览组件已移除
