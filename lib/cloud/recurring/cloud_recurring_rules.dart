import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart';
import '../../providers.dart';

import 'recurring_handoff.dart';
export 'recurring_handoff.dart';

final cloudRecurringModeProvider = FutureProvider<bool>((ref) async {
  ref.watch(activeCloudConfigProvider);
  return ref.watch(cloudServiceStoreProvider).usesBeeCountCloud();
});

final cloudRuleBookProvider =
    FutureProvider.autoDispose.family<CloudRuleBook, int>((ref, id) async {
  final api = await ref.watch(beecountCloudProviderInstance.future);
  if (api == null) throw StateError('BeeCount Cloud');
  final ledger = await ref.watch(repositoryProvider).getLedgerById(id);
  final user = await api.auth.currentUser;
  if (ledger == null || user == null) {
    throw CloudNotAuthenticatedException('BeeCount Cloud');
  }
  final external = ledger.syncId ?? id.toString();
  final scope = ruleScope(api, user.id, external);
  final prefs = await SharedPreferences.getInstance();
  final key = 'recurring-cache.$scope';
  late final RuleJson response;
  try {
    response = await api.recurringRules(external);
    final refs = await api.fetchSharedResources(ledgerId: external);
    response['categories'] = [
      for (final c in refs.categories)
        {
          'id': c.syncId,
          'name': c.name,
          'kind': c.kind,
          'icon': c.icon,
          'parent_id': c.parentSyncId,
        }
    ];
    response['accounts'] = [
      for (final a in refs.accounts)
        {'id': a.syncId, 'name': a.name, 'currency': a.currency}
    ];
  } catch (error) {
    if (error is! SocketException &&
        error is! TimeoutException &&
        error is! ClientException &&
        !(error is RecurringRuleException &&
            {502, 503, 504}.contains(error.status))) {
      await prefs.remove(key);
      rethrow;
    }
    final cached = prefs.getString(key);
    if (cached == null) rethrow;
    return CloudRuleBook(
        api, ledger, scope, jsonDecode(cached) as RuleJson, true);
  }
  await prefs.setString(key, jsonEncode(response));
  return CloudRuleBook(api, ledger, scope, response, false);
});

final pendingRecurringProvider = StreamProvider.autoDispose
    .family<List<RecurringTransaction>, int>((ref, ledgerId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.recurringTransactions)
        ..where((r) => r.ledgerId.equals(ledgerId) & r.cloudRuleId.isNull()))
      .watch();
});
