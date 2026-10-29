import 'dart:async';
import 'dart:convert';
import 'package:agentcore/agentcore.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/providers/controllers/ai_provider_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tester implements AIProviderConnectionTester {
  final pending = <ProviderTestCapability, Completer<(bool, String?)>>{};
  final calls = <ProviderTestCapability>[];
  @override
  Future<(bool, String?)> test(
      AIServiceProviderConfig config, ProviderTestCapability capability,
      {void Function(AgentModelCapabilities)? onCapabilities}) {
    calls.add(capability);
    return (pending[capability] = Completer<(bool, String?)>()).future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = lookupAppLocalizations(const Locale('zh'));
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ai_providers_v2':
          jsonEncode([AIServiceProviderConfig.zhipuDefault.toJson()])
    });
  });
  AIProviderEditorController create(
          {_Tester? tester, AIServiceProviderConfig? original}) =>
      AIProviderEditorController(
          l: l, original: original, tester: tester ?? _Tester());
  void fill(AIProviderEditorController c) {
    c.name.text = ' QA服务商 ';
    c.url.text = ' https://qa.invalid/v1 ';
    c.key.text = ' qa-only-key ';
    c.text.text = ' qa-text ';
    c.vision.text = ' qa-vision ';
  }

  test('缺名称/URL拒绝，不要求密钥或全部模型，也不写配置', () async {
    final c = create();
    expect((await c.save()).$2, l.aiProviderNameRequired);
    c.name.text = 'QA';
    expect((await c.save()).$2, l.aiProviderBaseUrlRequired);
    expect((await AIProviderManager.getProviders()).length, 1);
    c.dispose();
  });
  test('新增编辑保留身份/创建时间，原精简模型及空密钥允许保存', () async {
    final c = create();
    fill(c);
    expect((await c.save()).$1, isTrue);
    final p = (await AIProviderManager.getProviders()).last;
    expect(p.name, 'QA服务商');
    expect(p.baseUrl, 'https://qa.invalid/v1');
    expect(p.apiKey, 'qa-only-key');
    expect(p.audioModel, '');
    c.dispose();
    final edit = create(original: p);
    edit.name.text = '改名';
    edit.key.clear();
    expect((await edit.save()).$1, isTrue);
    final updated = (await AIProviderManager.getProviders()).last;
    expect(updated.id, p.id);
    expect(updated.createdAt, p.createdAt);
    expect(updated.apiKey, '');
    expect(updated.visionModel, p.visionModel);
    edit.dispose();
  });
  test('内置服务商身份/名称/URL保持原值，只保存允许修改的字段', () async {
    final p = AIServiceProviderConfig.zhipuDefault,
        c = create(original: AIServiceProviderConfig.zhipuDefault);
    c.name.text = '不应覆盖';
    c.url.text = 'https://invalid.example';
    c.text.text = ' QA模型 ';
    expect((await c.save()).$1, isTrue);
    final saved = (await AIProviderManager.getProviders()).first;
    expect(saved.id, p.id);
    expect(saved.name, p.name);
    expect(saved.baseUrl, p.baseUrl);
    expect(saved.createdAt, p.createdAt);
    expect(saved.textModel, 'QA模型');
    c.dispose();
  });
  test('真实请求边界在App，测试中阻止保存/重复提交并呈现成功失败', () async {
    final tester = _Tester(), c = create(tester: tester);
    fill(c);
    final future = c.test(ProviderTestCapability.text);
    expect(c.busy, isTrue);
    expect(c.statuses[ProviderTestCapability.text], TestStatus.testing);
    expect((await c.save()).$1, isFalse);
    expect((await AIProviderManager.getProviders()).length, 1);
    tester.pending[ProviderTestCapability.text]!.complete((true, '工具调用兼容'));
    await future;
    expect(c.statuses[ProviderTestCapability.text], TestStatus.success);
    expect(c.details[ProviderTestCapability.text], '工具调用兼容');
    final failing = c.test(ProviderTestCapability.vision);
    tester.pending[ProviderTestCapability.vision]!.complete((false, '合成失败'));
    await failing;
    expect(c.statuses[ProviderTestCapability.vision], TestStatus.failed);
    expect(c.details[ProviderTestCapability.vision], '合成失败');
    c.dispose();
  });
  test('三能力原并行一键测试，以及关闭后完成不通知已销毁控制器', () async {
    final tester = _Tester(), c = create(tester: tester);
    fill(c);
    c.speech.text = 'qa-audio';
    final all = c.testAll();
    expect(tester.calls.toSet(), ProviderTestCapability.values.toSet());
    for (final pending in tester.pending.values) {
      pending.complete((true, null));
    }
    await all;
    expect(c.statuses.values.every((s) => s == TestStatus.success), isTrue);
    final pending = c.test(ProviderTestCapability.text);
    c.dispose();
    tester.pending[ProviderTestCapability.text]!.complete((true, null));
    await pending;
  });
}
