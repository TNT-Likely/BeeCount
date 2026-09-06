import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_tool_permission.dart';

final class SharedPreferencesAgentToolPermissionStore
    implements AgentToolPermissionStore {
  SharedPreferencesAgentToolPermissionStore({
    required Future<SharedPreferences> Function() getPreferences,
  }) : _getPreferences = getPreferences;

  static const String key = 'agent_tool_permissions_v1';
  static const int _version = 1;
  static final _states = Expando<_PermissionPersistenceState>();
  final Future<SharedPreferences> Function() _getPreferences;

  @override
  Future<AgentToolPermission?> permissionFor(String toolName) async {
    final descriptor = AgentToolPermissionCatalog.find(toolName);
    if (descriptor == null) return null;
    final stored = await _readStored();
    return stored[toolName] ?? descriptor.defaultPermission;
  }

  @override
  Future<Map<String, AgentToolPermission>> readAll() async {
    final stored = await _readStored();
    final result = <String, AgentToolPermission>{};
    for (final descriptor in AgentToolPermissionCatalog.descriptors) {
      result[descriptor.toolName] =
          stored[descriptor.toolName] ?? descriptor.defaultPermission;
    }
    return Map.unmodifiable(result);
  }

  @override
  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  ) async {
    if (AgentToolPermissionCatalog.find(toolName) == null) {
      throw ArgumentError.value(toolName, 'toolName', 'Unknown agent tool');
    }
    await _withState((prefs, state) async {
      // An uncertain plugin cache must never enter the next successful write.
      final stored = _decodeStored(state.trustedRaw);
      stored[toolName] = permission;
      await _write(
          prefs,
          state,
          jsonEncode({
            'version': _version,
            'tools': stored.map((name, value) => MapEntry(name, value.name)),
          }));
    });
  }

  @override
  Future<void> restoreDefaults() async {
    await _withState((prefs, state) => _write(prefs, state, null));
  }

  Future<Map<String, AgentToolPermission>> _readStored() =>
      _withState((prefs, state) async =>
          state.uncertain ? {} : _decodeStored(state.trustedRaw));

  Future<T> _withState<T>(
    Future<T> Function(
            SharedPreferences prefs, _PermissionPersistenceState state)
        action,
  ) async {
    final prefs = await _getPreferences();
    final state = _states[prefs] ??= _PermissionPersistenceState();
    // Serialize across Store instances sharing this preferences object. This
    // also prevents a reader from trusting an in-flight optimistic cache update.
    final previous = state.pending;
    final finished = Completer<void>();
    state.pending = finished.future;
    await previous;
    try {
      if (!state.initialized) {
        await prefs.reload();
        state.trustedRaw = prefs.getString(key);
        state.initialized = true;
      }
      return await action(prefs, state);
    } finally {
      finished.complete();
    }
  }

  Future<void> _write(SharedPreferences prefs,
      _PermissionPersistenceState state, String? raw) async {
    try {
      final persisted = raw == null
          ? await prefs.remove(key)
          : await prefs.setString(key, raw);
      if (!persisted) throw StateError('工具授权偏好保存失败。');
      state.trustedRaw = raw;
      state.uncertain = false;
    } on Object {
      // Windows getAll/reload can return cache values from a failed disk write.
      // Keep the safety lock even if this best-effort rollback reports success.
      state.uncertain = true;
      try {
        final previous = state.trustedRaw;
        if (previous == null) {
          await prefs.remove(key);
        } else {
          await prefs.setString(key, previous);
        }
      } on Object {
        // Preserve the original failure; rollback cannot establish new trust.
      }
      rethrow;
    }
  }

  Map<String, AgentToolPermission> _decodeStored(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['version'] != _version) return {};
      final tools = decoded['tools'];
      if (tools is! Map) return {};
      final result = <String, AgentToolPermission>{};
      for (final entry in tools.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final descriptor = AgentToolPermissionCatalog.find(entry.key as String);
        if (descriptor == null) continue;
        final permission = _permissionFromName(entry.value as String);
        if (permission != null) result[entry.key as String] = permission;
      }
      return result;
    } on Object {
      return {};
    }
  }

  AgentToolPermission? _permissionFromName(String name) {
    for (final permission in AgentToolPermission.values) {
      if (permission.name == name) return permission;
    }
    return null;
  }
}

final class _PermissionPersistenceState {
  bool initialized = false;
  bool uncertain = false;
  String? trustedRaw;
  Future<void> pending = Future.value();
}
