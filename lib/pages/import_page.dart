import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/primary_header.dart';
import 'import_confirm_page.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _controller = TextEditingController();
  bool _hasHeader = true;
  PlatformFile? _picked;
  // 手动字段映射：key -> 列索引
  final Map<String, int?> _mapping = {
    'date': null,
    'type': null,
    'amount': null,
    'category': null,
    'note': null,
  };

  @override
  void initState() {
    super.initState();
    // 访问一次平台通道，促使插件在部分场景下完成注册（修复热重载后 MissingPluginException 的偶现）
    // ignore: unawaited_futures
    FilePicker.platform.clearTemporaryFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PrimaryHeader(title: '导入账单', showBack: true),
            const Text(
                '选择 CSV/TSV 文件或粘贴内容。支持表头自动识别；也可下方“字段映射”手动指定列，避免因表头不匹配导入失败。'),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final text = data?.text ?? '';
                    if (text.isNotEmpty) {
                      setState(() => _controller.text = text);
                    }
                  },
                  icon: const Icon(Icons.paste),
                  label: const Text('从剪贴板粘贴'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _picked?.name ?? '未选择文件',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 字段映射区块（预览前几行 + 下拉映射）
            _MappingBlock(
              controller: _controller,
              hasHeader: _hasHeader,
              onPreview: (_) {},
              mapping: _mapping,
              onMappingChanged: (k, v) => setState(() => _mapping[k] = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'date,type,amount,category,note\n2025-08-01,expense,12.50,餐饮,午餐',
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                    value: _hasHeader,
                    onChanged: (v) => setState(() => _hasHeader = v ?? true)),
                const Text('第一行是表头'),
                const Spacer(),
                FilledButton(
                  onPressed: _onImport,
                  child: const Text('导入'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _onImport() async {
    String csvText = _controller.text.trim();
    if (_picked != null) {
      if (_picked!.path != null) {
        try {
          csvText = await File(_picked!.path!).readAsString();
        } catch (_) {
          // ignore and fallback to bytes
        }
      }
      if ((csvText.isEmpty) && _picked!.bytes != null) {
        csvText = String.fromCharCodes(_picked!.bytes!);
      }
    }
    if (csvText.isEmpty) return;
    // 跳转到确认映射页，批量导入在新页面执行
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ImportConfirmPage(csvText: csvText, hasHeader: _hasHeader),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt'],
        allowMultiple: false,
        withData: true, // iOS 模拟器/沙盒下读取 bytes
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() => _picked = res.files.first);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开文件选择器：$e\n可以尝试把文本复制后使用“从剪贴板粘贴”导入。')),
      );
    }
  }
}

List<List<String>> _parseRows(String input) {
  // 去除 BOM、统一换行
  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  // 优先使用 CSV 解析器（tab 或 逗号）
  if (text.contains('\t')) {
    return CsvToListConverter(fieldDelimiter: '\t')
        .convert(text)
        .map((r) => r.map((e) => (e?.toString() ?? '').trim()).toList())
        .toList();
  }
  if (text.contains(',')) {
    return CsvToListConverter(fieldDelimiter: ',')
        .convert(text)
        .map((r) => r.map((e) => (e?.toString() ?? '').trim()).toList())
        .toList();
  }
  // 回退：按“连续空白”切列（支持全角空格\u3000、NBSP\u00A0）
  final ws = RegExp(r'[ \t\u00A0\u3000]+');
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
  return lines.map((l) => l.trim().split(ws).toList()).toList();
}

class _MappingBlock extends StatefulWidget {
  final TextEditingController controller;
  final bool hasHeader;
  final void Function(List<List<String>> rows) onPreview;
  final Map<String, int?> mapping;
  final void Function(String key, int? index) onMappingChanged;
  const _MappingBlock({
    required this.controller,
    required this.hasHeader,
    required this.onPreview,
    required this.mapping,
    required this.onMappingChanged,
  });

  @override
  State<_MappingBlock> createState() => _MappingBlockState();
}

class _MappingBlockState extends State<_MappingBlock> {
  List<List<String>> rows = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    final text = widget.controller.text;
    final parsed = _parseRows(text);
    setState(() => rows = parsed.take(6).toList());
    widget.onPreview(rows);
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final headers = rows.first;
    // final sampleStart = widget.hasHeader ? 1 : 0;
    final columnCount = headers.length;
    List<DropdownMenuItem<int>> makeItems() => List.generate(columnCount, (i) {
          final label = (widget.hasHeader &&
                  i < headers.length &&
                  headers[i].trim().isNotEmpty)
              ? headers[i].trim()
              : '第 ${i + 1} 列';
          return DropdownMenuItem(
              value: i, child: Text(label, overflow: TextOverflow.ellipsis));
        });
    Widget buildMapping(String key, String label) {
      return Row(
        children: [
          SizedBox(width: 64, child: Text(label)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: widget.mapping[key],
            hint: const Text('自动'),
            items: makeItems(),
            onChanged: (v) => widget.onMappingChanged(key, v),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('字段映射（可选）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              buildMapping('date', '日期'),
              buildMapping('type', '类型'),
              buildMapping('amount', '金额'),
              buildMapping('category', '分类'),
              buildMapping('note', '备注'),
            ],
          ),
          const SizedBox(height: 8),
          Text('预览：', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          _PreviewTable(rows: rows),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final List<List<String>> rows;
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (int r = 0; r < rows.length; r++)
              Container(
                color: r == 0 ? Colors.grey.shade100 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  children: [
                    for (final cell in rows[r])
                      Expanded(
                        child: Text(
                          cell,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: r == 0 ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
