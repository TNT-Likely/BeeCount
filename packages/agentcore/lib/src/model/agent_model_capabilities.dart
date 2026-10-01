import 'dart:collection';

/// Three-state capability value used when a provider has not been probed yet
/// or a transient network failure prevents a definitive answer.
enum AgentCapabilitySupport { supported, unsupported, unknown }

/// Provider/model capabilities required by a native-tool Agent runtime.
///
/// The contract is provider-neutral and serializable so applications can keep
/// a short-lived local cache without coupling agentcore to a storage package.
final class AgentModelCapabilities {
  AgentModelCapabilities({
    required this.nativeToolCalls,
    this.text = AgentCapabilitySupport.unknown,
    this.streaming = AgentCapabilitySupport.unknown,
    this.forcedToolChoice = AgentCapabilitySupport.unknown,
    this.detail,
    DateTime? checkedAt,
    Map<String, Object?> metadata = const {},
  })  : checkedAt = checkedAt ?? DateTime.now(),
        metadata = UnmodifiableMapView(Map.of(metadata));

  final AgentCapabilitySupport text;
  final AgentCapabilitySupport nativeToolCalls;
  final AgentCapabilitySupport streaming;
  final AgentCapabilitySupport forcedToolChoice;
  final String? detail;
  final DateTime checkedAt;
  final Map<String, Object?> metadata;

  bool get canRunNativeToolAgent =>
      nativeToolCalls == AgentCapabilitySupport.supported;

  bool isFresh(Duration maximumAge, {DateTime? now}) {
    final age = (now ?? DateTime.now()).difference(checkedAt);
    return !age.isNegative && age <= maximumAge;
  }

  Map<String, Object?> toJson() => {
        'text': text.name,
        'nativeToolCalls': nativeToolCalls.name,
        'streaming': streaming.name,
        'forcedToolChoice': forcedToolChoice.name,
        'detail': detail,
        'checkedAt': checkedAt.toIso8601String(),
        'metadata': metadata,
      };

  factory AgentModelCapabilities.fromJson(Map<String, Object?> json) =>
      AgentModelCapabilities(
        text: _supportFrom(json['text']),
        nativeToolCalls: _supportFrom(json['nativeToolCalls']),
        streaming: _supportFrom(json['streaming']),
        forcedToolChoice: _supportFrom(json['forcedToolChoice']),
        detail: json['detail'] as String?,
        // A corrupt/missing cache timestamp must be stale, not silently reset
        // to "now" on every read (which could block a model indefinitely).
        checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        metadata: json['metadata'] is Map
            ? Map<String, Object?>.from(json['metadata']! as Map)
            : const {},
      );

  static AgentCapabilitySupport _supportFrom(Object? value) {
    for (final support in AgentCapabilitySupport.values) {
      if (support.name == value) return support;
    }
    return AgentCapabilitySupport.unknown;
  }
}

/// Application-owned persistence for provider/model capability reports.
abstract interface class AgentModelCapabilityStore {
  Future<AgentModelCapabilities?> read(String fingerprint);

  Future<void> write(
    String fingerprint,
    AgentModelCapabilities capabilities,
  );
}

typedef AgentModelCapabilityProbe = Future<AgentModelCapabilities> Function();

/// Resolves a fresh cached capability report or runs the supplied probe.
final class AgentModelCapabilityResolver {
  const AgentModelCapabilityResolver({
    required this.store,
    this.maximumAge = const Duration(days: 7),
  });

  final AgentModelCapabilityStore store;
  final Duration maximumAge;

  Future<AgentModelCapabilities> resolve({
    required String fingerprint,
    required AgentModelCapabilityProbe probe,
    bool forceRefresh = false,
    DateTime? now,
  }) async {
    if (!forceRefresh) {
      final cached = await store.read(fingerprint);
      if (cached != null && cached.isFresh(maximumAge, now: now)) {
        return cached;
      }
    }
    final capabilities = await probe();
    await store.write(fingerprint, capabilities);
    return capabilities;
  }
}
