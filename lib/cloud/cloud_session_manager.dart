import 'dart:async';
import 'dart:convert';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

typedef CloudServices = ({CloudProvider? provider, CloudAuthService? auth});
typedef CloudServicesFactory = Future<CloudServices> Function(
    CloudServiceConfig);

/// Owns one active configuration's services. The factory remains uncached.
class CloudSession {
  CloudSession(this.config, this.services);

  final CloudServiceConfig config;
  final CloudServices services;
  final Set<void Function()> _onClose = {};
  Future<void>? _closing;
  bool get isClosed => _closing != null;

  /// Consumers stop scheduling work before their network resources are released.
  void Function() onClose(void Function() callback) {
    if (isClosed) {
      callback();
    } else {
      _onClose.add(callback);
    }
    return () => _onClose.remove(callback);
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    final done = Completer<void>();
    _closing = done.future;
    Future<void>(() async {
      Object? firstError;
      StackTrace? firstStack;
      try {
        for (final callback in _onClose.toList()) {
          try {
            callback();
          } catch (error, stack) {
            firstError ??= error;
            firstStack ??= stack;
          }
        }
      } finally {
        _onClose.clear();
        await services.provider?.dispose();
      }
      if (firstError != null) {
        Error.throwWithStackTrace(firstError!, firstStack!);
      }
    }).then(done.complete, onError: done.completeError);
    return done.future;
  }
}

class CloudSessionManager {
  CloudSessionManager(
      {CloudServicesFactory factory = createCloudServices,
      CloudServicesFactory? temporaryFactory})
      : _factory = factory,
        _temporaryFactory = temporaryFactory ??
            ((config) => createCloudServices(config, persistSession: false));

  final CloudServicesFactory _factory;
  final CloudServicesFactory _temporaryFactory;
  CloudSession? _active;
  Future<void> _tail = Future.value();
  Future<CloudSession>? _pending;
  String? _requestedKey;
  int _generation = 0;
  bool _disposed = false;

  Future<CloudSession> activate(CloudServiceConfig config) {
    if (_disposed) return Future.error(StateError('Session manager closed'));
    // Includes credentials: editing credentials must replace the session too.
    // Never log this key, since configuration can contain passwords.
    final key = jsonEncode(config.toJson());
    if (_requestedKey == key && _pending != null) return _pending!;
    _requestedKey = key;
    final generation = ++_generation;
    final next = _tail.then((_) async {
      _checkGeneration(generation);
      final previous = _active;
      _active = null;
      await previous?.close();
      _checkGeneration(generation);
      final services = await _factory(config);
      final session = CloudSession(config, services);
      if (_disposed || generation != _generation) {
        await session.close();
        throw StateError('Cloud configuration changed during initialization');
      }
      // Backend-specific recovery belongs in session assembly, not UI providers.
      final auth = services.auth;
      if (auth is BeeCountCloudAuthService) {
        auth.setRecoveryCredentials(
          email: config.beecountCloudEmail,
          password: config.beecountCloudPassword,
        );
      }
      _active = session;
      return session;
    });
    _pending = next;
    _tail = next.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      if (generation == _generation) {
        _requestedKey = null;
        _pending = null;
      }
    });
    return next;
  }

  void _checkGeneration(int generation) {
    if (_disposed || generation != _generation) {
      throw StateError('Cloud configuration changed');
    }
  }

  /// Draft configurations never replace the active session. Always released.
  Future<T> withTemporarySession<T>(CloudServiceConfig config,
      Future<T> Function(CloudSession) action) async {
    if (_disposed) throw StateError('Session manager closed');
    final session = CloudSession(config, await _temporaryFactory(config));
    try {
      if (_disposed) throw StateError('Session manager closed');
      return await action(session);
    } finally {
      await session.close();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_generation;
    await _tail;
    final previous = _active;
    _active = null;
    await previous?.close();
  }
}
