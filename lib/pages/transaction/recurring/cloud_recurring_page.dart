import 'dart:async';
import 'dart:convert';

import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../cloud/recurring/cloud_recurring_rules.dart';
import '../../../cloud/sync/sync_engine.dart';
import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../shared/scaffold/widgets/page_scaffold.dart';
import '../../shared/selectors/ledger_selector_dialog.dart';
import 'cloud_rule_editor.dart';
import 'bindings/recurring_editor_controls.dart';
import '../../../services/data/recurring_transaction_service.dart';

class CloudRecurringPage extends ConsumerStatefulWidget {
  const CloudRecurringPage({super.key});
  @override
  ConsumerState<CloudRecurringPage> createState() => _CloudRecurringPageState();
}

class _CloudRecurringPageState extends ConsumerState<CloudRecurringPage>
    with WidgetsBindingObserver {
  int? selected;
  bool busy = false;
  late final Timer timer;
  int get ledgerId => selected ?? ref.read(currentLedgerIdProvider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!busy &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        refresh();
      }
    });
  }

  void refresh() => ref.invalidate(cloudRuleBookProvider(ledgerId));
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) refresh();
  }

  @override
  void dispose() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> edit(CloudRuleBook book,
      {CloudRule? row, RuleJson? draft}) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                CloudRuleEditor(book: book, row: row, draft: draft)));
    if (mounted) {
      refresh();
      setState(() {});
    }
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        showBeeToast(context, cloudRuleError(context, e), tone: BeeTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refresh();
      }
    }
  }

  Future<void> adopt(CloudRuleBook book, RecurringTransaction local) async {
    final l = AppLocalizations.of(context);
    final choice = await showBeeDialog<String>(context,
        title: l.cloudRecurringAdopt,
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.cloudRecurringLink),
          for (final row in book.rules.where((r) => r.canEdit))
            BeeMenuRow(
                title: '${row.config['name']} · ${row.tx['amount']}',
                onTap: () => Navigator.pop(context, row.id)),
          BeeMenuRow(
              title: l.cloudRecurringCreateSeparate,
              onTap: () => Navigator.pop(context, 'create')),
        ])));
    if (choice == null || !mounted) return;
    final db = ref.read(databaseProvider);
    final repo = ref.read(repositoryProvider);
    final sync = ref.read(syncServiceProvider);
    if (sync is! SyncEngine) throw StateError(l.cloudRecurringSyncFirst);
    final frozen = await freezeRecurring(db, local.id, book.scope);
    await sync.pushUserGlobalEntities();
    final transactions = await localRuleTransactions(db, frozen);
    final target = book.rules.where((r) => r.id == choice).firstOrNull;
    final nextLocal =
        RecurringTransactionService(repo).calculateNextDate(frozen);
    final consumed = frozen.lastGeneratedDate ??
        (nextLocal == null
            ? null
            : DateTime(nextLocal.year, nextLocal.month, nextLocal.day - 1));
    final change = <String, dynamic>{
      'action': target == null ? 'create' : 'update',
      'client_id': frozen.cloudHandoffKey,
      'local_transactions': [
        for (final tx in transactions)
          {'sync_id': tx.syncId, 'date': ruleDate(tx.happenedAt)}
      ],
      if (target != null) ...{
        'record_id': target.id,
        'expected_revision': target.revision
      },
      'data': target == null
          ? await legacyRuleConfig(repo, frozen, book.zone)
          : {...target.config, 'enabled': target.status != 'paused'},
      'migrate': true,
      'consumed_through': consumed == null ? null : ruleDate(consumed),
    };
    final preview = await book.change({...change, 'confirm': false});
    if (preview['handoff_confirmed'] == true) {
      await applyHandoffReceipt(
          db, frozen, preview, l.cloudRecurringManualReview);
      await sync.uploadCurrentLedger(ledgerId: local.ledgerId);
      await sync.pull(local.ledgerId.toString());
      return;
    }
    change['reviewed_mapping'] = preview['reviewed_mapping'];
    final mappings =
        Map<String, dynamic>.from(preview['local_transactions'] as Map);
    final overlaps =
        transactions.where((tx) => mappings[tx.syncId] != tx.syncId);
    if (!mounted) return;
    final dates =
        (preview['next_occurrences'] as List? ?? []).take(3).join('\n');
    if (await showBeeConfirm(context,
            title: l.cloudRecurringAdopt,
            message: [
              l.cloudRecurringConfirm,
              dates,
              if (overlaps.isNotEmpty) l.cloudRecurringKeepCloud,
              for (final tx in overlaps)
                '${ruleDate(tx.happenedAt)} · ${tx.amount}'
            ].join('\n'),
            confirmLabel: l.commonOk,
            cancelLabel: l.commonCancel) !=
        true) {
      return;
    }
    RuleJson result;
    try {
      result = await book.change({...change, 'confirm': true});
    } on RecurringRuleException catch (e) {
      if (!e.message.contains('SIMILAR_RULE') || !mounted) rethrow;
      if (await showBeeConfirm(context,
              title: l.cloudRecurringDistinct,
              message: l.cloudRecurringLink,
              confirmLabel: l.cloudRecurringCreateSeparate,
              cancelLabel: l.commonCancel) !=
          true) {
        return;
      }
      result =
          await book.change({...change, 'confirm': true, 'distinct': true});
    }
    await applyHandoffReceipt(db, frozen, result, l.cloudRecurringManualReview);
    await sync.uploadCurrentLedger(ledgerId: local.ledgerId);
    await sync.pull(local.ledgerId.toString());
  }

  Future<List<RuleJson>> storedDrafts(CloudRuleBook book) async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final key
          in prefs.getKeys().where((k) => k.startsWith('${book.draftKey}.')))
        jsonDecode(prefs.getString(key)!) as RuleJson
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final int id = selected ?? ref.watch(currentLedgerIdProvider);
    final data = ref.watch(cloudRuleBookProvider(id));
    final old = ref.watch(pendingRecurringProvider(id)).valueOrNull ?? [];
    final book = data.valueOrNull;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.recurringTransactionTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.ledgerSelectTitle,
                icon: const BeeLineIcon('BookOpen'),
                onPressed: busy
                    ? null
                    : () async {
                        final next = await showLedgerSelector(context,
                            currentLedgerId: id);
                        if (mounted && next != null) {
                          setState(() => selected = next);
                        }
                      }),
            BeeIconButton(
                label: l.recurringTransactionAdd,
                icon: const BeeLineIcon('Plus'),
                onPressed: book != null && book.canCreate && !busy
                    ? () => edit(book)
                    : null),
          ]),
      Expanded(
          child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => BeeEmptyState(
                  title: cloudRuleError(context, e),
                  action:
                      BeeButton(label: l.v4RecordingRetry, onPressed: refresh)),
              data: (book) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(cloudRuleBookProvider(id));
                    await ref.read(cloudRuleBookProvider(id).future);
                  },
                  child: ListView(
                      padding: const EdgeInsets.all(17),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        BeeRecurringUsageNotice(
                            title: book.ledger.name,
                            description: book.offline
                                ? l.cloudRecurringCached
                                : book.schedulerEnabled
                                    ? l.cloudRecurringOwner
                                    : l.cloudRecurringPausedService),
                        FutureBuilder<List<RuleJson>>(
                            future: storedDrafts(book),
                            builder: (_, s) => Column(children: [
                                  for (final draft in s.data ?? <RuleJson>[])
                                    ListTile(
                                        title: Text(l.cloudRecurringDraft),
                                        subtitle: Text(
                                            draft['data']['name'].toString()),
                                        trailing: IconButton(
                                            icon: const Icon(Icons.close),
                                            tooltip: l.commonRemove,
                                            onPressed: () async {
                                              final prefs =
                                                  await SharedPreferences
                                                      .getInstance();
                                              await prefs.remove(
                                                  '${book.draftKey}.${draft['record_id'] ?? draft['client_id']}');
                                              if (mounted) setState(() {});
                                            }),
                                        onTap: () => edit(book,
                                            draft: draft,
                                            row: book.rules
                                                .where((r) =>
                                                    r.id == draft['record_id'])
                                                .firstOrNull)),
                                ])),
                        if (old.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(l.cloudRecurringPending)),
                        for (final local in old)
                          ListTile(
                              title: Text(local.note ??
                                  '${local.amount} · ${local.type}'),
                              subtitle: Text(
                                  '${local.amount} · ${ruleDate(local.startDate)}'),
                              trailing: TextButton(
                                  onPressed:
                                      busy || book.offline || !book.canCreate
                                          ? null
                                          : () => run(() => adopt(book, local)),
                                  child: Text(l.cloudRecurringAdopt))),
                        if (book.rules.isEmpty && old.isEmpty)
                          BeeEmptyState(
                              title: l.recurringTransactionEmpty,
                              action: book.canCreate
                                  ? BeeButton(
                                      label: l.recurringTransactionAdd,
                                      onPressed: () => edit(book))
                                  : null),
                        for (final row in book.rules)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: BeeRecurringBillCard(
                                  title: row.config['name'] as String,
                                  ledger: book.ledger.name,
                                  frequency: recurringEditorIntervalLabel(
                                      l,
                                      RecurringFrequency.fromString(
                                          row.config['frequency'] as String),
                                      row.config['interval'] as int),
                                  icon: const BeeLineIcon('Repeat2'),
                                  amount: Text(
                                      '${row.tx['amount']} ${row.tx['currency'] ?? book.ledger.currency}'),
                                  note: row.tx['note'] as String?,
                                  enabled: row.status == 'active' ||
                                      row.status == 'executing',
                                  toggleLabel: l.recurringTransactionTitle,
                                  busy: busy || !row.canEdit || book.offline,
                                  nextRunCaption: l.cloudRecurringOwner,
                                  nextRunLabel: row.status == 'paused'
                                      ? l.v4RecurringStatusPaused
                                      : row.next?.substring(0, 10) ??
                                          l.v4RecurringStatusCompleted,
                                  onOpen: row.canEdit
                                      ? () => edit(book, row: row)
                                      : null,
                                  onToggle: !row.canEdit ||
                                          book.offline ||
                                          row.status == 'completed'
                                      ? null
                                      : (v) => run(() async {
                                            await book.change({
                                              'action': v ? 'resume' : 'pause',
                                              'record_id': row.id,
                                              'expected_revision': row.revision,
                                              'confirm': true
                                            });
                                          }))),
                      ]))))
    ]));
  }
}

String cloudRuleError(BuildContext context, Object error) {
  final l = AppLocalizations.of(context);
  if (error is RecurringRuleException) {
    if (error.status == 409) return l.cloudRecurringConflict;
    if (error.status == 404) return l.cloudRecurringUpgrade;
  }
  return '${l.commonError}: $error';
}
