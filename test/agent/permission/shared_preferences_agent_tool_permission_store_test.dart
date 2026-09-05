import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Retain the real SharedPreferences cache while rejecting its platform write.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:beecount/agent/permission/agent_tool_permission.dart';
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  SharedPreferencesAgentToolPermissionStore createStore() =>
      SharedPreferencesAgentToolPermissionStore(
        getPreferences: SharedPreferences.getInstance,
      );

  test('returns catalog defaults when no local preference exists', () async {
    final store = createStore();

    expect(
      await store.permissionFor('record_transaction_from_text'),
      AgentToolPermission.ask,
    );
    expect(
      await store.permissionFor('query_transactions'),
      AgentToolPermission.alwaysAllow,
    );
    expect(
      await store.permissionFor('get_spending_summary'),
      AgentToolPermission.alwaysAllow,
    );
    expect(
      await store.permissionFor('get_budget_status'),
      AgentToolPermission.alwaysAllow,
    );
  });

  test('false platform result fails without granting a cached permission',
      () async {
    SharedPreferencesStorePlatform.instance = _RejectingPreferencesPlatform();
    final store = createStore();
    await expectLater(
      store.setPermission(
          'record_transaction_from_text', AgentToolPermission.alwaysAllow),
      throwsStateError,
    );
    expect(await store.permissionFor('record_transaction_from_text'),
        AgentToolPermission.ask);
    expect(await createStore().permissionFor('record_transaction_from_text'),
        AgentToolPermission.ask);
  });

  test('never returns an inherited permission for an unknown tool', () async {
    final store = createStore();
    expect(await store.permissionFor('delete_everything'), isNull);
  });

  test('persists an explicit permission and restores catalog defaults',
      () async {
    final store = createStore();
    await store.setPermission(
      'record_transaction_from_text',
      AgentToolPermission.alwaysAllow,
    );
    final rebuilt = createStore();
    expect(
      await rebuilt.permissionFor('record_transaction_from_text'),
      AgentToolPermission.alwaysAllow,
    );

    await rebuilt.restoreDefaults();
    expect(
      await createStore().permissionFor('record_transaction_from_text'),
      AgentToolPermission.ask,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('agent_tool_permissions_v1'), isFalse);
  });

  test('rejects unknown tools without persisting them', () async {
    final store = createStore();
    expect(
      () => store.setPermission('delete_everything', AgentToolPermission.ask),
      throwsArgumentError,
    );
    expect(
        (await SharedPreferences.getInstance())
            .containsKey('agent_tool_permissions_v1'),
        isFalse);
  });

  test('ignores malformed JSON and invalid entries', () async {
    SharedPreferences.setMockInitialValues({
      'agent_tool_permissions_v1': jsonEncode({
        'version': 1,
        'tools': {
          'record_transaction_from_text': 'invalid',
          'query_transactions': 'alwaysAllow',
          'unknown_tool': 'ask',
        },
      }),
    });
    final store = createStore();
    expect(
      await store.permissionFor('record_transaction_from_text'),
      AgentToolPermission.ask,
    );
    expect(
      await store.permissionFor('query_transactions'),
      AgentToolPermission.alwaysAllow,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agent_tool_permissions_v1', '{not-json');
    expect(
      await createStore().permissionFor('record_transaction_from_text'),
      AgentToolPermission.ask,
    );
  });

  test('readAll contains only catalog tools and stored enum values', () async {
    final store = createStore();
    await store.setPermission(
        'save_explicit_memory', AgentToolPermission.alwaysAllow);
    final all = await store.readAll();
    expect(
        all.keys,
        containsAll(<String>[
          'query_transactions',
          'get_spending_summary',
          'get_budget_status',
          'record_transaction_from_text',
          'save_explicit_memory',
          'forget_memory',
        ]));
    expect(all.length, 6);
    expect(all['save_explicit_memory'], AgentToolPermission.alwaysAllow);
  });
}

final class _RejectingPreferencesPlatform
    extends InMemorySharedPreferencesStore {
  _RejectingPreferencesPlatform() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}
