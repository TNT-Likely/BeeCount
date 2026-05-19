import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../styles/tokens.dart';
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

  const AccountSelector({
    super.key,
    required this.selectedAccountId,
    required this.onAccountSelected,
    required this.ledgerId,
  });

  @override
  ConsumerState<AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends ConsumerState<AccountSelector> {
  List<Account> _accounts = [];
  List<int> _lruOrder = [];
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

      final accounts = allAccounts
          .where((a) => a.currency == ledger.currency && isTradableType(a.type))
          .toList();

      // 获取 LRU 排序
      final lruOrder = await _lruCache.getOrderedIds();

      logger.debug('AccountSelector', '加载账户完成，初始选中: $_initialSelectedAccountId, LRU顺序: $lruOrder');

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
      final selected = _accounts.where((a) => a.id == _initialSelectedAccountId).firstOrNull;
      if (selected != null) {
        sorted.add(selected);
      }
    }

    // 按 LRU 顺序添加其他账户
    for (final id in _lruOrder) {
      final account = _accounts.where((a) => a.id == id && a.id != _initialSelectedAccountId).firstOrNull;
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
      return const SizedBox(
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final sortedAccounts = _getSortedAccounts();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: sortedAccounts.length + 1, // +1 for "no account" option
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          // "无账户"永远在第一位
          if (index == 0) {
            final isSelected = widget.selectedAccountId == null;
            return _buildAccountChip(
              label: AppLocalizations.of(context).accountNone,
              isSelected: isSelected,
              onTap: () => _onAccountTap(null),
            );
          }

          // 其他账户从索引 1 开始
          final accountIndex = index - 1;
          final account = sortedAccounts[accountIndex];
          final isSelected = widget.selectedAccountId == account.id;

          return _buildAccountChip(
            label: account.name,
            isSelected: isSelected,
            onTap: () => _onAccountTap(account.id),
          );
        },
      ),
    );
  }

  Widget _buildAccountChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = ref.watch(primaryColorProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : BeeTokens.surfaceChip(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : BeeTokens.textSecondary(context),
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
