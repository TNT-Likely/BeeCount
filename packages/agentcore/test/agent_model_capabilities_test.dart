import 'package:agentcore/agentcore.dart';
import 'package:test/test.dart';

void main() {
  test('capability report survives storage serialization', () {
    final checkedAt = DateTime.utc(2026, 9, 29, 8);
    final original = AgentModelCapabilities(
      text: AgentCapabilitySupport.supported,
      nativeToolCalls: AgentCapabilitySupport.supported,
      streaming: AgentCapabilitySupport.unsupported,
      forcedToolChoice: AgentCapabilitySupport.unknown,
      detail: 'fallback',
      checkedAt: checkedAt,
      metadata: const {'provider': 'example'},
    );

    final restored = AgentModelCapabilities.fromJson(original.toJson());

    expect(restored.text, AgentCapabilitySupport.supported);
    expect(restored.nativeToolCalls, AgentCapabilitySupport.supported);
    expect(restored.streaming, AgentCapabilitySupport.unsupported);
    expect(restored.checkedAt, checkedAt);
    expect(restored.metadata, {'provider': 'example'});
  });

  test('invalid cache timestamps do not renew an unsupported verdict', () {
    final now = DateTime.utc(2026, 10, 1);
    for (final timestamp in [null, '', 'invalid-date']) {
      final report = AgentModelCapabilities.fromJson({
        'nativeToolCalls': 'unsupported',
        'checkedAt': timestamp,
      });
      expect(report.checkedAt,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
      expect(report.isFresh(const Duration(days: 7), now: now), isFalse);
    }
  });

  test('resolver reuses fresh reports and refreshes stale reports', () async {
    final now = DateTime.utc(2026, 9, 29);
    final store = _MemoryStore();
    final resolver = AgentModelCapabilityResolver(
      store: store,
      maximumAge: const Duration(days: 7),
    );
    var probes = 0;
    Future<AgentModelCapabilities> probe() async {
      probes++;
      return AgentModelCapabilities(
        nativeToolCalls: AgentCapabilitySupport.supported,
        checkedAt: now,
      );
    }

    await resolver.resolve(fingerprint: 'model', probe: probe, now: now);
    await resolver.resolve(
      fingerprint: 'model',
      probe: probe,
      now: now.add(const Duration(days: 6)),
    );
    await resolver.resolve(
      fingerprint: 'model',
      probe: probe,
      now: now.add(const Duration(days: 8)),
    );

    expect(probes, 2);
  });
}

final class _MemoryStore implements AgentModelCapabilityStore {
  final values = <String, AgentModelCapabilities>{};

  @override
  Future<AgentModelCapabilities?> read(String fingerprint) async =>
      values[fingerprint];

  @override
  Future<void> write(
    String fingerprint,
    AgentModelCapabilities capabilities,
  ) async {
    values[fingerprint] = capabilities;
  }
}
