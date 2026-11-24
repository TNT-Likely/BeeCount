import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:uuid/uuid.dart';

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../sync/change_tracker.dart';
import '../../services/data/recurring_transaction_service.dart';

typedef RuleJson = Map<String, dynamic>;

String ruleDate(DateTime date) => date.toIso8601String().substring(0, 10);

/// Cloud measures the rule title in Unicode code points. Keep the memo intact.
String recurringRuleTitle(String text) =>
    String.fromCharCodes(text.trim().runes.take(255)).trimRight();

String? recurringReference(RuleJson tx, String key) {
  final value = tx[key] as String?;
  if (value != null && value.isNotEmpty) return value;
  return switch (key) {
    'from_account_id' => tx['account_id'] as String?,
    'from_account' => tx['account'] as String?,
    _ => null,
  };
}

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
  String get name => config['name'] as String;
  String? get displayNote {
    final note = tx['note'] as String?;
    return note?.trim() == name.trim() ? null : note;
  }

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

  RuleJson? resource(RuleJson tx, String key, String group) {
    final id = recurringReference(tx, '${key}_id');
    final name = recurringReference(tx, key);
    if (id == null && name == null) return null;
    return options(group)
        .where((item) =>
            (group != 'categories' || item['kind'] == tx['tx_type']) &&
            (id == null ? item['name'] == name : item['id'] == id))
        .firstOrNull;
  }

  String? currencyFor(RuleJson tx) {
    final explicit = (tx['currency'] as String?)?.trim().toUpperCase();
    final transfer = tx['tx_type'] == 'transfer';
    if (!transfer && explicit != null && explicit.isNotEmpty) return explicit;
    final key = transfer ? 'from_account' : 'account';
    if (recurringReference(tx, '${key}_id') != null ||
        recurringReference(tx, key) != null) {
      final account = resource(tx, key, 'accounts');
      if (account == null) return null;
      return (account['currency'] as String? ?? ledger.currency).toUpperCase();
    }
    // A new transfer can select its currency before either account is chosen.
    return explicit == null || explicit.isEmpty
        ? ledger.currency.toUpperCase()
        : explicit;
  }

  String get draftKey => 'recurring-draft.$scope';

  Future<RuleJson> change(RuleJson payload) => _request(payload);
  Future<RuleJson> readCurrent() => _request(null);

  Future<void> ensureActive() async {
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
  }

  Future<RuleJson> _request(RuleJson? payload) async {
    await ensureActive();
    return api.recurringRules(ledgerKey, change: payload);
  }
}

String ruleScope(BeeCountCloudProvider api, String user, String ledger) =>
    sha256
        .convert(
            utf8.encode(jsonEncode([api.baseUrl, api.apiPrefix, user, ledger])))
        .toString();

/// Lock locally before the request; a lost response reuses the same server creation key.
Future<RecurringTransaction> freezeRecurring(
        BeeDatabase db, int id, String scope,
        {RecurringTransaction? expected, String? clientId}) =>
    db.transaction(() async {
      final query = db.select(db.recurringTransactions)
        ..where((r) => r.id.equals(id));
      final current = await query.getSingle();
      if (expected != null && current != expected) {
        throw StateError('REVISION_CONFLICT');
      }
      if (current.cloudHandoffKey != null &&
          current.cloudHandoffScope != scope) {
        throw StateError('Rule belongs to another Cloud session');
      }
      if (current.cloudHandoffKey != null) return current;
      await (db.update(db.recurringTransactions)..where((r) => r.id.equals(id)))
          .write(RecurringTransactionsCompanion(
              cloudHandoffScope: Value(scope),
              cloudHandoffKey: Value(clientId ?? const Uuid().v4())));
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
      final deleted =
          (reply['deleted_transactions'] as List? ?? const []).toSet();
      for (final entry in mappings.entries
          .where((e) => e.key != e.value || deleted.contains(e.key))) {
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
      // A second installation may still have its original unsent create.
      // Cloud already holds this exact transaction, including later edits.
      if (reply.containsKey('required_uploads')) {
        final required = (reply['required_uploads'] as List).toSet();
        final accepted = mappings.keys
            .where((sid) => mappings[sid] == sid && !required.contains(sid));
        for (final sid in accepted) {
          await (db.update(db.localChanges)
                ..where((c) =>
                    c.ledgerId.equals(frozen.ledgerId) &
                    c.entityType.equals('transaction') &
                    c.entitySyncId.equals(sid) &
                    c.action.equals('create') &
                    c.pushedAt.isNull()))
              .write(LocalChangesCompanion(pushedAt: Value(DateTime.now())));
        }
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
              cloudHandoffIssue: const Value(null),
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
    'name': recurringRuleTitle((rule.note?.trim().isNotEmpty ?? false)
        ? rule.note!
        : category?.name ?? account?.name ?? rule.type),
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
      'currency': account == null ? rule.currencyCode : null,
      'note': rule.note
    }
  };
}

/// A preview is tied to the exact local copy, server version and occurrence mapping.
class RecurringHandoff {
  const RecurringHandoff(
      this.book, this.local, this.transactions, this.request, this.preview);

  final CloudRuleBook book;
  final RecurringTransaction local;
  final List<Transaction> transactions;
  final RuleJson request, preview;

  Iterable<Transaction> get overlaps {
    final mappings = preview['local_transactions'] as Map;
    final deleted =
        (preview['deleted_transactions'] as List? ?? const []).toSet();
    return transactions.where((tx) =>
        mappings[tx.syncId] != tx.syncId || deleted.contains(tx.syncId));
  }

  static Future<RecurringHandoff> prepare(BeeDatabase db, BaseRepository repo,
      CloudRuleBook book, RecurringTransaction local,
      {CloudRule? target, bool automatic = false}) async {
    await book.ensureActive();
    final current = await (db.select(db.recurringTransactions)
          ..where((r) => r.id.equals(local.id)))
        .getSingle();
    if (current.cloudHandoffKey != null &&
        current.cloudHandoffScope != book.scope) {
      throw StateError('Rule belongs to another Cloud session');
    }
    final transactions = await localRuleTransactions(db, current);
    final next = RecurringTransactionService(repo).calculateNextDate(current);
    final consumed = current.lastGeneratedDate ??
        (next == null ? null : DateTime(next.year, next.month, next.day - 1));
    final request = <String, dynamic>{
      'action': 'create',
      'migrate': true,
      'automatic': automatic,
      'client_id': current.cloudHandoffKey ?? const Uuid().v4(),
      'consumed_through': consumed == null ? null : ruleDate(consumed),
      if (current.lastGeneratedDate != null)
        'last_generated_date': ruleDate(current.lastGeneratedDate!),
      'local_transactions': [
        for (final tx in transactions)
          {'sync_id': tx.syncId, 'date': ruleDate(tx.happenedAt)}
      ],
    };
    void link(CloudRule row) {
      request.addAll({
        'action': 'update',
        'record_id': row.id,
        'expected_revision': row.revision,
        'data': {...row.config, 'enabled': row.status != 'paused'}
      });
    }

    if (target != null) {
      link(target);
    } else {
      request['data'] = await legacyRuleConfig(repo, current, book.zone);
    }
    var preview = await book.change({...request, 'confirm': false});
    final matched = preview['matched_rule'];
    if (automatic && matched is RuleJson) {
      link(CloudRule(matched));
      preview = await book.change({...request, 'confirm': false});
    }
    return RecurringHandoff(book, current, transactions, request, preview);
  }

  Future<void> finish(BeeDatabase db, {bool distinct = false}) async {
    await book.ensureActive();
    // A preview cannot commit. Reserve its key only before sending confirmation.
    final frozen = await freezeRecurring(db, local.id, book.scope,
        expected: local, clientId: request['client_id'] as String);
    final result = preview['handoff_confirmed'] == true
        ? preview
        : await book.change({
            ...request,
            'confirm': true,
            'distinct': distinct,
            'reviewed_mapping': preview['reviewed_mapping'],
          });
    final reviewedDeleted =
        (preview['deleted_transactions'] as List? ?? const []).toSet();
    if ((result['deleted_transactions'] as List? ?? const [])
        .any((id) => !reviewedDeleted.contains(id))) {
      throw StateError('HISTORY_CONFLICT');
    }
    await book.ensureActive();
    await applyHandoffReceipt(db, frozen, result, 'HISTORY_CONFLICT');
  }
}
