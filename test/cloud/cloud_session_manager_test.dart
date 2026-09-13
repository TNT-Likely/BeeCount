import 'dart:async';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/cloud/cloud_session_manager.dart';

import 'sync/_fakes/fake_beecount_cloud_provider.dart';

const configA = CloudServiceConfig(
    type: CloudBackendType.beecountCloud,
    name: 'A',
    beecountCloudBaseUrl: 'https://a.example');
const configB = CloudServiceConfig(
    type: CloudBackendType.beecountCloud,
    name: 'B',
    beecountCloudBaseUrl: 'https://b.example');

class TrackedProvider extends FakeBeeCountCloudProvider {
  int closed = 0;
  @override
  Future<void> dispose() async {
    closed++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('concurrent consumers and equal reloaded configurations share services',
      () async {
    var creates = 0;
    final provider = TrackedProvider();
    final manager = CloudSessionManager(factory: (_) async {
      creates++;
      return (provider: provider, auth: provider.auth);
    });
    final sessions = await Future.wait([
      manager.activate(configA),
      manager.activate(configA),
      manager.activate(CloudServiceConfig.fromJson(configA.toJson())),
    ]);
    expect(creates, 1);
    expect(sessions.every((s) => identical(s, sessions.first)), isTrue);
    await manager.dispose();
    await manager.dispose();
    expect(provider.closed, 1);
  });

  test(
      'switch stops consumers and releases old services before creating new ones',
      () async {
    final events = <String>[];
    final first = TrackedProvider();
    final second = TrackedProvider();
    final manager = CloudSessionManager(factory: (cfg) async {
      if (cfg == configB) {
        expect(first.closed, 1);
        expect(events, ['stop engine']);
      }
      final p = cfg == configA ? first : second;
      return (provider: p, auth: p.auth);
    });
    final old = await manager.activate(configA);
    old.onClose(() => events.add('stop engine'));
    await manager.activate(configB);
    expect(old.isClosed, isTrue);
    await manager.dispose();
    expect(second.closed, 1);
  });

  test(
      'late initialization from superseded config is disposed, never published',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final first = TrackedProvider();
    final second = TrackedProvider();
    final manager = CloudSessionManager(factory: (cfg) async {
      if (cfg == configA) {
        started.complete();
        await release.future;
      }
      final p = cfg == configA ? first : second;
      return (provider: p, auth: p.auth);
    });
    final obsolete = manager.activate(configA);
    final rejected = expectLater(obsolete, throwsStateError);
    await started.future;
    final current = manager.activate(configB);
    release.complete();
    await rejected;
    expect((await current).services.provider, second);
    expect(first.closed, 1);
    await manager.dispose();
  });

  test('failed initialization can retry the same configuration', () async {
    var attempts = 0;
    final p = TrackedProvider();
    final manager = CloudSessionManager(factory: (_) async {
      if (++attempts == 1) throw StateError('offline');
      return (provider: p, auth: p.auth);
    });
    await expectLater(manager.activate(configA), throwsStateError);
    expect((await manager.activate(configA)).services.provider, p);
    await manager.dispose();
  });

  test('a failing close listener does not skip remaining cleanup', () async {
    final provider = TrackedProvider();
    final session = CloudSession(configA,
        (provider: provider, auth: provider.auth));
    var stopped = false;
    session.onClose(() => throw StateError('listener failed'));
    session.onClose(() => stopped = true);
    await expectLater(session.close(), throwsStateError);
    expect(stopped, isTrue);
    expect(provider.closed, 1);
  });

  test('shutdown during creation disposes late services', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final p = TrackedProvider();
    final manager = CloudSessionManager(factory: (_) async {
      started.complete();
      await release.future;
      return (provider: p, auth: p.auth);
    });
    final pending = expectLater(manager.activate(configA), throwsStateError);
    await started.future;
    final closing = manager.dispose();
    release.complete();
    await pending;
    await closing;
    expect(p.closed, 1);
  });

  test('temporary failure releases draft without replacing active services',
      () async {
    final p = TrackedProvider();
    final draft = TrackedProvider();
    final manager = CloudSessionManager(
      factory: (_) async => (provider: p, auth: p.auth),
      temporaryFactory: (_) async => (provider: draft, auth: draft.auth),
    );
    final active = await manager.activate(configA);
    await expectLater(
        manager.withTemporarySession<void>(configB, (_) async {
          throw StateError('test failed');
        }),
        throwsStateError);
    expect(draft.closed, 1);
    expect(p.closed, 0);
    expect(await manager.activate(configA), same(active));
    await manager.dispose();
  });
}
