import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../presentation/v4/bindings/recording_save.dart';
import '../../presentation/v4/bindings/transfer_inline_accounts.dart';
import '../../l10n/app_localizations.dart';
import '../biz/amount_editor_sheet.dart';
import '../../utils/account_type_utils.dart';
import '../ui/ui.dart';

/// Account selection and the existing recording editor share one page. New
/// transfers require a same-currency pair, independent of the ledger currency.
class TransferForm extends ConsumerStatefulWidget {
  final bool initialExcludeFromStats, initialExcludeFromBudget;
  final String? initialCurrencyCode;
  final double? initialNativeAmount;
  final VoidCallback onTransferComplete;
  final ValueChanged<bool>? onSavingChanged;
  final int? initialFromAccountId, initialToAccountId, editingTransactionId;
  final double? initialAmount;
  final String? initialNote;
  final DateTime? initialDate;
  final List<int>? initialTagIds;
  final bool systemKeyboardVisible;
  const TransferForm(
      {super.key,
      this.initialExcludeFromStats = false,
      this.initialExcludeFromBudget = false,
      this.initialCurrencyCode,
      this.initialNativeAmount,
      required this.onTransferComplete,
      this.onSavingChanged,
      this.initialFromAccountId,
      this.initialToAccountId,
      this.editingTransactionId,
      this.initialAmount,
      this.initialNote,
      this.initialDate,
      this.initialTagIds,
      this.systemKeyboardVisible = false});
  @override
  ConsumerState<TransferForm> createState() => TransferFormState();
}

class TransferFormState extends ConsumerState<TransferForm> {
  int? _fromAccountId, _toAccountId, _retryTransactionId;
  late final int _ledgerId;
  late DateTime _initialDate;
  GlobalKey<AmountEditorSheetState> _editorKey =
      GlobalKey<AmountEditorSheetState>();
  bool _saving = false, _reset = false;
  bool get _accountsChanged =>
      _fromAccountId != widget.initialFromAccountId ||
      _toAccountId != widget.initialToAccountId;
  bool get hasDraftChanges =>
      _accountsChanged || (_editorKey.currentState?.hasDraftChanges ?? false);
  bool get _originalPair =>
      !_reset &&
      widget.editingTransactionId != null &&
      _fromAccountId == widget.initialFromAccountId &&
      _toAccountId == widget.initialToAccountId;
  @override
  void initState() {
    super.initState();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _initialDate = widget.initialDate ?? DateTime.now();
    _fromAccountId = widget.initialFromAccountId;
    _toAccountId = widget.initialToAccountId;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final base = ref.watch(currentLedgerCurrencyProvider);
    final query = (
      ledgerId: _ledgerId,
      fromPin: _reset ? null : widget.initialFromAccountId,
      toPin: _reset ? null : widget.initialToAccountId
    );
    final available = ref.watch(transferInlineAccountsProvider(query));
    return available.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
          child: TextButton(
              onPressed: () =>
                  ref.invalidate(transferInlineAccountsProvider(query)),
              child: Text(l.v4RecordingRetry))),
      data: (all) {
        final pins = {
          if (query.fromPin != null) query.fromPin!,
          if (query.toPin != null) query.toPin!
        };
        final accounts = all
            .where((account) => isTransferInlineAccountEligible(account,
                pinnedIds: pins, editing: widget.editingTransactionId != null))
            .toList();
        Account? account(int? id) {
          for (final item in accounts) {
            if (item.id == id) return item;
          }
          return null;
        }

        final from = account(_fromAccountId), to = account(_toAccountId);
        final validPair = from != null &&
            to != null &&
            from.id != to.id &&
            (from.currency.toUpperCase() == to.currency.toUpperCase() ||
                _originalPair);
        final currency = _originalPair
            ? (widget.initialCurrencyCode ?? from?.currency ?? base)
            : (from?.currency ?? base);
        Future<void> select(bool isFrom) async {
          if (_saving) return;
          FocusManager.instance.primaryFocus?.unfocus();
          final candidates = isFrom
              ? accounts
              : accounts
                  .where((item) =>
                      item.id != _fromAccountId &&
                      (from == null ||
                          item.currency.toUpperCase() ==
                              from.currency.toUpperCase() ||
                          (_originalPair &&
                              item.id == widget.initialToAccountId)))
                  .toList();
          final selected = await showBeeSheet<String>(context,
              title: isFrom ? l.transferFromAccount : l.transferToAccount,
              child: BeeAccountPicker(
                  currency: from?.currency ?? base,
                  filterByCurrency: false,
                  allowUnset: false,
                  unsetLabel: l.transferSelectAccount,
                  accounts: candidates
                      .map((item) => BeeAccountChoice(
                          id: '${item.id}',
                          name: item.name,
                          currency: item.currency,
                          balance: '',
                          detail: item.hidden ? l.accountHiddenTag : null,
                          icon: AccountTypeIcon(type: item.type, size: 24)))
                      .toList(),
                  selected: '${isFrom ? _fromAccountId : _toAccountId}',
                  searchLabel: l.transferSelectAccount,
                  emptyLabel: l.accountsEmptyMessage,
                  onSelected: (id) => Navigator.pop(context, id)));
          if (selected == null || !mounted) return;
          final id = int.parse(selected);
          setState(() {
            if (isFrom) {
              _fromAccountId = id;
              final newFrom = account(id), oldTo = account(_toAccountId);
              if (_toAccountId == id ||
                  (!_originalPair &&
                      newFrom != null &&
                      oldTo != null &&
                      newFrom.currency.toUpperCase() !=
                          oldTo.currency.toUpperCase())) {
                _toAccountId = null;
              }
            } else {
              _toAccountId = id;
            }
          });
        }

        return AmountEditorSheet(
          key: _editorKey,
          cardLayout: true,
          systemKeyboardVisible: widget.systemKeyboardVisible,
          categorySection: BeeTransferAccountPair(
              fromLabel: l.transferFromAccount,
              toLabel: l.transferToAccount,
              fromName: from?.name ?? l.transferSelectAccount,
              toName: to?.name ?? l.transferSelectAccount,
              fromDetail:
                  from?.hidden == true ? l.accountHiddenTag : from?.currency,
              toDetail: to?.hidden == true ? l.accountHiddenTag : to?.currency,
              fromIcon: from == null
                  ? null
                  : AccountTypeIcon(type: from.type, size: 24),
              toIcon:
                  to == null ? null : AccountTypeIcon(type: to.type, size: 24),
              onFrom: () => select(true),
              onTo: () => select(false)),
          categoryName: l.transferTitle,
          canSubmit: validPair,
          blockedSubmitLabel: l.transferSelectAccount,
          externalDraftChanged: _accountsChanged,
          initialDate: _initialDate,
          initialAmount: _reset ? null : widget.initialAmount,
          initialNote: _reset ? null : widget.initialNote,
          initialTagIds: _reset ? null : widget.initialTagIds,
          showAccountPicker: false,
          ledgerId: _ledgerId,
          editingTransactionId: widget.editingTransactionId,
          transactionKind: 'transfer',
          initialExcludeFromStats: widget.initialExcludeFromStats,
          initialExcludeFromBudget: widget.initialExcludeFromBudget,
          initialCurrencyCode: _reset ? null : widget.initialCurrencyCode,
          initialNativeAmount: _reset ? null : widget.initialNativeAmount,
          fixedCurrencyCode: currency,
          onSubmit: (result) async {
            if (_saving || !validPair) return;
            final fromId = _fromAccountId!, toId = _toAccountId!;
            setState(() => _saving = true);
            widget.onSavingChanged?.call(true);
            try {
              await persistTransferDraft(ref,
                  ledgerId: _ledgerId,
                  fromAccountId: fromId,
                  toAccountId: toId,
                  result: result,
                  editingId: widget.editingTransactionId ?? _retryTransactionId,
                  onCreated: (id) => _retryTransactionId = id,
                  pinnedAccountIds: pins);
              _retryTransactionId = null;
              if (!mounted || !context.mounted) return;
              showToast(
                  context,
                  widget.editingTransactionId == null
                      ? l.transferCreateSuccess
                      : l.transferUpdateSuccess,
                  tone: BeeTone.success);
              widget.onTransferComplete();
              if (mounted && widget.editingTransactionId == null) {
                setState(() {
                  _reset = true;
                  _fromAccountId = null;
                  _toAccountId = null;
                  _initialDate = DateTime.now();
                  _editorKey = GlobalKey<AmountEditorSheetState>();
                });
              }
            } finally {
              if (mounted) {
                setState(() => _saving = false);
                widget.onSavingChanged?.call(false);
              }
            }
          },
        );
      },
    );
  }
}
