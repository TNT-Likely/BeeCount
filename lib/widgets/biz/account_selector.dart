import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../utils/currencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../utils/lru_cache.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../../providers.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../services/system/logger_service.dart';
import '../../l10n/app_localizations.dart';

/// 账户选择器组件
/// 横滑标签形式，支持 LRU 排序
class AccountSelector extends ConsumerStatefulWidget {
  final int? selectedAccountId;
  final ValueChanged<int?> onAccountSelected;
  final int ledgerId;

  /// Full searchable V4 picker; the original chip consumers keep their layout.
  final bool expandedPicker;

  /// v30 多币种:按币种过滤可选账户(记账币种优先联动,选 JPY → 只显示 JPY
  /// 账户)。null = 账本本位币(旧行为)。变更时列表自动重载。
  final String? filterCurrency;

  /// 账户隐藏(#240)E1 钉住:编辑历史交易时传入该交易当前挂的账户 id。若该
  /// 账户已被隐藏(因而被下方过滤排除),补回候选并打「已隐藏」灰标,让用户
  /// 能原样保存;其余隐藏账户仍不出现。null = 不钉住(新建交易场景)。
  final int? pinnedAccountId;

  const AccountSelector({
    super.key,
    required this.selectedAccountId,
    required this.onAccountSelected,
    required this.ledgerId,
    this.filterCurrency,
    this.pinnedAccountId,
    this.expandedPicker = false,
  });

  @override
  ConsumerState<AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends ConsumerState<AccountSelector> {
  List<Account> _accounts = [];
  List<int> _lruOrder = [];
  final Map<int, double> _balances = {};
  late LRUCache _lruCache;
  bool _isLoading = true;

  // 记录初始选中的账户ID，用于排序（不随点击变化）
  int? _initialSelectedAccountId;

  @override
  void initState() {
    super.initState();
    _initialSelectedAccountId = widget.selectedAccountId;
    _lruCache = LRUCache(key: 'account_lru_${widget.ledgerId}', maxSize: 20);
    _loadAccounts();
  }

  @override
  void didUpdateWidget(covariant AccountSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // v30:记账切换币种 → 账户列表按新币种重载
    if (oldWidget.filterCurrency != widget.filterCurrency) {
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final repo = ref.read(repositoryProvider);

      // 使用 provider 查询账本信息
      final ledger = await ref.read(ledgerByIdProvider(widget.ledgerId).future);
      if (ledger == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // 获取所有账户,然后按当前账本币种 + 可交易类型筛选
      var allAccounts = await repo.getAllAccounts();

      // §7 共享账本 picker 过滤:Editor + 共享账本 → 只看 Owner mirror 账户;
      // 单人账本 / Owner 视角 → 排除 mirror 账户(只看自己 user-global)
      if (repo is LocalRepository) {
        final ctx = await repo.db.loadLedgerPickerContext(widget.ledgerId);
        allAccounts = await repo.db.filterAccountsForLedger(allAccounts, ctx);
      }

      // v30:过滤币种 = 显式传入(记账所选币种)?? 账本本位币(旧行为)
      final wanted = (widget.filterCurrency ?? ledger.currency).toUpperCase();
      var accounts = allAccounts
          .where((a) =>
              a.currency.toUpperCase() == wanted && isTradableType(a.type))
          .toList();

      // 账户隐藏(#240)E1 钉住:above 的 filterAccountsForLedger 已排除隐藏
      // 账户;若调用方传了 pinnedAccountId 且它因隐藏被排除,补回候选(带
      // hidden=true,chip 渲染时打灰标)。账户不存在或本就未隐藏则不处理。
      final pinnedId = widget.pinnedAccountId;
      if (pinnedId != null && !accounts.any((a) => a.id == pinnedId)) {
        final pinned = await repo.getAccount(pinnedId);
        if (pinned != null && pinned.hidden) {
          accounts = [...accounts, pinned];
        }
      }

      if (widget.expandedPicker) {
        _balances.clear();
        for (final account in accounts.where((a) => a.id >= 0)) {
          _balances[account.id] =
              (await repo.getAccountStats(account.id)).balance;
        }
      }
      // 获取 LRU 排序
      final lruOrder = await _lruCache.getOrderedIds();

      logger.debug('AccountSelector',
          '加载账户完成，初始选中: $_initialSelectedAccountId, LRU顺序: $lruOrder');

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _lruOrder = lruOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 根据 LRU 排序账户
  /// 使用初始选中的账户ID进行排序，避免点击时立即重排
  List<Account> _getSortedAccounts() {
    if (_accounts.isEmpty) return [];

    final List<Account> sorted = [];

    // 将初始选中的账户放在第一个（如果存在）
    if (_initialSelectedAccountId != null) {
      final selected =
          _accounts.where((a) => a.id == _initialSelectedAccountId).firstOrNull;
      if (selected != null) {
        sorted.add(selected);
      }
    }

    // 按 LRU 顺序添加其他账户
    for (final id in _lruOrder) {
      final account = _accounts
          .where((a) => a.id == id && a.id != _initialSelectedAccountId)
          .firstOrNull;
      if (account != null && !sorted.contains(account)) {
        sorted.add(account);
      }
    }

    // 添加未在 LRU 中的账户（按创建顺序）
    for (final account in _accounts) {
      if (!sorted.contains(account)) {
        sorted.add(account);
      }
    }

    return sorted;
  }

  void _onAccountTap(int? accountId) {
    logger.debug('AccountSelector', '点击账户: $accountId, 当前LRU顺序: $_lruOrder');
    widget.onAccountSelected(accountId);

    // 只记录使用，不立即更新排序（下次加载时才生效）
    if (accountId != null) {
      _lruCache.recordUsage(accountId);
      logger.debug('AccountSelector', '已记录使用，但不更新当前排序');
    }
  }

  @override
  Widget build(BuildContext context) {
    // §7 共享账本:WS shared_resource_change 推送后 tick bump,触发 _loadAccounts
    // 重查 SharedLedgerAccounts。否则 A 在 web/mobile 改账户名,B 的 picker
    // 永远显示旧名,要重启 app。
    ref.listen<int>(sharedResourceRefreshProvider, (prev, next) {
      if (prev != next) _loadAccounts();
    });
    if (_isLoading) {
      final l10n = AppLocalizations.of(context);
      return BeeAccountStrip(
          items: const [],
          selected: null,
          loading: true,
          unsetLabel: l10n.accountNone,
          emptyLabel: l10n.accountsEmptyMessage,
          hiddenLabel: l10n.accountHiddenTag,
          onSelected: (_) {});
    }

    final sortedAccounts = _getSortedAccounts();
    if (widget.expandedPicker) {
      final l10n = AppLocalizations.of(context);
      return BeeAccountPicker(
          accounts: sortedAccounts
              .map((a) => BeeAccountChoice(
                  id: '${a.id}',
                  name: a.name,
                  currency: a.currency,
                  balance: _balances.containsKey(a.id)
                      ? '${getCurrencySymbol(a.currency)}${_balances[a.id]!.toStringAsFixed(2)}'
                      : '',
                  detail: a.hidden
                      ? l10n.accountHiddenTag
                      : getAccountTypeLabel(context, a.type),
                  icon: AccountTypeIcon(type: a.type, size: 24)))
              .toList(),
          currency: widget.filterCurrency ?? '',
          // All filtering and historical pinning has already happened above.
          filterByCurrency: false,
          selected: widget.selectedAccountId?.toString(),
          searchLabel: l10n.commonSearch,
          emptyLabel: l10n.accountsEmptyMessage,
          unsetLabel: l10n.accountNone,
          onSelected: (id) => _onAccountTap(id == null ? null : int.parse(id)));
    }
    final l10n = AppLocalizations.of(context);
    return BeeAccountStrip(
      items: sortedAccounts
          .map((a) => BeeAccountStripItem(
              id: '${a.id}',
              label: a.name,
              hidden: a.hidden,
              icon: AccountTypeIcon(type: a.type, size: 18)))
          .toList(),
      selected: widget.selectedAccountId?.toString(),
      unsetLabel: l10n.accountNone,
      emptyLabel: l10n.accountsEmptyMessage,
      hiddenLabel: l10n.accountHiddenTag,
      onSelected: (id) => _onAccountTap(id == null ? null : int.parse(id)),
    );
  }
}
