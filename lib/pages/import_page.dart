import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ui/ui.dart';
import 'import_confirm_page.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _controller = TextEditingController();
  final bool _hasHeader = true;
  PlatformFile? _picked;
  bool _reading = false;
  double? _readProgress; // 0~1
  bool _cancelRead = false;

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
      body: Column(
        children: [
          const PrimaryHeader(title: '导入账单', showBack: true),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('请选择 CSV/TSV 文件进行导入（默认第一行为表头）'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('选择文件'),
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
                      const Spacer(),
                      if (_picked == null)
                        const Text('提示：请选择一个 CSV/TSV 文件开始导入',
                            style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                if (_reading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          width: 320,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('读取文件中…'),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: _readProgress),
                              const SizedBox(height: 8),
                              Text(_readProgress == null
                                  ? '准备中…'
                                  : '${((_readProgress ?? 0) * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() => _cancelRead = true);
                                },
                                child: const Text('取消'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onImport() async {
    String csvText = _controller.text.trim();
    if (_picked != null) {
      csvText = await _readFileStreaming(_picked!);
    }
    if (csvText.isEmpty) return; // 可能读取被取消
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
        // 选中即进入确认页
        await _onImport();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      showToast(context, '无法打开文件选择器：$e');
    }
  }

  // 流式读取文件并显示进度（State 内部方法，可使用 setState）
  Future<String> _readFileStreaming(PlatformFile picked) async {
    if (!mounted) return '';
    if (picked.path == null || picked.path!.isEmpty) {
      final b = picked.bytes;
      if (b == null || b.isEmpty) return '';
      return _decodeBytes(b);
    }
    final file = File(picked.path!);
    final exists = await file.exists();
    if (!exists) {
      final b = picked.bytes;
      if (b == null || b.isEmpty) return '';
      return _decodeBytes(b);
    }

    const int chunkSize = 256 * 1024; // 256KB
    final length = await file.length();
    final raf = await file.open();
    try {
      final chunks = <List<int>>[];
      int offset = 0;
      setState(() {
        _reading = true;
        _readProgress = 0;
        _cancelRead = false;
      });
      while (offset < length) {
        if (_cancelRead) {
          setState(() {
            _reading = false;
            _readProgress = null;
          });
          return '';
        }
        final toRead =
            (length - offset) < chunkSize ? (length - offset) : chunkSize;
        final bytes = await raf.read(toRead);
        if (bytes.isEmpty) break;
        chunks.add(bytes);
        offset += bytes.length;
        setState(() {
          _readProgress = offset / (length == 0 ? 1 : length);
        });
        await Future<void>.delayed(Duration.zero);
      }
      final all = <int>[];
      for (final c in chunks) {
        all.addAll(c);
      }
      final text = _decodeBytes(all);
      setState(() {
        _reading = false;
        _readProgress = null;
      });
      return text;
    } finally {
      await raf.close();
    }
  }
}

// 解析逻辑统一在确认页进行

// 尝试识别编码并把字节转为字符串：优先 BOM；其次假定 UTF-8；最后使用 latin1 兜底
String _decodeBytes(List<int> bytes) {
  if (bytes.length >= 2) {
    // UTF-16 LE BOM FF FE
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      try {
        // 使用 dart:convert 的 Utf16Codec 需要自实现，这里简化按小端解析
        final codeUnits = <int>[];
        for (int i = 2; i + 1 < bytes.length; i += 2) {
          codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
        }
        return String.fromCharCodes(codeUnits);
      } catch (_) {}
    }
    // UTF-16 BE BOM FE FF
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      try {
        final codeUnits = <int>[];
        for (int i = 2; i + 1 < bytes.length; i += 2) {
          codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
        }
        return String.fromCharCodes(codeUnits);
      } catch (_) {}
    }
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    // UTF-8 BOM
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    // 兜底 latin1（部分 GBK 会显示乱码，但用户可粘贴修正）
    return latin1.decode(bytes);
  }
}

//（已简化导入流程，移除了页面内的手动映射区块）

// 预览组件已移除
