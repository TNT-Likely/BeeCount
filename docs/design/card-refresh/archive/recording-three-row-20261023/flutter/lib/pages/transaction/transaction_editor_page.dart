import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:beecount_ui/beecount_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_editor_sheet.dart';
import '../../widgets/category/category_selector.dart';
import '../../widgets/transaction/transfer_form.dart';
import '../../styles/tokens.dart';
import '../../services/billing/post_processor.dart';
import '../../services/attachment_service.dart';
import '../../services/data/tx_author_service.dart';
import '../../presentation/v4/bindings/recording_category_section.dart';

/// 交易编辑器页面
/// 支持创建/编辑收入、支出和转账记录
class TransactionEditorPage extends ConsumerStatefulWidget {
  final bool isCopy;
  final String initialKind; // 'expense', 'income', or 'transfer'
  // quickAdd: 点击分类后在当前弹窗上叠加金额输入
  final bool quickAdd;

  /// Development opt-in; the production entry remains on the existing UI.
  final bool useV4;
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
    this.useV4 = const bool.fromEnvironment('BEECOUNT_V4_RECORDING'),
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

class _TransactionEditorPageState extends ConsumerState<TransactionEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _autoOpened = false;
  bool get _usesCardEditor => widget.useV4 && widget.quickAdd;
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
    _tab = TabController(length: 3, vsync: this);
    // 设置初始tab: 0=支出, 1=收入, 2=转账
    if (widget.initialKind == 'income') {
      _tab.index = 1;
    } else if (widget.initialKind == 'transfer') {
      _tab.index = 2;
    } else {
      _tab.index = 0;
    }

    // 若需要自动打开金额输入，则在首帧后查询分类并触发
    // 注意：转账类型不走这个逻辑
    if (_usesCardEditor) {
      _cardLedgerId = ref.read(currentLedgerIdProvider);
      _initializeCardEditor();
    } else if (widget.quickAdd &&
        widget.initialCategoryId != null &&
        widget.initialKind != 'transfer') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _autoOpened) return;
        final repo = ref.read(repositoryProvider);
        // §7 共享账本:initialCategoryId 可能是 synthetic(< 0)— Editor 编辑
        // 共享账本下记的 tx,反查走 SharedLedger* 表。
        Category? c;
        if (widget.initialCategoryId! < 0 && repo is LocalRepository) {
          c = await repo.db
              .findCategoryBySyntheticId(widget.initialCategoryId!);
        } else {
          c = await repo.getCategoryById(widget.initialCategoryId!);
        }
        if (c != null && mounted) {
          // 切换到对应的 tab
          final idx = c.kind == 'income' ? 1 : 0;
          if (_tab.index != idx) _tab.animateTo(idx);
          _autoOpened = true;
          // 直接调用 onPick 逻辑，打开金额输入
          // ignore: use_build_context_synchronously
          await _onCategorySelected(context, c, c.kind);
        }
      });
    }
    // 注意：转账编辑模式不需要在这里做任何操作，让 TransferForm 自己处理
  }

  @override
  Widget build(BuildContext context) {
    if (_usesCardEditor) return _buildCardEditor(context);
    return Scaffold(
      body: Column(
        children: [
          // 紧凑顶部：去除多余留白 + 选中下划线
          PrimaryHeader(
            title: '',
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            bottom: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: TabBar(
                            controller: _tab,
                            isScrollable: false,
                            labelColor: BeeTokens.textPrimary(context),
                            unselectedLabelColor:
                                BeeTokens.textSecondary(context),
                            indicator: UnderlineTabIndicator(
                              borderSide: BorderSide(
                                  width: 2,
                                  color: BeeTokens.textPrimary(context)),
                              insets: const EdgeInsets.symmetric(horizontal: 0),
                            ),
                            tabs: [
                              Tab(
                                  text: AppLocalizations.of(context)
                                      .categoryExpense),
                              Tab(
                                  text: AppLocalizations.of(context)
                                      .categoryIncome),
                              Tab(
                                  text: AppLocalizations.of(context)
                                      .transferTitle),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppLocalizations.of(context).commonCancel,
                            style: TextStyle(
                                color: BeeTokens.textPrimary(context))),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                CategorySelector(
                  kind: 'expense',
                  onCategorySelected: (c) =>
                      _onCategorySelected(context, c, 'expense'),
                  initialCategoryId: widget.initialCategoryId,
                ),
                CategorySelector(
                  kind: 'income',
                  onCategorySelected: (c) =>
                      _onCategorySelected(context, c, 'income'),
                  initialCategoryId: widget.initialCategoryId,
                ),
                TransferForm(
                  onTransferComplete: () {
                    // 关闭交易编辑器
                    Navigator.pop(context);
                  },
                  initialFromAccountId: widget.initialAccountId,
                  initialToAccountId: widget.initialToAccountId,
                  editingTransactionId: widget.editingTransactionId,
                  initialAmount: widget.initialAmount,
                  initialNote: widget.initialNote,
                  initialDate: widget.initialDate,
                  initialTagIds: widget.initialTagIds,
                  initialExcludeFromStats: widget.initialExcludeFromStats,
                  initialExcludeFromBudget: widget.initialExcludeFromBudget,
                  initialCurrencyCode: widget.initialCurrencyCode,
                  initialNativeAmount: widget.initialNativeAmount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
              ? await _getDefaultAccountId(widget.initialKind, _cardLedgerId)
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

  Widget _buildCardEditor(BuildContext context) {
    final theme = Theme.of(context);
    final cards = BeeCardTheme.fromBrightness(theme.brightness);
    final l10n = AppLocalizations.of(context);
    final onPrimary =
        ThemeData.estimateBrightnessForColor(theme.colorScheme.primary) ==
                Brightness.light
            ? const Color(0xff262829)
            : Colors.white;
    final kind = _tab.index == 1
        ? 'income'
        : _tab.index == 2
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
              SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      IconButton(
                          tooltip: l10n.commonBack,
                          icon: const BeeLineIcon('ChevronLeft', size: 22),
                          onPressed: () => Navigator.maybePop(context)),
                      Expanded(
                          child: Center(
                              child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: cards.soft,
                              borderRadius: BorderRadius.circular(13)),
                          child: Row(
                              children: [
                            l10n.categoryExpense,
                            l10n.categoryIncome,
                            l10n.transferTitle
                          ]
                                  .asMap()
                                  .entries
                                  .map((entry) => Expanded(
                                          child: Material(
                                        color: _tab.index == entry.key
                                            ? cards.surface
                                            : Colors.transparent,
                                        elevation:
                                            _tab.index == entry.key ? 1 : 0,
                                        shadowColor: Colors.black12,
                                        borderRadius: BorderRadius.circular(9),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(9),
                                          onTap: () async {
                                            if (_tab.index == entry.key) return;
                                            if (entry.key == 2 ||
                                                _tab.index == 2) {
                                              final discard = await showDialog<
                                                      bool>(
                                                  context: context,
                                                  builder: (context) =>
                                                      BeeDialog(
                                                          title: Text(l10n
                                                              .v4RecordingDiscardTitle),
                                                          content: Text(l10n
                                                              .v4RecordingDiscardMessage),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        false),
                                                                child: Text(l10n
                                                                    .commonCancel)),
                                                            FilledButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        true),
                                                                child: Text(l10n
                                                                    .commonConfirm)),
                                                          ]));
                                              if (discard != true || !mounted) {
                                                return;
                                              }
                                            }
                                            setState(() {
                                              _tab.index = entry.key;
                                              _cardCategory = null;
                                              _cardDirty = true;
                                            });
                                          },
                                          child: SizedBox(
                                              height: 34,
                                              child: Center(
                                                  child: Text(entry.value,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: _tab
                                                                      .index ==
                                                                  entry.key
                                                              ? FontWeight.w500
                                                              : FontWeight.w400,
                                                          color: _tab.index ==
                                                                  entry.key
                                                              ? theme
                                                                  .colorScheme
                                                                  .onSurface
                                                              : theme
                                                                  .hintColor)))),
                                        ),
                                      )))
                                  .toList()),
                        ),
                      ))),
                      IconButton(
                          tooltip: l10n.txFlagMoreOptions,
                          icon: const BeeLineIcon('Ellipsis', size: 22),
                          onPressed: () => _cardEditorKey.currentState
                              ?.showRecordingOptions()),
                    ]),
                  )),
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
    final kind = _tab.index == 1 ? 'income' : 'expense';
    final accountId = await _getDefaultAccountId(kind, ledgerId);
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

  /// 获取默认账户ID（验证币种匹配）
  Future<int?> _getDefaultAccountId(String kind, int ledgerId) async {
    try {
      // 1. 根据类型获取默认账户ID
      final defaultAccountId = kind == 'income'
          ? await ref.read(defaultIncomeAccountIdProvider.future)
          : await ref.read(defaultExpenseAccountIdProvider.future);

      if (defaultAccountId == null) return null;

      // 2. 获取账本币种
      final ledger = await ref.read(ledgerByIdProvider(ledgerId).future);
      if (ledger == null) return null;

      // 3. 获取默认账户信息
      final account =
          await ref.read(accountByIdProvider(defaultAccountId).future);
      if (account == null) return null;

      // 账户隐藏 #240 E3:默认账户已被隐藏时按「无默认」处理(defensive 兜底,
      // 正常路径下隐藏时已清 pref,这里防同步竞态等边缘情况)
      if (account.hidden) return null;

      // 4. 验证币种匹配
      if (account.currency != ledger.currency) return null;

      return defaultAccountId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _onCategorySelected(
      BuildContext context, Category c, String kind) async {
    if (!widget.quickAdd) {
      Navigator.pop(context, c);
      return;
    }
    final ledgerId = ref.read(currentLedgerIdProvider);

    // 确定初始账户ID（新建时使用默认账户，编辑时保持原值）
    int? initialAccountId = widget.initialAccountId;
    if (!widget.isCopy &&
        widget.editingTransactionId == null &&
        widget.initialAccountId == null) {
      // 新建模式：尝试获取默认账户
      initialAccountId = await _getDefaultAccountId(kind, ledgerId);
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeTokens.surfaceSheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AmountEditorSheet(
        categoryName: c.name,
        categoryId: c.id,
        categorySyncId: c.id < 0 ? c.syncId : null,
        initialDate: widget.initialDate ?? DateTime.now(),
        initialAmount: widget.initialAmount,
        initialNote: widget.initialNote,
        initialAccountId: initialAccountId,
        initialTagIds: widget.initialTagIds,
        showAccountPicker: true,
        ledgerId: ledgerId,
        editingTransactionId: widget.editingTransactionId,
        transactionKind: kind,
        initialExcludeFromStats: widget.initialExcludeFromStats,
        initialExcludeFromBudget: widget.initialExcludeFromBudget,
        initialCurrencyCode: widget.initialCurrencyCode,
        initialNativeAmount: widget.initialNativeAmount,
        allowContinueAdding: widget.quickAdd &&
            !widget.isCopy &&
            widget.editingTransactionId == null &&
            kind != 'transfer',
        onSubmit: (res) => _saveTransaction(c, kind, res,
            sheetContext: ctx, targetLedgerId: ledgerId),
      ),
    );
  }

  Future<void> _saveTransaction(
    Category c,
    String kind,
    AmountEditorResult res, {
    BuildContext? sheetContext,
    int? targetLedgerId,
  }) async {
    final int ledgerId =
        targetLedgerId ?? ref.read<int>(currentLedgerIdProvider);
    if (_usesCardEditor && ledgerId != ref.read(currentLedgerIdProvider)) {
      throw StateError('Ledger context changed during recording');
    }
    if (_usesCardEditor) {
      final available = await ref.read(
          recordingCategoriesProvider((ledgerId: ledgerId, kind: kind)).future);
      if (!available.any((category) => category.id == c.id)) {
        throw StateError('Selected category is no longer available');
      }
      if (!mounted) return;
    }
    final repo = ref.read(repositoryProvider);
    final attachmentService = ref.read(attachmentServiceProvider);
    int transactionId;
    // §7 v25:Category 是来自 SharedLedger* 的 synthetic (id<0)时,
    // categoryId 留 null,override 走 syncId。同理对 account/toAccount。
    // res.accountId 可能也是 synthetic(Account picker 用同一规则)。
    final isSyntheticCategory = c.id < 0;
    final isSyntheticAccount = res.accountId != null && res.accountId! < 0;
    final categoryIdForWrite = isSyntheticCategory ? null : c.id;
    // synthetic / picker 返 null 时账户 id 写 null。
    // addTransaction 的 accountId 是 int?(直接传 null 即写 null);
    // updateTransaction 的 accountId 是 dynamic,dart null 被解释成
    // Value.absent(=不更新该字段) → 用户选"不选择账户"无效;必须显式
    // 传 d.Value<int?>(null) 才会真清空旧 accountId。
    final accountIdForAdd = isSyntheticAccount ? null : res.accountId;
    final accountIdForUpdate = d.Value<int?>(accountIdForAdd);
    final categoryOverride = isSyntheticCategory ? c.syncId : null;
    final accountOverride = isSyntheticAccount
        ? await _resolveSyncIdByAccountId(res.accountId!, ledgerId)
        : null;
    final editingId = widget.editingTransactionId ?? _retryTransactionId;
    if (editingId != null) {
      // 编辑模式：使用repository更新交易
      await repo.updateTransaction(
        id: editingId,
        type: kind,
        amount: res.amount,
        categoryId: categoryIdForWrite,
        note: res.note,
        happenedAt: res.date,
        accountId: accountIdForUpdate,
        categorySyncIdOverride: categoryOverride,
        accountSyncIdOverride: accountOverride,
        excludeFromStats: res.excludeFromStats,
        excludeFromBudget: res.excludeFromBudget,
        currencyCode: res.currencyCode,
        nativeAmount: res.nativeAmount,
      );
      transactionId = editingId;
      // 共享账本:本地 lastEditedByUserId 立即回填,UI 头像组直接展示
      // 当前 user 为编辑人(否则要等 server 下次 pull 才回来)
      await TxAuthorService.markEdited(ref, transactionId);
    } else {
      transactionId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: kind,
        amount: res.amount,
        categoryId: categoryIdForWrite,
        happenedAt: res.date,
        note: res.note,
        accountId: accountIdForAdd,
        categorySyncIdOverride: categoryOverride,
        accountSyncIdOverride: accountOverride,
        excludeFromStats: res.excludeFromStats,
        excludeFromBudget: res.excludeFromBudget,
        currencyCode: res.currencyCode,
        nativeAmount: res.nativeAmount,
      );
      _retryTransactionId = transactionId;
      // 共享账本:新建本地 tx 也回填创建人 + 编辑人(同一个 user)
      await TxAuthorService.markCreated(ref, transactionId);
    }
    // 保存待上传的附件
    if (res.pendingAttachments.isNotEmpty) {
      await attachmentService.saveAttachments(
        transactionId: transactionId,
        sourceFiles: res.pendingAttachments,
        startIndex: 0,
      );
      // 刷新附件列表缓存
      ref.read(attachmentListRefreshProvider.notifier).state++;
    }
    // 更新标签关联
    // §7 共享账本:tag.id < 0 是 synthetic(Owner tag from SharedLedger*),
    // 主表 Tags 没该行,不能直接写 transaction_tags.tag_id。分两类:
    // - 正数 id → 写 transaction_tags 主表(老路径)
    // - 负数 id → 走 SharedLedgerTags 反查 syncId → 写 transaction_tag_overrides
    final normalTagIds = res.tagIds.where((id) => id >= 0).toList();
    final syntheticTagIds = res.tagIds.where((id) => id < 0).toList();

    if (normalTagIds.isNotEmpty) {
      await repo.updateTransactionTags(
        transactionId: transactionId,
        tagIds: normalTagIds,
      );
      ref.read(tagListRefreshProvider.notifier).state++;
    } else if (editingId != null) {
      // 编辑模式没主表 tag → 清掉旧主表关联
      await repo.removeAllTagsFromTransaction(transactionId);
      ref.read(tagListRefreshProvider.notifier).state++;
    }

    // §7 写 override:先反查 tx.syncId + 把 synthetic tag_id 翻译成
    // Owner tag syncId,再 upsert 进 TransactionTagOverrides
    if (repo is LocalRepository) {
      final txRow = await (repo.db.select(repo.db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      final txSyncId = txRow?.syncId;
      if (txSyncId != null) {
        await (repo.db.delete(repo.db.transactionTagOverrides)
              ..where((t) => t.transactionSyncId.equals(txSyncId)))
            .go();
        if (syntheticTagIds.isNotEmpty) {
          final allShared =
              await repo.db.select(repo.db.sharedLedgerTags).get();
          final now = DateTime.now().toUtc();
          for (final sid in syntheticTagIds) {
            for (final s in allShared) {
              if (syntheticIdForSyncId(s.syncId) == sid) {
                await repo.db.into(repo.db.transactionTagOverrides).insert(
                      TransactionTagOverridesCompanion.insert(
                        transactionSyncId: txSyncId,
                        tagSyncId: s.syncId,
                        createdAt: now,
                      ),
                    );
                break;
              }
            }
          }
          ref.read(tagListRefreshProvider.notifier).state++;
        }
        // 这里**不再**重复 recordLedgerChange(transaction:update)。
        // 之前为了"override 变化也走 push"专门补一条 update,但
        // - addTransaction / updateTransaction 已经登记过一次 change
        // - _serializeEntityForPush('transaction') 在 push 时**统一**读 DB
        //   最新状态(包括 transaction_tag_overrides 表),payload 自然含
        //   最新 overrides
        // 结论:那条补登记的 update 跟前面的 create/update 推同样 payload,
        // 服务端 sync_changes 表凭空多一条 row(已观察到共享账本 Editor
        // 创建 tx 时 1 秒内 2 条 identical upsert)。直接砍。
      }
    }
    // 统一处理：自动/手动同步与状态刷新（后台静默）
    PostProcessor.sync(ref, ledgerId: ledgerId);
    // 刷新：账本笔数与全局统计
    ref.invalidate(countsForLedgerProvider(ledgerId));
    ref.read(statsRefreshProvider.notifier).state++;
    // 刷新：预算数据
    ref.read(budgetRefreshProvider.notifier).state++;
    // 更新小组件数据（后台执行，不阻塞UI）
    if (mounted) {
      updateAppWidget(ref, context);
    }
    _retryTransactionId = null;
    // 双击完成：只收起金额面板，保留分类选择页供下一笔使用。
    // 普通完成：按原流程关闭金额面板和分类选择页。
    if (sheetContext != null &&
        sheetContext.mounted &&
        Navigator.of(sheetContext).canPop()) {
      Navigator.of(sheetContext).pop();
    }
    if (_usesCardEditor && res.continueAdding && mounted) {
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
      );
    }
    // 反馈：轻微触感 + 系统点击音
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// §7 v25:account picker 返 synthetic Account(id<0)时,把 id 反查
  /// SharedLedgerAccounts 拿 syncId,写到 tx.accountSyncIdOverride。
  /// 失败返 null,调用方应回到 accountId int 路径(synthetic 不一致时的兜底)。
  Future<String?> _resolveSyncIdByAccountId(int accountId, int ledgerId) async {
    if (accountId >= 0) return null;
    final repo = ref.read(repositoryProvider);
    if (repo is! LocalRepository) return null;
    // 反查:本地 ledger.syncId → SharedLedgerAccounts ledgerSyncId 范围
    final ledger = await (repo.db.select(repo.db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledger?.syncId == null) return null;
    final rows = await (repo.db.select(repo.db.sharedLedgerAccounts)
          ..where((t) => t.ledgerSyncId.equals(ledger!.syncId!)))
        .get();
    for (final r in rows) {
      if (syntheticIdForSyncId(r.syncId) == accountId) return r.syncId;
    }
    return null;
  }
}
