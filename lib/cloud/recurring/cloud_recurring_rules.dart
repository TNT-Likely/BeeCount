import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/db.dart';
import '../sync/change_tracker.dart';
import '../../data/repositories/base_repository.dart';
import '../../providers.dart';

typedef RuleJson = Map<String, dynamic>;

String ruleDate(DateTime date) => date.toIso8601String().substring(0, 10);

final cloudRecurringModeProvider = FutureProvider<bool>((ref) async {
  ref.watch(activeCloudConfigProvider);
  return ref.watch(cloudServiceStoreProvider).usesBeeCountCloud();
});

/// Cloud rules are never inserted into the executable local template collection.
class CloudRule {
  CloudRule(this.json);
  final RuleJson json;
  String get id => json['id'] as String;
  int get revision => json['revision'] as int;
  String get status => json['status'] as String;
  bool get canEdit => json['can_edit'] == true && status != 'executing';
  RuleJson get data => json['data'] as RuleJson;
  RuleJson get config => data['rule'] as RuleJson;
  RuleJson get tx => config['transaction'] as RuleJson;
  String? get next =>
      json['next_local'] as String? ?? json['next_due_at'] as String?;
}

class CloudRuleBook {
  CloudRuleBook(this.api, this.ledger, this.scope, this.snapshot, this.offline);
  final BeeCountCloudProvider api;
  final Ledger ledger;
  final String scope;
  final RuleJson snapshot;
  final bool offline;
  String get ledgerKey => ledger.syncId ?? ledger.id.toString();
  String get zone => snapshot['time_zone'] as String;
  bool get canCreate => snapshot['can_create'] == true;
  bool get schedulerEnabled => snapshot['scheduler_enabled'] == true;
  List<CloudRule> get rules =>
      (snapshot['items'] as List).cast<RuleJson>().map(CloudRule.new).toList();
  List<RuleJson> options(String key) =>
      (snapshot[key] as List).cast<RuleJson>();

  String get draftKey => 'recurring-draft.$scope';

  Future<RuleJson> change(RuleJson payload) => _request(payload);
  Future<RuleJson> readCurrent() => _request(null);

  Future<RuleJson> _request(RuleJson? payload) async {
    // Do not submit an old open editor after changing provider, instance or user.
    if (!await CloudServiceStore().usesBeeCountCloud()) {
      throw StateError('Cloud is disconnected');
    }
    final active = await CloudServiceStore().loadActive();
    final session = await api.auth.currentUser;
    final email = active.beecountCloudEmail?.trim().toLowerCase();
    final prefix = (active.beecountCloudApiPrefix ?? '/api/v1')
        .split('/')
        .where((part) => part.isNotEmpty)
        .join('/');

    if (session == null ||
        (email != null &&
            email.isNotEmpty &&
            session.email?.toLowerCase() != email) ||
        '/$prefix' != api.apiPrefix ||
        active.beecountCloudBaseUrl?.trim().replaceAll(RegExp(r'/+$'), '') !=
            api.baseUrl?.trim().replaceAll(RegExp(r'/+$'), '') ||
        scope != ruleScope(api, session.id, ledgerKey)) {
      throw StateError('Cloud session changed');
    }
    return api.recurringRules(ledgerKey, change: payload);
  }
}

String ruleScope(BeeCountCloudProvider api, String user, String ledger) =>
    sha256
        .convert(
            utf8.encode(jsonEncode([api.baseUrl, api.apiPrefix, user, ledger])))
        .toString();

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
        {'id': c.syncId, 'name': c.name, 'kind': c.kind}
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

/// Lock locally before the request; a lost response reuses the same server creation key.
Future<RecurringTransaction> freezeRecurring(
        BeeDatabase db, int id, String scope) =>
    db.transaction(() async {
      final query = db.select(db.recurringTransactions)
        ..where((r) => r.id.equals(id));
      final current = await query.getSingle();
      if (current.cloudHandoffScope != null &&
          current.cloudHandoffScope != scope) {
        throw StateError('Rule belongs to another Cloud session');
      }
      if (current.cloudHandoffKey != null) return current;
      await (db.update(db.recurringTransactions)..where((r) => r.id.equals(id)))
          .write(RecurringTransactionsCompanion(
              cloudHandoffScope: Value(scope),
              cloudHandoffKey: Value(const Uuid().v4())));
      return query.getSingle();
    });

Future<List<Transaction>> localRuleTransactions(
        BeeDatabase db, RecurringTransaction rule) =>
    db.transaction(() async {
      final query = db.select(db.transactions)
        ..where((t) =>
            t.ledgerId.equals(rule.ledgerId) & t.recurringId.equals(rule.id));
      final rows = await query.get();
      for (final tx in rows.where((t) => t.syncId == null)) {
        final sid = const Uuid().v4();
        await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
            .write(TransactionsCompanion(syncId: Value(sid)));
        await ChangeTracker(db).recordLedgerChange(
            ledgerId: tx.ledgerId,
            entityType: 'transaction',
            entityId: tx.id,
            entitySyncId: sid,
            action: 'create');
      }
      return query.get();
    });

/// Apply a committed server receipt and retire only the reviewed local copies.
/// Tagged/annotated copies require manual reconciliation to preserve local edits.
Future<void> applyHandoffReceipt(BeeDatabase db, RecurringTransaction frozen,
        RuleJson reply, String reviewMessage) =>
    db.transaction(() async {
      if (reply['handoff_confirmed'] != true) {
        throw StateError('Missing Cloud receipt');
      }
      final mappings =
          Map<String, dynamic>.from(reply['local_transactions'] as Map);
      for (final entry in mappings.entries.where((e) => e.key != e.value)) {
        final row = await (db.select(db.transactions)
              ..where((t) =>
                  t.recurringId.equals(frozen.id) & t.syncId.equals(entry.key)))
            .getSingleOrNull();
        if (row == null) continue;
        final annotated = await (db.select(db.transactionAttachments)
              ..where((a) => a.transactionId.equals(row.id)))
            .get();
        final tags = await (db.select(db.transactionTags)
              ..where((a) => a.transactionId.equals(row.id)))
            .get();
        final edits = await (db.select(db.localChanges)
              ..where((c) =>
                  c.entityType.equals('transaction') &
                  c.entitySyncId.equals(entry.key) &
                  c.action.equals('update')))
            .get();
        if (annotated.isNotEmpty || tags.isNotEmpty || edits.isNotEmpty) {
          throw StateError(reviewMessage);
        }
        await (db.delete(db.localChanges)
              ..where((c) =>
                  c.entityType.equals('transaction') &
                  c.ledgerId.equals(frozen.ledgerId) &
                  c.entitySyncId.equals(entry.key)))
            .go();
        await (db.delete(db.transactions)..where((t) => t.id.equals(row.id)))
            .go();
      }
      for (final sid
          in (reply['required_uploads'] as List? ?? const []).cast<String>()) {
        final tx = await (db.select(db.transactions)
              ..where((t) =>
                  t.recurringId.equals(frozen.id) & t.syncId.equals(sid)))
            .getSingleOrNull();
        if (tx == null) continue;
        final pending = await (db.select(db.localChanges)
              ..where((c) =>
                  c.entityType.equals('transaction') &
                  c.entitySyncId.equals(sid) &
                  c.pushedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
        if (pending == null) {
          await ChangeTracker(db).recordLedgerChange(
              ledgerId: tx.ledgerId,
              entityType: 'transaction',
              entityId: tx.id,
              entitySyncId: sid,
              action: 'create');
        }
      }
      await (db.update(db.recurringTransactions)
            ..where((r) =>
                r.id.equals(frozen.id) &
                r.cloudHandoffKey.equals(frozen.cloudHandoffKey!)))
          .write(RecurringTransactionsCompanion(
              cloudRuleId: Value(reply['id'] as String),
              enabled: const Value(false)));
    });

Future<RuleJson> legacyRuleConfig(
    BaseRepository repo, RecurringTransaction rule, String zone) async {
  final category = rule.categoryId == null
      ? null
      : await repo.getCategoryById(rule.categoryId!);
  final account =
      rule.accountId == null ? null : await repo.getAccount(rule.accountId!);
  final target = rule.toAccountId == null
      ? null
      : await repo.getAccount(rule.toAccountId!);
  if ((rule.categoryId != null && category?.syncId == null) ||
      (rule.accountId != null && account?.syncId == null) ||
      (rule.toAccountId != null && target?.syncId == null)) {
    throw StateError('Sync the linked categories and accounts first');
  }
  return {
    'name': (rule.note?.trim().isNotEmpty ?? false)
        ? rule.note
        : category?.name ?? account?.name ?? rule.type,
    'frequency': rule.frequency,
    'interval': rule.interval,
    'starts_at': ruleDate(rule.startDate),
    'ends_at': rule.endDate == null ? null : ruleDate(rule.endDate!),
    'time_zone': zone,
    'day_of_month': rule.frequency == 'monthly' ||
            (rule.frequency == 'yearly' && rule.monthOfYear != null)
        ? rule.dayOfMonth
        : null,
    'day_of_week': rule.dayOfWeek,
    'month_of_year': rule.monthOfYear,
    'enabled': rule.enabled,
    'transaction': {
      'tx_type': rule.type,
      'amount': rule.amount,
      'category_id': category?.syncId,
      if (rule.type == 'transfer') ...{
        'from_account_id': account?.syncId,
        'to_account_id': target?.syncId
      } else
        'account_id': account?.syncId,
      'currency': rule.currencyCode,
      'note': rule.note
    }
  };
}
