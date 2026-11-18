import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/db.dart';
import '../../../../l10n/app_localizations.dart';
import '../../recurring_transaction_edit_page.dart';
import '../../../../providers.dart';
import '../../../../services/billing/post_processor.dart';
import '../../../../services/data/recurring_transaction_service.dart';
import '../../../../styles/tokens.dart';
import '../../../../utils/category_utils.dart';
import '../../../shared/formatting/amount_text.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';
import '../../../shared/resources/bindings/recording_category_icon.dart';

final _recurringAccountsProvider = StreamProvider.autoDispose<List<Account>>(
  (ref) => ref.watch(repositoryProvider).watchAllAccounts(),
);

/// Keeps the original all-ledger stream and write/navigation contracts.
class RecurringBillsControls extends ConsumerStatefulWidget {
  const RecurringBillsControls({super.key});
  @override
  ConsumerState<RecurringBillsControls> createState() =>
      _RecurringBillsControlsState();
}

class _RecurringBillsControlsState
    extends ConsumerState<RecurringBillsControls> {
  final pending = <int>{};

  Future<void> openEditor([RecurringTransaction? recurring]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => RecurringTransactionEditPage(recurring: recurring)));
    if (mounted && changed == true) {
      ref.invalidate(allRecurringTransactionsProvider);
    }
  }

  Future<void> toggle(RecurringTransaction recurring, bool enabled) async {
    if (pending.contains(recurring.id)) return;
    final repo = ref.read(repositoryProvider);
    setState(() => pending.add(recurring.id));
    try {
      await repo.toggleRecurringTransaction(recurring.id, enabled);
      if (enabled) {
        final generatedLedgers =
            await RecurringTransactionService.generatePendingTransactionsStatic(
          repository: repo,
          rescanIfBusy: true,
        );
        if (mounted) {
          for (final ledgerId in generatedLedgers) {
            await PostProcessor.run(ref, ledgerId: ledgerId);
          }
        }
      }
      // Preserve the original grace period for a realtime repository update.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) ref.invalidate(allRecurringTransactionsProvider);
    } catch (error) {
      debugPrint('周期账单切换失败: $error');
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonFailed,
            tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => pending.remove(recurring.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(allRecurringTransactionsProvider);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.recurringTransactionTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.recurringTransactionAdd,
                icon: const BeeLineIcon('Plus'),
                onPressed: openEditor)
          ]),
      Expanded(
          child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => BeeEmptyState(
                  title: '${l.commonError}: $error',
                  icon: const BeeLineIcon('CircleAlert', size: 36),
                  action: BeeButton(
                      label: l.v4RecordingRetry,
                      onPressed: () =>
                          ref.invalidate(allRecurringTransactionsProvider))),
              data: (records) => records.isEmpty
                  ? BeeEmptyState(
                      title: l.recurringTransactionEmpty,
                      message: l.recurringTransactionEmptyHint,
                      icon: const BeeLineIcon('Repeat2', size: 40),
                      action: BeeButton(
                          label: l.recurringTransactionAdd,
                          onPressed: openEditor))
                  : ListView.separated(
                      padding: const EdgeInsets.all(17),
                      itemCount: records.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        if (index == 0) {
                          return BeeRecurringUsageNotice(
                              title: l.recurringTransactionUsageTitle,
                              description: l.v4RecurringUsageSummary);
                        }
                        final record = records[index - 1];
                        return RecurringBillBinding(
                            key: ValueKey('recurring-rule-${record.id}'),
                            recurring: record,
                            busy: pending.contains(record.id),
                            onOpen: () => openEditor(record),
                            onToggle: (value) => toggle(record, value));
                      })))
    ]));
  }
}

String recurringFrequencyLabel(
    AppLocalizations l, RecurringTransaction recurring) {
  final frequency = RecurringFrequency.fromString(recurring.frequency);
  if (recurring.interval == 1) {
    return switch (frequency) {
      RecurringFrequency.daily => l.recurringTransactionDaily,
      RecurringFrequency.weekly => l.recurringTransactionWeekly,
      RecurringFrequency.monthly => l.recurringTransactionMonthly,
      RecurringFrequency.yearly => l.recurringTransactionYearly,
    };
  }
  return switch (frequency) {
    RecurringFrequency.daily =>
      l.recurringTransactionEveryNDays(recurring.interval),
    RecurringFrequency.weekly =>
      l.recurringTransactionEveryNWeeks(recurring.interval),
    RecurringFrequency.monthly =>
      l.recurringTransactionEveryNMonths(recurring.interval),
    RecurringFrequency.yearly =>
      l.recurringTransactionEveryNYears(recurring.interval),
  };
}

String recurringScheduleLabel(
  AppLocalizations l,
  RecurringTransaction recurring,
  String localeName,
) {
  final freq = recurringFrequencyLabel(l, recurring);
  return switch (RecurringFrequency.fromString(recurring.frequency)) {
    RecurringFrequency.daily => freq,
    RecurringFrequency.monthly => l.v4RecurringMonthlyOnDay(
        freq,
        (recurring.dayOfMonth ?? recurring.startDate.day).clamp(1, 31),
      ),
    RecurringFrequency.weekly => () {
        final dow = recurring.dayOfWeek;
        // 2024-01-01 is Monday (weekday == 1).
        final refDate = (dow != null && dow >= 1 && dow <= 7)
            ? DateTime(2024, 1, dow)
            : recurring.startDate;
        return l.v4RecurringWithAnchor(
          freq,
          DateFormat.E(localeName).format(refDate),
        );
      }(),
    RecurringFrequency.yearly => () {
        final m = (recurring.monthOfYear ?? recurring.startDate.month).clamp(
          1,
          12,
        );
        final rawDay =
            (recurring.monthOfYear != null && recurring.dayOfMonth != null
                    ? recurring.dayOfMonth!
                    : recurring.startDate.day)
                .clamp(1, 31);
        final maxDay = DateTime(2024, m + 1, 0).day;
        final refDate = DateTime(2024, m, rawDay > maxDay ? maxDay : rawDay);
        return l.v4RecurringWithAnchor(
          freq,
          DateFormat.Md(localeName).format(refDate),
        );
      }(),
  };
}

/// The host resolves category images, per-ledger base currency, privacy and
/// semantic amount colors; the reusable package only renders supplied widgets.
class RecurringBillBinding extends ConsumerWidget {
  const RecurringBillBinding(
      {super.key,
      required this.recurring,
      required this.busy,
      this.onOpen,
      this.onToggle});
  final RecurringTransaction recurring;
  final bool busy;
  final VoidCallback? onOpen;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final ledger =
        ref.watch(ledgerByIdProvider(recurring.ledgerId)).valueOrNull;
    final hasAccountRefs =
        recurring.accountId != null || recurring.toAccountId != null;
    final accountsAsync =
        hasAccountRefs ? ref.watch(_recurringAccountsProvider) : null;
    final accountsLoaded = accountsAsync?.hasValue ?? false;
    final accountsList = accountsAsync?.valueOrNull ?? const <Account>[];

    Account? findAccount(int? id) {
      if (id == null) return null;
      for (final account in accountsList) {
        if (account.id == id) return account;
      }
      return null;
    }

    final fromAccount = findAccount(recurring.accountId);
    final toAccount = recurring.type == 'transfer'
        ? findAccount(recurring.toAccountId)
        : null;

    String? warningMessage;
    var blockedByAccount = false;
    if (accountsLoaded) {
      if (recurring.accountId != null) {
        if (fromAccount == null) {
          blockedByAccount = true;
          warningMessage = l.v4RecurringAccountMissingWarning;
        } else if (fromAccount.hidden) {
          blockedByAccount = true;
          warningMessage = l.v4RecurringAccountHiddenWarning(fromAccount.name);
        }
      }
      if (warningMessage == null &&
          recurring.type == 'transfer' &&
          recurring.toAccountId != null) {
        if (toAccount == null) {
          blockedByAccount = true;
          warningMessage = l.v4RecurringAccountMissingWarning;
        } else if (toAccount.hidden) {
          blockedByAccount = true;
          warningMessage = l.v4RecurringToAccountHiddenWarning(toAccount.name);
        }
      }
    }

    String? nextRunLabel;
    var nextRunCaption = l.v4RecurringAutomatic;
    var nextRunHighlighted = false;
    var nextRunMuted = false;
    if (!recurring.enabled) {
      nextRunLabel = l.v4RecurringStatusPaused;
      nextRunMuted = true;
    } else if (blockedByAccount) {
      nextRunLabel = l.v4RecurringStatusBlocked;
      nextRunMuted = true;
    } else {
      final upcoming = RecurringTransactionService.previewUpcomingOccurrences(
        RecurringScheduleSpec.fromModel(recurring),
        count: 1,
      );
      if (upcoming.isEmpty) {
        nextRunLabel = l.v4RecurringStatusCompleted;
        nextRunMuted = true;
      } else {
        final next = upcoming.first;
        nextRunLabel = DateFormat.MMMd(localeName).format(next.date);
        final String relative;
        if (next.daysFromToday <= 0) {
          relative = l.calendarToday;
          nextRunHighlighted = true;
        } else if (next.daysFromToday == 1) {
          relative = l.v4RecurringPreviewTomorrow;
        } else {
          relative = l.v4RecurringPreviewInDays(next.daysFromToday);
        }
        nextRunCaption = l.v4RecurringNextCaption(relative);
      }
    }

    final baseLedger = ledger == null
        ? l.billCardUnknownLedger
        : '${ledger.name} · ${ledger.currency}';
    final String? accountSummary;
    if (recurring.type == 'transfer' &&
        (fromAccount != null || toAccount != null)) {
      accountSummary =
          '${fromAccount?.name ?? l.accountNone} → ${toAccount?.name ?? l.accountNone}';
    } else if (fromAccount != null) {
      accountSummary = fromAccount.name;
    } else {
      accountSummary = null;
    }
    final ledgerSubtitle = accountSummary == null || ledger == null
        ? baseLedger
        : '${ledger.name} · $accountSummary · ${ledger.currency}';

    final code = recurring.currencyCode;
    // Match the original non-null foreign-code behavior while loading a book.
    final foreign = code != null &&
        code.isNotEmpty &&
        code.toUpperCase() != (ledger?.currency.toUpperCase() ?? '');
    final color = switch (recurring.type) {
      'expense' => BeeTokens.expenseColor(context, ref),
      'income' => BeeTokens.incomeColor(context, ref),
      _ => Theme.of(context).colorScheme.onSurface,
    };
    Widget content(Category? category) {
      final title = recurring.type == 'transfer'
          ? l.transferTitle
          : category == null
              ? l.commonOther
              : CategoryUtils.getDisplayName(category.name, context);
      return BeeRecurringBillCard(
          title: title,
          amountLabel: switch (recurring.type) {
            'expense' => l.v4RecurringAmountExpense,
            'income' => l.v4RecurringAmountIncome,
            _ => l.v4RecurringAmountTransfer,
          },
          ledger: ledgerSubtitle,
          frequency: recurringScheduleLabel(l, recurring, localeName),
          icon: recurring.type == 'transfer'
              ? const BeeLineIcon('ArrowLeftRight', size: 20)
              : category == null
                  ? const BeeLineIcon('Shapes', size: 20)
                  : RecordingCategoryIcon(category: category, size: 20),
          amount: Row(mainAxisSize: MainAxisSize.min, children: [
            if (foreign) ...[
              Text(code.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).hintColor)),
              const SizedBox(width: 6),
            ],
            Flexible(
                child: AmountText(
                    value: recurring.type == 'expense'
                        ? -recurring.amount
                        : recurring.amount,
                    signed: recurring.type != 'transfer',
                    style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: color))),
          ]),
          note: recurring.note,
          lastGenerated: recurring.lastGeneratedDate == null
              ? l.v4RecurringNotGeneratedYet
              : '${l.v4RecurringLastGeneratedLabel} ${DateFormat.Md(localeName).format(recurring.lastGeneratedDate!)}',
          nextRunCaption: nextRunCaption,
          nextRunLabel: nextRunLabel,
          nextRunHighlighted: nextRunHighlighted,
          nextRunMuted: nextRunMuted,
          warningMessage: warningMessage,
          enabled: recurring.enabled,
          toggleLabel: '${l.recurringTransactionTitle} · $title',
          busy: busy,
          onOpen: onOpen,
          onToggle: onToggle);
    }

    if (recurring.type == 'transfer' || recurring.categoryId == null) {
      return content(null);
    }
    return FutureBuilder<Category?>(
        future: ref
            .watch(repositoryProvider)
            .getCategoryById(recurring.categoryId!),
        builder: (_, snapshot) => content(snapshot.data));
  }
}
