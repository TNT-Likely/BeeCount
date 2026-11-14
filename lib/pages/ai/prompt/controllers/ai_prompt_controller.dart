import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../ai/core/prompt_builder.dart';
import '../../../../ai/providers/ai_constants.dart';
import '../../../../ai/providers/ai_provider_manager.dart';

/// Owns actual App persistence and draft semantics; UI packages never read preferences.
class AIPromptEditorController extends ChangeNotifier {
  AIPromptEditorController(
      {Future<String?> Function()? load, Future<void> Function(String)? save})
      : _load = load ?? _read,
        _save = save ?? AIProviderManager.saveCustomPrompt {
    text.addListener(_changed);
  }
  final Future<String?> Function() _load;
  final Future<void> Function(String) _save;
  final text = TextEditingController();
  String _saved = '';
  bool loading = true, saving = false, _disposed = false;
  Object? error;
  bool get dirty => text.text != _saved;
  List<PromptPlaceholder> get missing =>
      PromptBuilder.missingPlaceholdersIn(text.text);
  static Future<String?> _read() async =>
      (await SharedPreferences.getInstance())
          .getString(AIConstants.keyAiCustomPrompt);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    _changed();
    try {
      final value = await _load();
      if (_disposed) return;
      _saved = value != null && value.trim().isNotEmpty
          ? value
          : PromptBuilder.defaultTemplate;
      text.text = _saved;
    } catch (e) {
      if (!_disposed) error = e;
    }
    if (!_disposed) {
      loading = false;
      _changed();
    }
  }

  Future<bool> save() async {
    if (saving || loading) return false;
    saving = true;
    error = null;
    _changed();
    final submitted = text.text;
    try {
      await _save(submitted);
      if (!_disposed) _saved = submitted;
      return true;
    } catch (e) {
      if (!_disposed) error = e;
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        _changed();
      }
    }
  }

  void resetDraft() => text.text = PromptBuilder.defaultTemplate;
  bool append(PromptPlaceholder placeholder) {
    final snippet = placeholder.appendSnippet;
    if (snippet == null) return false;
    text.text = '${text.text.trimRight()}\n$snippet';
    return true;
  }

  String preview({DateTime? at}) {
    final now = at ?? DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '$date ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    // Preserve the original synthetic preview examples and replacement order.
    return text.text
        .replaceAll('{{INPUT_SOURCE}}', '从以下支付账单文本中')
        .replaceAll('{{CURRENT_TIME}}', time)
        .replaceAll('{{CURRENT_DATE}}', date)
        .replaceAll(
            '{{OCR_TEXT}}', '商品名称：星巴克拿铁咖啡\n金额：￥35.00\n支付时间：2025-01-15 14:30')
        .replaceAll('{{CATEGORIES}}', '分类列表：\n支出：餐饮、交通、购物、娱乐、居家\n收入：工资、理财、红包')
        .replaceAll('{{ACCOUNTS}}', '\n账户列表：微信、支付宝、现金、Chase(USD)')
        .replaceAll('{{CURRENCIES}}', '\n账本主币种：CNY；账本内已有外币账户：USD');
  }

  @override
  void dispose() {
    _disposed = true;
    text.removeListener(_changed);
    text.dispose();
    super.dispose();
  }
}
