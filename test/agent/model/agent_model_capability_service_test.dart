import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/model/agent_model_capability_service.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores and reuses a capability report for the same provider model',
      () async {
    final config = _config(apiKey: 'secret-one');
    var probes = 0;
    final service = AgentModelCapabilityService(
      store: SharedPreferencesAgentModelCapabilityStore(
        getPreferences: SharedPreferences.getInstance,
      ),
      loadConfig: () async => config,
      probe: (_) async {
        probes++;
        return AgentModelCapabilities(
          text: AgentCapabilitySupport.supported,
          nativeToolCalls: AgentCapabilitySupport.supported,
        );
      },
    );

    final first = await service.resolve();
    final second = await service.resolve();

    expect(first?.canRunNativeToolAgent, isTrue);
    expect(second?.canRunNativeToolAgent, isTrue);
    expect(probes, 1);
  });

  test('fingerprint contains no API key and changes with credentials or model',
      () {
    final first = AgentModelCapabilityService.fingerprint(
      _config(apiKey: 'top-secret'),
    );
    final sameModelNewKey = AgentModelCapabilityService.fingerprint(
      _config(apiKey: 'rotated-secret'),
    );
    final anotherModel = AgentModelCapabilityService.fingerprint(
      _config(apiKey: 'top-secret', textModel: 'model-b'),
    );

    expect(first, isNot(sameModelNewKey));
    expect(first, isNot(contains('top-secret')));
    expect(first, isNot(anotherModel));
  });
}

AIServiceProviderConfig _config({
  required String apiKey,
  String textModel = 'model-a',
}) =>
    AIServiceProviderConfig(
      id: 'provider-a',
      name: 'Provider A',
      apiKey: apiKey,
      baseUrl: 'https://example.com/v1',
      textModel: textModel,
      createdAt: DateTime.utc(2026),
    );
