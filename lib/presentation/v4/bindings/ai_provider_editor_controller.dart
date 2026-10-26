import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';
import '../../../ai/providers/ai_constants.dart';
import '../../../ai/providers/ai_provider_config.dart';
import '../../../ai/providers/ai_provider_factory.dart';
import '../../../ai/providers/ai_provider_manager.dart';
import '../../../l10n/app_localizations.dart';

enum TestStatus { idle, testing, success, failed }

enum ProviderTestCapability { text, vision, speech }

/// App-only request seam: presentation packages do not load credentials or create clients.
abstract class AIProviderConnectionTester {
  Future<(bool, String?)> test(
      AIServiceProviderConfig config, ProviderTestCapability capability,
      {void Function(AgentModelCapabilities)? onCapabilities});
}

class ProductionAIProviderConnectionTester
    implements AIProviderConnectionTester {
  const ProductionAIProviderConnectionTester();
  @override
  Future<(bool, String?)> test(
          AIServiceProviderConfig config, ProviderTestCapability capability,
          {void Function(AgentModelCapabilities)? onCapabilities}) =>
      switch (capability) {
        ProviderTestCapability.text => AIProviderFactory.validateTextCapability(
            config,
            onCapabilities: onCapabilities),
        ProviderTestCapability.vision =>
          AIProviderFactory.validateVisionCapability(config),
        ProviderTestCapability.speech =>
          AIProviderFactory.validateSpeechCapability(config),
      };
}

class AIProviderEditorController extends ChangeNotifier {
  AIProviderEditorController(
      {required this.l,
      this.original,
      this.tester = const ProductionAIProviderConnectionTester(),
      this.onCapabilities}) {
    name = TextEditingController(text: original?.name ?? '');
    key = TextEditingController(text: original?.apiKey ?? '');
    url = TextEditingController(text: original?.baseUrl ?? '');
    text = TextEditingController(text: original?.textModel ?? '');
    vision = TextEditingController(text: original?.visionModel ?? '');
    speech = TextEditingController(text: original?.audioModel ?? '');
    for (final c in fields) {
      c.addListener(_changed);
    }
  }
  final AppLocalizations l;
  final AIServiceProviderConfig? original;
  final AIProviderConnectionTester tester;
  final Future<void> Function(AIServiceProviderConfig, AgentModelCapabilities)?
      onCapabilities;
  late final TextEditingController name, key, url, text, vision, speech;
  List<TextEditingController> get fields =>
      [name, key, url, text, vision, speech];
  final statuses = {
    for (final c in ProviderTestCapability.values) c: TestStatus.idle
  };
  final Map<ProviderTestCapability, String?> details = {};
  bool saving = false, obscure = true, _disposed = false;
  bool get builtIn => original?.isBuiltIn ?? false;
  bool get busy => statuses.values.contains(TestStatus.testing);
  AIServiceProviderConfig get draft => AIServiceProviderConfig(
      id: original?.id ?? 'test',
      name: name.text,
      isBuiltIn: builtIn,
      apiKey: key.text,
      baseUrl: url.text,
      textModel: text.text,
      visionModel: vision.text,
      audioModel: speech.text,
      createdAt: original?.createdAt ?? DateTime.now());
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void toggleObscure() {
    obscure = !obscure;
    _changed();
  }

  bool canTest(ProviderTestCapability c) =>
      key.text.isNotEmpty &&
      switch (c) {
        ProviderTestCapability.text => text.text.isNotEmpty,
        ProviderTestCapability.vision => vision.text.isNotEmpty,
        ProviderTestCapability.speech => speech.text.isNotEmpty,
      };
  Future<String?> test(ProviderTestCapability capability) async {
    if (key.text.isEmpty) return l.aiProviderNoApiKey;
    statuses[capability] = TestStatus.testing;
    details[capability] = null;
    _changed();
    try {
      final config = draft;
      AgentModelCapabilities? detected;
      final result = await tester.test(config, capability,
          onCapabilities: (v) => detected = v);
      if (!_disposed && detected != null && onCapabilities != null) {
        await onCapabilities!(config, detected!);
      }
      if (!_disposed) {
        statuses[capability] =
            result.$1 ? TestStatus.success : TestStatus.failed;
        details[capability] = result.$2;
        _changed();
      }
    } catch (e) {
      if (!_disposed) {
        statuses[capability] = TestStatus.failed;
        details[capability] = AIProviderFactory.userFacingError(e);
        _changed();
      }
    }
    return null;
  }

  Future<void> testAll() async {
    await Future.wait([for (final c in ProviderTestCapability.values) test(c)]);
  }

  Future<(bool, String?)> save() async {
    if (!builtIn && name.text.trim().isEmpty) {
      return (false, l.aiProviderNameRequired);
    }
    if (!builtIn && url.text.trim().isEmpty) {
      return (false, l.aiProviderBaseUrlRequired);
    }
    if (saving || busy) return (false, null);
    saving = true;
    _changed();
    try {
      if (original != null) {
        await AIProviderManager.updateProvider(original!.copyWith(
            name: builtIn ? null : name.text.trim(),
            apiKey: key.text.trim(),
            baseUrl: builtIn ? null : url.text.trim(),
            textModel: text.text.trim(),
            visionModel: vision.text.trim(),
            audioModel: speech.text.trim()));
      } else {
        await AIProviderManager.addProvider(
            name: name.text.trim(),
            apiKey: key.text.trim(),
            baseUrl: url.text.trim(),
            textModel: text.text.trim(),
            visionModel: vision.text.trim(),
            audioModel: speech.text.trim());
      }
      return (true, null);
    } catch (e) {
      return (false, '$e');
    } finally {
      saving = false;
      _changed();
    }
  }

  String modelHint(ProviderTestCapability c) => switch (c) {
        ProviderTestCapability.text =>
          builtIn ? AIConstants.defaultGlmModel : 'gpt-4o-mini',
        ProviderTestCapability.vision =>
          builtIn ? AIConstants.defaultGlmVisionModel : 'gpt-4o',
        ProviderTestCapability.speech =>
          builtIn ? AIConstants.defaultGlmAudioModel : 'whisper-1',
      };
  @override
  void dispose() {
    _disposed = true;
    for (final c in fields) {
      c.removeListener(_changed);
      c.dispose();
    }
    super.dispose();
  }
}
