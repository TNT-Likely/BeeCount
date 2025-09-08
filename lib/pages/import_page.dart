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
            child: Padding(
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
          ),
        ],
      ),
    );
  }

  Future<void> _onImport() async {
    String csvText = _controller.text.trim();
    if (_picked != null) {
      List<int>? bytes;
      try {
        if (_picked!.path != null) {
          bytes = await File(_picked!.path!).readAsBytes();
        }
      } catch (_) {
        // ignore and fallback to picker provided bytes
      }
      bytes ??= _picked!.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        csvText = _decodeBytes(bytes);
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
        // 选中即进入确认页
        await _onImport();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开文件选择器：$e\n可以尝试把文本复制后使用“从剪贴板粘贴”导入。')),
      );
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
