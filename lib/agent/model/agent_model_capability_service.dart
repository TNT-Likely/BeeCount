import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_factory.dart';
import '../../ai/providers/ai_provider_manager.dart';

typedef AgentProviderConfigLoader = Future<AIServiceProviderConfig?> Function();
typedef AgentProviderCapabilityProbe = Future<AgentModelCapabilities> Function(
  AIServiceProviderConfig config,
);

/// SharedPreferences adapter for agentcore's provider-neutral capability
/// cache. Only capability metadata is persisted; raw API keys are never
/// stored. The fingerprint contains only a SHA-256 digest so rotating a
/// credential invalidates stale capability results.
final class SharedPreferencesAgentModelCapabilityStore
    implements AgentModelCapabilityStore {
  SharedPreferencesAgentModelCapabilityStore({
    required Future<SharedPreferences> Function() getPreferences,
  }) : _getPreferences = getPreferences;

  static const _storageKey = 'agent_model_capabilities_v1';

  final Future<SharedPreferences> Function() _getPreferences;

  @override
  Future<AgentModelCapabilities?> read(String fingerprint) async {
    final preferences = await _getPreferences();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final all = jsonDecode(raw);
      if (all is! Map || all[fingerprint] is! Map) return null;
      return AgentModelCapabilities.fromJson(
        Map<String, Object?>.from(all[fingerprint] as Map),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(
    String fingerprint,
    AgentModelCapabilities capabilities,
  ) async {
    final preferences = await _getPreferences();
    final raw = preferences.getString(_storageKey);
    var all = <String, Object?>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) all = Map<String, Object?>.from(decoded);
      } on Object {
        // Replace a corrupt cache. Capability probes contain no user data.
      }
    }
    all[fingerprint] = capabilities.toJson();
    await preferences.setString(_storageKey, jsonEncode(all));
  }
}

/// Loads and probes the currently selected text model through the reusable
/// agentcore resolver.
final class AgentModelCapabilityService {
  AgentModelCapabilityService({
    required AgentModelCapabilityStore store,
    AgentProviderConfigLoader? loadConfig,
    AgentProviderCapabilityProbe? probe,
    Duration maximumAge = const Duration(days: 7),
  })  : _loadConfig = loadConfig ?? _loadCurrentConfig,
        _probe = probe ?? _probeConfig,
        _resolver = AgentModelCapabilityResolver(
          store: store,
          maximumAge: maximumAge,
        );

  final AgentProviderConfigLoader _loadConfig;
  final AgentProviderCapabilityProbe _probe;
  final AgentModelCapabilityResolver _resolver;

  Future<AgentModelCapabilities?> resolve({bool forceRefresh = false}) async {
    final config = await _loadConfig();
    if (config == null || !config.isValid || !config.supportsText) return null;
    return _resolver.resolve(
      fingerprint: fingerprint(config),
      forceRefresh: forceRefresh,
      probe: () => _probe(config),
    );
  }

  Future<void> cache(
    AIServiceProviderConfig config,
    AgentModelCapabilities capabilities,
  ) =>
      _resolver.store.write(fingerprint(config), capabilities);

  static String fingerprint(AIServiceProviderConfig config) {
    final credentialDigest = sha256.convert(utf8.encode(config.apiKey));
    return base64Url.encode(utf8.encode(
      '${config.baseUrl}\n${config.textModel}\n$credentialDigest',
    ));
  }

  static Future<AIServiceProviderConfig?> _loadCurrentConfig() =>
      AIProviderManager.getProviderForCapability(AICapabilityType.text);

  static Future<AgentModelCapabilities> _probeConfig(
    AIServiceProviderConfig config,
  ) =>
      AIProviderFactory.probeAgentCapabilities(config);
}
