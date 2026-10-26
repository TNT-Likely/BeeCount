import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:beecount/ai/core/prompt_builder.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/presentation/v4/bindings/ai_prompt_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AIProviderManager.onConfigChanged = null);
  test('HTML完整模板和八个变量从原Dart源生成，补丁逐字一致', () {
    final registry = jsonDecode(
        File('docs/design/card-refresh/tokens/ai-prompt-template.json')
            .readAsStringSync()) as Map<String, dynamic>;
    expect(registry['template'], PromptBuilder.defaultTemplate);
    expect(registry['snippet'], PromptBuilder.currencySectionSnippet);
    expect(registry['variables'],
        PromptBuilder.placeholders.map((p) => p.token).toList());
  });
  test('空和空白旧配置回退原模板，不自动写入', () async {
    for (final value in [null, '', '  \n']) {
      final c = AIPromptEditorController(load: () async => value);
      await c.load();
      expect(c.text.text, PromptBuilder.defaultTemplate);
      expect(c.dirty, isFalse);
      expect(
          (await SharedPreferences.getInstance())
              .containsKey('ai_custom_prompt'),
          isFalse);
      c.dispose();
    }
  });
  test('自定义文本逐字保留，安全补丁/重置只改草稿，保存沿原Manager发通知', () async {
    const original = '我的模板 {{OCR_TEXT}}';
    SharedPreferences.setMockInitialValues({'ai_custom_prompt': original});
    var notified = 0;
    AIProviderManager.onConfigChanged = () => notified++;
    final c = AIPromptEditorController();
    await c.load();
    expect(c.text.text, original);
    final missing = c.missing;
    final safe = missing.firstWhere((v) => v.appendSnippet != null);
    final unsafe = PromptBuilder.placeholders
        .firstWhere((v) => v.token == '{{BILL_GUARD}}');
    expect(c.append(unsafe), isFalse);
    expect(c.append(safe), isTrue);
    expect(c.text.text.startsWith(original), isTrue);
    expect(c.missing.any((v) => v.token == safe.token), isFalse);
    expect(
        (await SharedPreferences.getInstance()).getString('ai_custom_prompt'),
        original);
    c.resetDraft();
    expect(c.text.text, PromptBuilder.defaultTemplate);
    expect(c.dirty, isTrue);
    expect(await c.save(), isTrue);
    expect(notified, 1);
    expect(c.dirty, isFalse);
    expect(
        (await SharedPreferences.getInstance()).getString('ai_custom_prompt'),
        PromptBuilder.defaultTemplate);
    c.dispose();
  });
  test('保存以提交快照为准，阻止重复，稍后编辑仍标未保存', () async {
    final pending = Completer<void>();
    final writes = <String>[];
    final c = AIPromptEditorController(
        load: () async => 'before',
        save: (s) {
          writes.add(s);
          return pending.future;
        });
    await c.load();
    c.text.text = 'submitted';
    final save = c.save();
    expect(c.saving, isTrue);
    c.text.text = 'later';
    expect(await c.save(), isFalse);
    pending.complete();
    expect(await save, isTrue);
    expect(writes, ['submitted']);
    expect(c.dirty, isTrue);
    expect(c.text.text, 'later');
    c.dispose();
  });
  test('加载和写失败可重试，失败不清除草稿', () async {
    var fail = true;
    final c = AIPromptEditorController(load: () async {
      if (fail) throw StateError('synthetic read');
      return 'saved';
    }, save: (_) async {
      throw StateError('synthetic write');
    });
    await c.load();
    expect(c.error, isA<StateError>());
    expect(c.loading, isFalse);
    fail = false;
    await c.load();
    expect(c.text.text, 'saved');
    expect(c.error, isNull);
    c.text.text = 'draft';
    expect(await c.save(), isFalse);
    expect(c.text.text, 'draft');
    expect(c.dirty, isTrue);
    expect(c.saving, isFalse);
    c.dispose();
  });
  test('异步返回已退出页面不再发通知或访问已释放控制器', () async {
    final pending = Completer<String?>();
    final c = AIPromptEditorController(load: () => pending.future);
    final load = c.load();
    c.dispose();
    pending.complete('later');
    await load;
    final saved = Completer<void>();
    final other = AIPromptEditorController(
        load: () async => 'saved', save: (_) => saved.future);
    await other.load();
    other.text.text = 'edited';
    final operation = other.save();
    other.dispose();
    saved.complete();
    expect(await operation, isTrue);
  });
  test('预览仍用原示例/时间/多币种，不写草稿，不替换原未替换的过滤段', () async {
    final c = AIPromptEditorController(
        load: () async =>
            '{{BILL_GUARD}} {{INPUT_SOURCE}} {{CURRENT_TIME}} {{CURRENT_DATE}} {{OCR_TEXT}} {{CATEGORIES}} {{ACCOUNTS}} {{CURRENCIES}}');
    await c.load();
    final before = c.text.text;
    final preview = c.preview(at: DateTime(2026, 10, 25, 9, 1));
    expect(preview, contains('2026-10-25 09:01'));
    expect(preview, contains('Chase(USD)'));
    expect(preview, contains('账本主币种：CNY'));
    expect(preview, contains('星巴克拿铁咖啡'));
    expect(preview, contains('{{BILL_GUARD}}'));
    expect(preview, isNot(contains('{{OCR_TEXT}}')));
    expect(c.text.text, before);
    expect(c.dirty, isFalse);
    c.dispose();
  });
}
