import '../../presentation/v4/bindings/account_sections.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../widgets/biz/format_money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/currency/rate_math.dart';
import '../../widgets/ui/ui.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../utils/net_worth_trend_utils.dart';
import '../currency/exchange_rate_page.dart';
import 'account_edit_page.dart';
import 'account_detail_page.dart';
import 'net_worth_trend_page.dart';

part '../../presentation/v4/bindings/account_overview.dart';
part '../../presentation/v4/bindings/assets_card_actions.dart';

class AccountsPage extends ConsumerStatefulWidget {
  final bool asTab;
  const AccountsPage({super.key, this.asTab = false});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage>
    with _AccountsOverviewBindings {
  /// 拖拽后临时保持本地排序，防止 stream rebuild 闪烁
  @override
  Map<String, List<db.Account>>? _reorderingGroups;

  @override
  void initState() {
    super.initState();
    // 进页静默刷新汇率:内部自带多币种总闸(D6)+ 24h 节流,单币种零请求。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshExchangeRatesFromUi(ref);
    });
  }

  @override
  Map<String, List<db.Account>> _groupAccounts(List<db.Account> accounts) {
    final Map<String, List<db.Account>> grouped = {};
    for (final account in accounts) {
      grouped.putIfAbsent(account.type, () => []).add(account);
    }
    return grouped;
  }

  @override
  void _onReorder(
      String type, List<db.Account> groupAccounts, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    // 乐观更新：用本地状态锁住当前排序，防止 stream 刷新导致闪烁
    setState(() {
      _reorderingGroups ??= _groupAccounts(
        ref.read(allAccountsStreamProvider).asData?.value ?? [],
      );
      final list = _reorderingGroups![type]!;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });

    // 构建批量更新
    final list = _reorderingGroups![type]!;
    final updates = <({int id, int sortOrder})>[];
    for (int i = 0; i < list.length; i++) {
      updates.add((id: list[i].id, sortOrder: i));
    }

    // 写入数据库，延迟清除本地状态让 stream 先到位
    ref.read(repositoryProvider).updateAccountSortOrders(updates).then((_) {
      // 账户拖拽排序也推到服务端。账户的 ChangeTracker 变更用的是 account.ledgerId
      // （非 0），走常规 push 路径即可。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _reorderingGroups = null);
      });
    });
  }

  @override
  void dispose() {
    _assetListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: widget.asTab ? l.tabAssets : l.accountsTitle,
          leading: widget.asTab ? null : const BackButton(),
          actions: [
            DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .12)),
                child: BeeIconButton(
                    label: l.accountAddTooltip,
                    icon: const BeeLineIcon('Plus'),
                    onPressed: () => _addAccount(
                        context, ref, ref.read(currentLedgerIdProvider)))),
            BeeIconButton(
                label: l.commonSettings,
                icon: const BeeLineIcon('Ellipsis'),
                onPressed: _showAssetMore),
          ]),
      Expanded(child: _buildAccountsBody(context)),
    ]));
  }
}
