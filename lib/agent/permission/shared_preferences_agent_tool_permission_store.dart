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
    final prefs = await _getPreferences();
    final stored = await _readStored(prefs);
    stored[toolName] = permission;
    final persisted = await prefs.setString(
        key,
        jsonEncode({
          'version': _version,
          'tools': stored.map((name, value) => MapEntry(name, value.name)),
        }));
    if (!persisted) throw StateError('工具授权偏好保存失败。');
  }

  @override
  Future<void> restoreDefaults() async {
    final prefs = await _getPreferences();
    await prefs.remove(key);
  }

  Future<Map<String, AgentToolPermission>> _readStored([
    SharedPreferences? preferences,
  ]) async {
    final prefs = preferences ?? await _getPreferences();
    // setString updates the plugin cache before its platform write completes.
    // Only persisted preferences may authorize later calls, even after a failed
    // write or when another store instance shares the same optimistic cache.
    await prefs.reload();
    final raw = prefs.getString(key);
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
