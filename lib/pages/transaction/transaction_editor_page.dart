import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_editor_sheet.dart';
import '../../widgets/transaction/transfer_form.dart';
import '../../presentation/v4/bindings/recording_category_section.dart';
import '../../presentation/v4/bindings/recording_save.dart';

/// 交易编辑器页面
/// 支持创建/编辑收入、支出和转账记录
class TransactionEditorPage extends ConsumerStatefulWidget {
  final bool isCopy;
  final String initialKind; // 'expense', 'income', or 'transfer'
  // Retained for existing callers; recording now opens the full editor.
  final bool quickAdd;

  final int? initialCategoryId;
  final String? initialNote; // 用于金额输入弹窗回填备注
  final double? initialAmount;
  final DateTime? initialDate;
  final int? editingTransactionId;
  final int? initialAccountId;
  final int? initialToAccountId; // 转账时的目标账户
  final List<int>? initialTagIds; // 初始标签ID列表
  final bool initialExcludeFromStats; // 不计入收支，编辑模式回显
  final bool initialExcludeFromBudget; // 不计入预算，编辑模式回显
  // v30 多币种编辑回显(推隐含汇率用)
  final String? initialCurrencyCode;
  final double? initialNativeAmount;

  const TransactionEditorPage({
    super.key,
    this.isCopy = false,
    required this.initialKind,
    this.quickAdd = false,
    this.initialCategoryId,
    this.initialNote,
    this.initialAmount,
    this.initialDate,
    this.editingTransactionId,
    this.initialAccountId,
    this.initialToAccountId,
    this.initialTagIds,
    this.initialExcludeFromStats = false,
    this.initialExcludeFromBudget = false,
    this.initialCurrencyCode,
    this.initialNativeAmount,
  });

  /// Reuse business fields only; saving takes the normal creation path.
  factory TransactionEditorPage.copy({
    required Transaction source,
    required List<int> tagIds,
    DateTime? now,
  }) =>
      TransactionEditorPage(
        isCopy: true,
        initialKind: source.type,
        quickAdd: true,
        initialCategoryId: source.categorySyncIdOverride == null
            ? source.categoryId
            : syntheticIdForSyncId(source.categorySyncIdOverride!),
        initialAccountId: source.accountSyncIdOverride == null
            ? source.accountId
            : syntheticIdForSyncId(source.accountSyncIdOverride!),
        initialToAccountId: source.toAccountSyncIdOverride == null
            ? source.toAccountId
            : syntheticIdForSyncId(source.toAccountSyncIdOverride!),
        initialAmount: source.amount,
        initialDate: now ?? DateTime.now(),
        initialNote: source.note,
        initialTagIds: List.unmodifiable(tagIds),
        initialExcludeFromStats: source.excludeFromStats,
        initialExcludeFromBudget: source.excludeFromBudget,
        initialCurrencyCode: source.currencyCode,
        initialNativeAmount: source.nativeAmount,
      );

  @override
  ConsumerState<TransactionEditorPage> createState() =>
      _TransactionEditorPageState();
}

class _TransactionEditorPageState extends ConsumerState<TransactionEditorPage> {
  late int _selectedType;
  Category? _cardCategory;
  GlobalKey<AmountEditorSheetState> _cardEditorKey =
      GlobalKey<AmountEditorSheetState>();
  bool _cardReset = false;
  int? _retryTransactionId;
  bool _cardDirty = false;
  bool _cardReady = false;
  bool _cardInitFailed = false;
  bool _cardSaving = false;
  int? _cardInitialAccountId;
  late int _cardLedgerId;
  late DateTime _cardInitialDate;

  @override
  void initState() {
    super.initState();
    _cardInitialDate = widget.initialDate ?? DateTime.now();
    _selectedType = widget.initialKind == 'income'
        ? 1
        : widget.initialKind == 'transfer'
            ? 2
            : 0;
    _cardLedgerId = ref.read(currentLedgerIdProvider);
    _initializeCardEditor();
  }

  Future<void> _initializeCardEditor() async {
    if (_cardInitFailed) setState(() => _cardInitFailed = false);
    try {
      final repo = ref.read(repositoryProvider);
      final initialId = widget.initialCategoryId;
      Category? category;
      if (initialId != null) {
        category = initialId < 0 && repo is LocalRepository
            ? await repo.db.findCategoryBySyntheticId(initialId)
            : await repo.getCategoryById(initialId);
      }
      final account = widget.initialAccountId ??
          (widget.editingTransactionId == null && !widget.isCopy
              ? await defaultRecordingAccount(
                  ref, widget.initialKind, _cardLedgerId)
              : null);
      if (!mounted) return;
      setState(() {
        _cardCategory = category;
        _cardInitialAccountId = account;
        _cardReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _cardInitFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = BeeCardTheme.fromBrightness(theme.brightness);
    final l10n = AppLocalizations.of(context);
    final onPrimary =
        ThemeData.estimateBrightnessForColor(theme.colorScheme.primary) ==
                Brightness.light
            ? const Color(0xff262829)
            : Colors.white;
    final kind = _selectedType == 1
        ? 'income'
        : _selectedType == 2
            ? 'transfer'
            : 'expense';
    return Theme(
      data: theme.copyWith(
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant)),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  foregroundColor: onPrimary,
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)))),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)))),
          colorScheme: theme.colorScheme.copyWith(onPrimary: onPrimary),
          extensions: [
            ...theme.extensions.values
                .where((extension) => extension is! BeeCardTheme),
            cards
          ]),
      child: Scaffold(
          backgroundColor: cards.canvas,
          body: SafeArea(
              child: AbsorbPointer(
            absorbing: _cardSaving,
            child: Column(children: [
              RecordingHeader(
                  height: MediaQuery.sizeOf(context).height -
                              MediaQuery.viewPaddingOf(context).vertical <
                          720
                      ? (MediaQuery.sizeOf(context).width <= 340 ? 44 : 46)
                      : 50,
                  labels: [
                    l10n.categoryExpense,
                    l10n.categoryIncome,
                    l10n.transferTitle
                  ],
                  selectedIndex: _selectedType,
                  backLabel: l10n.commonBack,
                  onBack: () => Navigator.maybePop(context),
                  moreLabel: l10n.txFlagMoreOptions,
                  onMore: kind == 'transfer'
                      ? null
                      : () =>
                          _cardEditorKey.currentState?.showRecordingOptions(),
                  onChanged: _changeType),
              Expanded(
                child: _cardInitFailed
                    ? Center(
                        child: TextButton(
                            onPressed: _initializeCardEditor,
                            child: Text(l10n.v4RecordingRetry)))
                    : !_cardReady
                        ? const Center(child: CircularProgressIndicator())
                        : kind == 'transfer'
                            ? TransferForm(
                                onTransferComplete: () =>
                                    Navigator.pop(context),
                                initialFromAccountId: widget.initialAccountId,
                                initialToAccountId: widget.initialToAccountId,
                                editingTransactionId:
                                    widget.editingTransactionId,
                                initialAmount: widget.initialAmount,
                                initialNote: widget.initialNote,
                                initialDate: widget.initialDate,
                                initialTagIds: widget.initialTagIds,
                                initialExcludeFromStats:
                                    widget.initialExcludeFromStats,
                                initialExcludeFromBudget:
                                    widget.initialExcludeFromBudget,
                                initialCurrencyCode: widget.initialCurrencyCode,
                                initialNativeAmount: widget.initialNativeAmount,
                              )
                            : AmountEditorSheet(
                                key: _cardEditorKey,
                                cardLayout: true,
                                systemKeyboardVisible:
                                    // Some floating/minimized IMEs report a
                                    // 1px inset without covering the editor.
                                    MediaQuery.viewInsetsOf(context).bottom >
                                        kMinInteractiveDimension,
                                categoryName: _cardCategory?.name ?? '',
                                categoryId: _cardCategory?.id,
                                categorySyncId: (_cardCategory?.id ?? 0) < 0
                                    ? _cardCategory?.syncId
                                    : null,
                                categorySection: RecordingCategorySection(
                                    ledgerId: _cardLedgerId,
                                    kind: kind,
                                    selectedId: _cardCategory?.id,
                                    onSelected: (category) => setState(() {
                                          _cardCategory = category;
                                          _cardDirty = true;
                                        })),
                                canSubmit: _cardCategory != null,
                                onLedgerChanged:
                                    widget.editingTransactionId == null &&
                                            !widget.isCopy
                                        ? _changeCardLedger
                                        : null,
                                externalDraftChanged: _cardDirty,
                                initialDate: _cardInitialDate,
                                initialAmount:
                                    _cardReset ? null : widget.initialAmount,
                                initialNote:
                                    _cardReset ? null : widget.initialNote,
                                initialAccountId: _cardInitialAccountId,
                                initialTagIds:
                                    _cardReset ? null : widget.initialTagIds,
                                showAccountPicker: true,
                                ledgerId: _cardLedgerId,
                                editingTransactionId:
                                    widget.editingTransactionId,
                                transactionKind: kind,
                                initialExcludeFromStats:
                                    widget.initialExcludeFromStats,
                                initialExcludeFromBudget:
                                    widget.initialExcludeFromBudget,
                                initialCurrencyCode: _cardReset
                                    ? null
                                    : widget.initialCurrencyCode,
                                initialNativeAmount: _cardReset
                                    ? null
                                    : widget.initialNativeAmount,
                                allowContinueAdding: !widget.isCopy &&
                                    widget.editingTransactionId == null,
                                onSubmit: (result) async {
                                  final category = _cardCategory;
                                  if (category == null || _cardSaving) return;
                                  setState(() => _cardSaving = true);
                                  try {
                                    await _saveTransaction(
                                        category, kind, result,
                                        targetLedgerId: _cardLedgerId);
                                  } finally {
                                    if (mounted) {
                                      setState(() => _cardSaving = false);
                                    }
                                  }
                                }),
              ),
            ]),
          ))),
    );
  }

  Future<void> _changeCardLedger(int ledgerId) async {
    final kind = _selectedType == 1 ? 'income' : 'expense';
    final accountId = await defaultRecordingAccount(ref, kind, ledgerId);
    if (!mounted) return;
    ref.read(currentLedgerIdProvider.notifier).state = ledgerId;
    setState(() {
      _cardLedgerId = ledgerId;
      _cardInitialAccountId = accountId;
      _cardCategory = null;
      _cardDirty = false;
      _cardReset = true;
      _cardInitialDate = DateTime.now();
      _retryTransactionId = null;
      _cardEditorKey = GlobalKey<AmountEditorSheetState>();
    });
  }

  Future<void> _changeType(int index) async {
    if (!_cardReady || _cardSaving || _selectedType == index) return;
    final previousIndex = _selectedType;
    final previousLedger = _cardLedgerId;
    if (index == 2 || _selectedType == 2) {
      final l10n = AppLocalizations.of(context);
      final discard = await showBeeConfirm(context,
          title: l10n.v4RecordingDiscardTitle,
          message: l10n.v4RecordingDiscardMessage,
          confirmLabel: l10n.commonConfirm,
          cancelLabel: l10n.commonCancel);
      if (!discard || !mounted) return;
    }
    var hadChanges = _cardCategory != null ||
        (_cardEditorKey.currentState?.hasDraftChanges ?? false);
    if (!hadChanges &&
        previousIndex != 2 &&
        index != 2 &&
        widget.editingTransactionId == null &&
        !widget.isCopy &&
        widget.initialAccountId == null &&
        widget.initialCurrencyCode == null) {
      final accountId = await defaultRecordingAccount(
          ref, index == 1 ? 'income' : 'expense', _cardLedgerId);
      if (!mounted ||
          _selectedType != previousIndex ||
          _cardLedgerId != previousLedger) {
        return;
      }
      // Input may have changed while the default account was loading.
      hadChanges = _cardCategory != null ||
          (_cardEditorKey.currentState?.hasDraftChanges ?? false);
      if (!hadChanges &&
          (_cardEditorKey.currentState
                  ?.applyDefaultAccountIfUntouched(accountId) ??
              false)) {
        _cardInitialAccountId = accountId;
      }
    }
    if (!mounted ||
        _selectedType != previousIndex ||
        _cardLedgerId != previousLedger) {
      return;
    }
    setState(() {
      _selectedType = index;
      _cardCategory = null;
      _cardDirty = hadChanges;
    });
  }

  Future<void> _saveTransaction(
    Category c,
    String kind,
    AmountEditorResult res, {
    required int targetLedgerId,
  }) async {
    await persistRecordingDraft(ref,
        ledgerId: targetLedgerId,
        category: c,
        kind: kind,
        result: res,
        editingId: widget.editingTransactionId ?? _retryTransactionId,
        onCreated: (id) => _retryTransactionId = id);
    // 更新小组件数据（后台执行，不阻塞UI）
    if (mounted) {
      updateAppWidget(ref, context);
    }
    _retryTransactionId = null;
    if (res.continueAdding && mounted) {
      setState(() {
        _cardEditorKey = GlobalKey<AmountEditorSheetState>();
        _cardReset = true;
        _cardCategory = null;
        _cardDirty = false;
        _retryTransactionId = null;
        _cardInitialDate = DateTime.now();
      });
    }
    if (!res.continueAdding && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (res.continueAdding && mounted) {
      showToast(
        context,
        AppLocalizations.of(context).transactionSavedNextCategory,
        tone: BeeTone.success,
      );
    }
    // 反馈：轻微触感 + 系统点击音
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }
}
