part of '../../../pages/main/ledgers_page_new.dart';

mixin _LedgerActions on ConsumerState<LedgersPageNew> {
  bool get _isRestoring;
  set _isRestoring(bool value);

  /// 处理本地账本点击 - 切换账本或显示冲突对话框
  Future<void> _handleLocalLedgerTap(LedgerDisplayItem ledger) async {
    // 获取同步状态
    final syncStatusAsync = ref.read(syncStatusProvider(ledger.id));
    final syncStatus = syncStatusAsync.valueOrNull;

    // 检查是否有冲突
    if (syncStatus?.diff == SyncDiff.different) {
      // 显示冲突解决对话框
      await _showConflictResolutionDialog(context, ledger);
      return;
    }

    // 正常切换账本
    ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
    // 清除缓存的交易数据，确保切换后刷新
    ref.invalidate(cachedTransactionsWithCategoryProvider);
    showToast(
        context,
        AppLocalizations.of(context)
            .ledgersSwitched(translateLedgerName(context, ledger.name)));
  }

  /// 处理远程账本点击 - 下载
  Future<void> _handleRemoteLedgerTap(
      BuildContext _, LedgerDisplayItem ledger) async {
    final confirmed = await _confirmLedger(
      context,
      title: AppLocalizations.of(context).ledgersDownloadTitle,
      message: AppLocalizations.of(context)
          .ledgersDownloadMessage(translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      showToast(context, AppLocalizations.of(context).ledgersDownloading);

      final syncService = ref.read(syncServiceProvider);
      if (syncService is SyncEngine) {
        // BeeCount Cloud 路径（sync_changes 增量日志模型）：
        // 1) syncLedgersFromServer 把账本行插到本地 Drift
        // 2) replayAllChanges 从 cursor=0 重拉整段 sync_changes 并幂等应用，
        //    把历史 tx/account/category/tag 挂到刚刚插好的新账本上
        //
        // 不走 `_fullPull`（整包 JSON 下载）—— 那是 S3/WebDAV 的玩法，BeeCount
        // Cloud 的模型就是 sync_changes，所有恢复都应该走这条日志。apply 是
        // 按 entity_sync_id upsert 幂等的，重放不会产生副本。
        await syncService.syncLedgersFromServer();
        await syncService.replayAllChanges();
      } else if (syncService is TransactionsSyncManager) {
        // 老的 Supabase 路径
        await syncService.downloadRemoteLedger(
          name: ledger.name,
          currency: ledger.currency,
          remotePath: 'ledger_${ledger.id}.json',
        );
      } else {
        throw Exception('Cloud sync not available');
      }

      if (!mounted) return;

      // 刷新列表和同步状态
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(syncStatusRefreshProvider.notifier).state++;

      showToast(
          context,
          AppLocalizations.of(context).ledgersDownloadSuccess(
              translateLedgerName(context, ledger.name)));
    } catch (e) {
      if (!mounted) return;
      await _ledgerError(
        context,
        title: AppLocalizations.of(context).commonFailed,
        message: '$e',
      );
    }
  }

  /// 显示本地账本操作菜单
  Future<void> _showLocalLedgerActions(BuildContext _, LedgerDisplayItem ledger,
      {String? initialAction}) async {
    final isOwner = ledger.myRole == 'owner';
    final isBeeCountCloud =
        ref.read(activeCloudConfigProvider).valueOrNull?.type ==
            CloudBackendType.beecountCloud;
    final l = AppLocalizations.of(context);
    final action = initialAction ??
        await showBeeDialog<String>(context,
            title: l.ledgersActions,
            child: BeeLedgerActions(
                name: translateLedgerName(context, ledger.name),
                subtitle:
                    '${ledger.currency} · ${l.ledgersRecords('${ledger.transactionCount}')}',
                shared: ledger.isShared,
                details: Text('ID: ${ledger.id}',
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).hintColor)),
                actions: [
                  if (isOwner)
                    BeeAction(
                        id: 'edit',
                        label: l.ledgersEdit,
                        icon: const BeeLineIcon('Pencil')),
                  BeeAction(
                      id: 'budget',
                      label: l.budgetManagement,
                      icon: const BeeLineIcon('ChartPie')),
                  if (isBeeCountCloud) ...[
                    BeeAction(
                        id: 'members',
                        label: l.sharedMembersPageTitle +
                            (ledger.isShared ? ' (${ledger.memberCount})' : ''),
                        icon: const BeeLineIcon('Users')),
                    if (ledger.isShared)
                      BeeAction(
                          id: 'memberStats',
                          label: l.sharedMembersStatsTitle,
                          icon: const BeeLineIcon('ChartNoAxesCombined')),
                  ],
                  if (isOwner)
                    BeeAction(
                        id: 'clear',
                        label: l.ledgersClear,
                        icon: const BeeLineIcon('ListX'),
                        danger: true),
                  // Local copy removal remains available to editors as in the original.
                  BeeAction(
                      id: 'deleteLocal',
                      label: l.ledgersDeleteLocal,
                      icon: const BeeLineIcon('FolderMinus'),
                      danger: true),
                  if (isOwner)
                    BeeAction(
                        id: 'delete',
                        label: l.ledgersDelete,
                        icon: const BeeLineIcon('Trash2'),
                        danger: true),
                ],
                onSelected: (id) => Navigator.pop(context, id)));

    if (!mounted) return;

    if (action == 'edit') {
      await _handleEditLedger(context, ledger);
    } else if (action == 'budget') {
      // 切到长按的账本(BudgetPage 内部 watch currentLedger,不接 ledgerId 参
      // 数),再 push。语义上"从账本列表 → 长按 A → 预算管理"自然就是切到 A。
      if (ref.read(currentLedgerIdProvider) != ledger.id) {
        ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
        ref.invalidate(currentLedgerProvider);
      }
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BudgetPage()),
        );
      }
    } else if (action == 'members') {
      // 跳转成员管理 — 需要 ledger.syncId(server external_id)。本地仅 ledger
      // (没 syncId,从未同步过的)无成员概念,提示用户先建云账户。
      final row = await ref.read(repositoryProvider).getLedgerById(ledger.id);
      final syncId = row?.syncId;
      if (syncId == null || syncId.isEmpty) {
        if (mounted) {
          showToast(
              context, AppLocalizations.of(context).sharedRequiresCloudSync);
        }
        return;
      }
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MemberListPage(
            ledgerExternalId: syncId,
            ledgerName: ledger.name,
          ),
        ));
      }
    } else if (action == 'memberStats') {
      // 跟成员管理同源:取 ledger.syncId 再跳 MemberStatsPage。
      final row = await ref.read(repositoryProvider).getLedgerById(ledger.id);
      final syncId = row?.syncId;
      if (syncId == null || syncId.isEmpty) {
        if (mounted) {
          showToast(
              context, AppLocalizations.of(context).sharedRequiresCloudSync);
        }
        return;
      }
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MemberStatsPage(
            ledgerExternalId: syncId,
            ledgerName: ledger.name,
          ),
        ));
      }
    } else if (action == 'clear') {
      await _handleClearLedger(context, ledger);
    } else if (action == 'deleteLocal') {
      await _handleDeleteLocalLedgerOnly(context, ledger);
    } else if (action == 'delete') {
      await _handleDeleteLocalLedger(context, ledger);
    }
  }

  /// 显示远程账本操作菜单
  Future<void> _showRemoteLedgerActions(
      BuildContext _, LedgerDisplayItem ledger) async {
    final l = AppLocalizations.of(context);
    final action = await showBeeDialog<String>(context,
        title: l.ledgersActions,
        child: BeeLedgerActions(
            name: translateLedgerName(context, ledger.name),
            subtitle: '${l.ledgersRemote} · ${ledger.currency}',
            details: Text(
                '${l.ledgersRecords('${ledger.transactionCount}')} · ${DateFormat('yyyy-MM-dd HH:mm').format(ledger.lastUpdated.toLocal())}'),
            actions: [
              BeeAction(
                  id: 'download',
                  label: l.ledgersDownload,
                  icon: const BeeLineIcon('CloudDownload')),
              BeeAction(
                  id: 'delete',
                  label: l.ledgersDeleteRemote,
                  icon: const BeeLineIcon('Trash2'),
                  danger: true),
            ],
            onSelected: (id) => Navigator.pop(context, id)));

    if (!mounted) return;

    if (action == 'download') {
      await _handleRemoteLedgerTap(context, ledger);
    } else if (action == 'delete') {
      await _handleDeleteRemoteLedger(context, ledger);
    }
  }

  /// 编辑账本
  Future<void> _handleEditLedger(
      BuildContext _, LedgerDisplayItem ledger) async {
    try {
      final repo = ref.read(repositoryProvider);
      final ledgerData = await repo.getLedgerById(ledger.id);

      if (ledgerData == null || !mounted) return;

      final result = await _showLedgerEditorDialog(
        context,
        title: AppLocalizations.of(context).ledgersEdit,
        initialName: ledgerData.name,
        initialCurrency: ledgerData.currency,
        initialMonthStartDay: ledgerData.monthStartDay,
      );

      if (result == null || !mounted) return;

      // v30 本位币变更:存量交易的 nativeAmount 快照是按旧本位币算的,需按新
      // 本位币全量重算(边界 5,.docs/multi-currency-ledger 02 §八)。先确认再改。
      final currencyChanged =
          result.currency.toUpperCase() != ledgerData.currency.toUpperCase();
      if (currencyChanged) {
        final stats = await repo.getLedgerStats(ledgerId: ledger.id);
        final txCount = stats.transactionCount;
        // 用 State 的 mounted/context:传入的参数 context 可能随编辑入口
        // 弹层一起销毁(mounted=false → 静默 return 会把整个保存吞掉)。
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        final confirmed = await showBeeConfirm(context,
            title: l10n.ledgerBaseCurrencyLabel,
            message:
                '${l10n.ledgerCurrencyChangeRecalcHint}\n${l10n.recalcSyncCountHint(txCount)}',
            cancelLabel: l10n.commonCancel,
            confirmLabel: l10n.commonConfirm);

        if (confirmed != true) return;
      }

      await repo.updateLedger(
        id: ledger.id,
        name: result.name.trim(),
        currency: result.currency,
        monthStartDay: result.monthStartDay,
      );

      if (currencyChanged) {
        // 先强制拉一次「以新主币种为 base」的汇率:改币种瞬间本地通常还没有
        // 这一组(汇率按本位币基准存),不拉的话重算会因缺汇率整体跳过
        // (反馈17:CNY→JPY 后旧交易折算不动)。extraQuotes 带上账本实际涉及
        // 的全部外币(无账户币种不在 usedCurrencies 里)。拉取失败也继续——
        // 缺汇率的笔退化 =amount,由 L11 横幅兜底,绝不保留旧口径错值。
        final foreign = await repo.getLedgerForeignCurrencies(ledger.id);
        await refreshExchangeRatesFromUi(ref,
            force: true,
            extraQuotes: {...foreign, ledgerData.currency.toUpperCase()});
        // 全量重算(逐笔记 change,L13);缺汇率的笔留待 L11 横幅
        final n =
            await repo.recalcNativeAmountsForLedger(ledger.id, result.currency);
        if (mounted && n > 0) {
          showToast(
              context, AppLocalizations.of(context).recalcForeignTxDone(n));
        }
      }

      // 刷新信号必须在 sync 之前发(反馈19):改主币种重算产生几百条 change,
      // push 可能耗时数十秒甚至失败,原先信号排在 await sync 之后导致首页/
      // 账本页统计长时间(或永远)显示旧数据。本地数据此刻已就绪,立即刷新。
      ref.read(ledgerListRefreshProvider.notifier).state++;
      // currentLedgerProvider 已是 StreamProvider(Drift watch 自动推送),
      // 此 invalidate 仅作防御性重订阅(如流曾进入 error 态),正常路径冗余无害。
      ref.invalidate(currentLedgerProvider);
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(budgetRefreshProvider.notifier).state++;

      // 修改账本元数据后,触发同步以更新云端(本地非 tx 写入不会自动 push)。
      // 放刷新信号之后:UI 不等 push 完成;失败也不影响本地展示(下次同步兜底)。
      try {
        await PostProcessor.sync(ref, ledgerId: ledger.id);
      } catch (e) {
        logger.warning('LedgersPage', '改账本元数据后同步失败(本地已生效,下次同步重试): $e');
      }

      // 起始日影响小部件「本月」口径,立即刷新
      try {
        final repository = ref.read(repositoryProvider);
        final redForIncome = ref.read(incomeExpenseColorSchemeProvider);
        // 没有 BuildContext,靠 languageProvider 还原当前 App 语言(见
        // widget_manager.dart resolveWidgetLocalizations 文档)。
        await WidgetManager().updateAllWidgetsLocalized(
          repository,
          ledger.id,
          ref.read(primaryColorProvider),
          explicitLocale: ref.read(languageProvider),
          redForIncome: redForIncome,
          baseCurrency: ref.read(baseCurrencyProvider),
        );
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      await _ledgerError(context,
          title: AppLocalizations.of(context).commonFailed, message: '$e');
    }
  }

  /// 清空 / 删除账本后,精准清理该账本关联的附件物理文件(best-effort)。
  /// 清空(clearLedgerTransactions)和删账本(deleteLedger)走批量 SQL 删行,
  /// 只删 DB 行不删物理文件;调用方在删除前先收集该账本的 fileName 传入。
  /// 按引用计数删除:其他账本/交易仍引用同一 fileName 的不会被误删。
  Future<void> _cleanupLedgerAttachmentFiles(List<String> fileNames) async {
    if (fileNames.isEmpty) return;
    try {
      await ref
          .read(attachmentServiceProvider)
          .deletePhysicalFilesIfUnreferenced(fileNames);
    } catch (e) {
      logger.warning('ledger', '清理账本附件文件失败（忽略）：$e');
    }
  }

  /// 清空账本（删除所有账单，保留账本）
  Future<void> _handleClearLedger(
      BuildContext _, LedgerDisplayItem ledger) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmLedger(
      context,
      danger: true,
      title: l10n.ledgersClearTitle,
      message:
          l10n.ledgersClearMessage(translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);

      // 删账单前先收集该账本附件 fileName(删行后就查不到了)
      final attachmentFiles =
          await repo.getAttachmentFileNamesByLedger(ledger.id);
      // 删除该账本的所有账单(批量删行不删物理文件)
      await repo.clearLedgerTransactions(ledger.id);
      // 删行后精准清理这些附件的物理文件(引用计数)
      await _cleanupLedgerAttachmentFiles(attachmentFiles);

      if (!mounted) return;

      // 清空缓存的交易数据（避免首页使用旧缓存）
      ref.read(cachedTransactionsProvider.notifier).state = null;

      // 触发同步状态刷新
      await PostProcessor.sync(ref, ledgerId: ledger.id);
      if (!mounted) return;

      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      showToast(context, l10n.ledgersClearSuccess);
    } catch (e) {
      if (!mounted) return;
      await _ledgerError(
        context,
        title: l10n.commonFailed,
        message: '$e',
      );
    }
  }

  /// 仅删除本地账本（保留云端备份）
  Future<void> _handleDeleteLocalLedgerOnly(
      BuildContext _, LedgerDisplayItem ledger) async {
    final l10n = AppLocalizations.of(context);

    final repo = ref.read(repositoryProvider);
    final allLedgers = await repo.getAllLedgers();
    if (!mounted) return;

    final confirmed = await _confirmLedger(
      context,
      danger: true,
      title: l10n.ledgersDeleteLocalTitle,
      message: l10n
          .ledgersDeleteLocalMessage(translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      final current = ref.read(currentLedgerIdProvider);

      // 如果删除的是当前账本,有其他账本就切一下;没有就让 currentLedger 落空
      // (currentLedgerProvider 查不到 ledger 返 null,首页胶囊回到「+ 新建账本」
      // 引导用户重新创建,符合"允许删完所有账本"的语义)。
      if (current == ledger.id) {
        final remainAfterDelete =
            allLedgers.where((l) => l.id != ledger.id).toList();
        if (remainAfterDelete.isNotEmpty) {
          ref.read(currentLedgerIdProvider.notifier).state =
              remainAfterDelete.first.id;
        }
      }

      // 删账本前先收集其附件 fileName(删行后查不到)
      final attachmentFiles =
          await repo.getAttachmentFileNamesByLedger(ledger.id);
      // 只删除本地账本，不删除云端备份
      await repo.deleteLedger(ledger.id);
      await _cleanupLedgerAttachmentFiles(attachmentFiles);

      if (!mounted) return;

      // currentLedgerProvider 已是 StreamProvider(Drift watch 自动推送),
      // 此 invalidate 仅作防御性重订阅(如流曾进入 error 态),正常路径冗余无害。
      ref.invalidate(currentLedgerProvider);
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      showToast(context, l10n.ledgersDeleteLocalSuccess);
    } catch (e) {
      if (!mounted) return;
      await _ledgerError(
        context,
        title: l10n.commonFailed,
        message: '$e',
      );
    }
  }

  /// 删除本地账本
  Future<void> _handleDeleteLocalLedger(
      BuildContext _, LedgerDisplayItem ledger) async {
    final l10n = AppLocalizations.of(context);

    final repo = ref.read(repositoryProvider);
    final allLedgers = await repo.getAllLedgers();
    if (!mounted) return;

    final confirmed = await _confirmLedger(
      context,
      danger: true,
      title: l10n.ledgersDeleteConfirm,
      message: l10n.ledgersDeleteMessage,
    );

    if (confirmed != true || !mounted) return;

    try {
      final sync = ref.read(syncServiceProvider);
      final current = ref.read(currentLedgerIdProvider);
      final deletedLedgerId = ledger.id;

      // 如果删除的是当前账本,有其他账本就切一下;没有就让 currentLedger 落空
      // (首页胶囊会回到「+ 新建账本」引导,允许删完所有账本)
      if (current == deletedLedgerId) {
        final remainAfterDelete =
            allLedgers.where((l) => l.id != deletedLedgerId).toList();
        if (remainAfterDelete.isNotEmpty) {
          ref.read(currentLedgerIdProvider.notifier).state =
              remainAfterDelete.first.id;
        }
      }

      // 先调 deleteRemoteBackup:此刻 ledger 行还在,deleteRemoteBackup 内部能
      // 查到 syncId 构造正确的 storage path。如果放到 deleteLedger 之后,
      // ledger 行已被删,fallback 到 ledger.id.toString() 对 UUID 账本会
      // miss(404),storage 快照清不掉。
      try {
        await sync.deleteRemoteBackup(ledgerId: deletedLedgerId);
      } catch (e) {
        logger.warning('ledger', '删除云端备份失败（忽略）：$e');
      }

      // 删除本地账本(repo.deleteLedger 内部会捕获 syncId,登记
      // ledger_snapshot:delete + 级联 transaction:delete + budget:delete change)
      // 删账本前先收集其附件 fileName(删行后查不到)
      final attachmentFiles =
          await repo.getAttachmentFileNamesByLedger(deletedLedgerId);
      await repo.deleteLedger(deletedLedgerId);
      await _cleanupLedgerAttachmentFiles(attachmentFiles);

      // 显式触发对被删账本的 sync,把 delete change 推到 server 清掉 canonical
      // state。SyncCoordinator 的 ledgerIdResolver 拿的是新切换的 currentLedger,
      // 不会触发被删账本的 sync,不调这里 → delete change 永远 stranded → server
      // 还保留账本和它的全部记录,remote ledgers 列表里还会显示。
      // sync_engine.sync() 内部已对 ledgerRow==null 短路:跳过 hasRemote/fullPush/
      // pull,只走 _push 把 delete change 推上去。
      // ignore: unawaited_futures
      PostProcessor.sync(ref, ledgerId: deletedLedgerId);

      if (!mounted) return;

      // 同 _handleDeleteLocalLedgerOnly:显式 invalidate currentLedgerProvider,
      // 哪怕 ledgerId 没切(没其他账本可切),也得让首页胶囊重读 → 查不到行 →
      // 显示 "+ 新建账本"。
      ref.invalidate(currentLedgerProvider);
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      showToast(context, AppLocalizations.of(context).ledgersDeleted);
    } catch (e) {
      if (!mounted) return;
      await _ledgerError(
        context,
        title: AppLocalizations.of(context).ledgersDeleteFailed,
        message: '$e',
      );
    }
  }

  /// 删除远程账本
  Future<void> _handleDeleteRemoteLedger(
      BuildContext _, LedgerDisplayItem ledger) async {
    final confirmed = await _confirmLedger(
      context,
      danger: true,
      title: AppLocalizations.of(context).ledgersDeleteRemoteConfirm,
      message: AppLocalizations.of(context).ledgersDeleteRemoteMessage(
          translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      showToast(context, AppLocalizations.of(context).ledgersDeleting);

      final syncService = ref.read(syncServiceProvider);
      if (syncService is! TransactionsSyncManager) {
        throw Exception('Cloud sync not available');
      }

      await syncService.deleteRemoteLedger(
          remotePath: 'ledger_${ledger.id}.json');

      if (!mounted) return;

      ref.read(ledgerListRefreshProvider.notifier).state++;

      showToast(
          context, AppLocalizations.of(context).ledgersDeleteRemoteSuccess);
    } catch (e) {
      if (!mounted) return;
      await _ledgerError(
        context,
        title: AppLocalizations.of(context).commonFailed,
        message: '$e',
      );
    }
  }

  /// 批量恢复所有远程账本
  Future<void> _handleBatchRestore(BuildContext _) async {
    // 获取远程账本数量
    final remoteLedgersAsync = ref.read(remoteLedgersProvider);
    final remoteLedgers = remoteLedgersAsync.value ?? [];

    final confirmed = await _confirmLedger(
      context,
      title: AppLocalizations.of(context).ledgersRestoreAllTitle,
      message: AppLocalizations.of(context)
          .ledgersRestoreAllMessage(remoteLedgers.length),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);

    try {
      showToast(context, AppLocalizations.of(context).ledgersRestoring);

      final syncService = ref.read(syncServiceProvider);
      int success = 0;
      int failed = 0;
      if (syncService is SyncEngine) {
        // BeeCount Cloud 批量（sync_changes 日志模型）：
        // 1) syncLedgersFromServer 把所有 remote-only ledger 插到本地
        // 2) replayAllChanges 一次性从 cursor=0 重拉历史 sync_changes，apply
        //    按 entity_sync_id 幂等 upsert，把所有账本的历史统一刷回来
        // 不走 `_fullPull` 的 JSON snapshot 下载 —— 那是 S3/WebDAV 的模型。
        await syncService.syncLedgersFromServer();
        try {
          await syncService.replayAllChanges();
          success = remoteLedgers.length;
        } catch (e, st) {
          logger.warning('LedgersPage', '批量恢复远程账本失败: $e', st);
          failed = remoteLedgers.length;
        }
      } else if (syncService is TransactionsSyncManager) {
        final result = await syncService.restoreAllRemoteLedgers();
        success = result.success;
        failed = result.failed;
      } else {
        throw Exception('Cloud sync not available');
      }

      if (!mounted) return;

      setState(() => _isRestoring = false);

      // 刷新列表和同步状态
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(syncStatusRefreshProvider.notifier).state++;

      // 显示结果
      await _ledgerInfo(
        context,
        title: AppLocalizations.of(context).ledgersRestoreComplete,
        message: AppLocalizations.of(context).ledgersRestoreResult(
          success,
          failed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRestoring = false);

      await _ledgerError(
        context,
        title: AppLocalizations.of(context).commonFailed,
        message: '$e',
      );
    }
  }

  /// 显示创建账本对话框
  Future<void> _showCreateLedgerDialog(BuildContext _) async {
    final result = await _showLedgerEditorDialog(
      context,
      title: AppLocalizations.of(context).ledgersNew,
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      final newLedgerId =
          await ref.read(databaseProvider).transaction(() async {
        final id = await repo.createLedger(
            name: result.name.trim(), currency: result.currency);
        if (result.monthStartDay != 1) {
          await repo.updateLedger(id: id, monthStartDay: result.monthStartDay);
        }
        return id;
      });

      // 空账本场景(welcome 未勾默认账本 / 老用户导入配置不含账本)进入此页
      // 创建第一个账本时,currentLedgerIdProvider 还指向默认值 1(无效),
      // 必须切到新账本 id 否则首页 header 胶囊继续显示「新建账本」、列表为
      // 空。已有账本时不动 currentLedger,保留用户当前所在账本。
      if (!mounted) return;
      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        ref.read(currentLedgerIdProvider.notifier).state = newLedgerId;
        ref.invalidate(currentLedgerProvider);
      }

      ref.read(ledgerListRefreshProvider.notifier).state++;

      // 显式触发新账本的同步。createLedger 不会切换 currentLedger,所以
      // SyncCoordinator 的 ledgerIdResolver 拿的还是旧账本,新账本的同步永
      // 远不会被自动触发。这里直接对 newLedgerId 调一次 sync,让 server 立
      // 即创建对应账本(走 sync 内的 !hasRemote → fullPush 路径)。
      // 不调的话,要等到用户切到新账本并加第一笔交易才会被动同步,违反"创
      // 建后立即可见"预期。
      // ignore: unawaited_futures
      PostProcessor.sync(ref, ledgerId: newLedgerId);

      if (!mounted) return;
      showToast(context, '账本创建成功');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '创建失败: ${e.toString()}');
    }
  }

  Future<({String name, String currency, int monthStartDay})?>
      _showLedgerEditorDialog(BuildContext _,
          {String? title,
          String? initialName,
          String? initialCurrency,
          int? initialMonthStartDay}) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showDialog<({String name, String currency, int monthStartDay})>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .26),
        builder: (_) => _LedgerEditorDialog(
            title: title,
            name: initialName ?? '',
            currency: initialCurrency ?? 'CNY',
            day: initialMonthStartDay ?? 1));
  }

  /// 显示冲突解决对话框
  Future<void> _showConflictResolutionDialog(
      BuildContext _, LedgerDisplayItem ledger) async {
    final l10n = AppLocalizations.of(context);
    final syncService = ref.read(syncServiceProvider);

    // 获取同步状态详情
    final syncStatus = await syncService.getStatus(ledgerId: ledger.id);

    if (!mounted) return;

    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    var isProcessing = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return BeeDialog(
              showClose: !isProcessing,
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.ledgersConflictTitle)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ledgersConflictMessage,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),

                    // 本地信息
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BeeCardTheme.of(context).soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.ledgersConflictLocalInfo(
                                syncStatus.localCount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.ledgersConflictLocalFingerprint(
                              syncStatus.localFingerprint.substring(
                                  0,
                                  syncStatus.localFingerprint.length
                                      .clamp(0, 8)),
                            ),
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 云端信息
                    if (syncStatus.cloudFingerprint != null &&
                        syncStatus.cloudExportedAt != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BeeCardTheme.of(context).soft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.ledgersConflictRemoteInfo(
                                  syncStatus.cloudCount ?? 0),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.ledgersConflictRemoteUpdated(
                                dateFormat.format(
                                    syncStatus.cloudExportedAt!.toLocal()),
                              ),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.ledgersConflictRemoteFingerprint(
                                syncStatus.cloudFingerprint!.substring(
                                    0,
                                    syncStatus.cloudFingerprint!.length
                                        .clamp(0, 8)),
                              ),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.commonCancel),
                  ),
                  TextButton(
                    onPressed: () async {
                      setState(() => isProcessing = true);
                      try {
                        showToast(context, l10n.ledgersConflictDownloading);
                        final result =
                            await syncService.downloadAndRestoreToCurrentLedger(
                          ledgerId: ledger.id,
                        );

                        if (stateContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (!mounted) return;

                        // 下载完成后，触发刷新状态和账本列表
                        await PostProcessor.sync(ref, ledgerId: ledger.id);
                        if (!mounted) return;

                        // 刷新统计
                        ref.read(statsRefreshProvider.notifier).state++;

                        showToast(
                          context,
                          l10n.ledgersConflictDownloadSuccess(result.inserted),
                        );
                      } catch (e) {
                        if (stateContext.mounted) {
                          setState(() => isProcessing = false);
                          await _ledgerError(
                            stateContext,
                            title: l10n.commonFailed,
                            message: '$e',
                          );
                        }
                      }
                    },
                    child: Text(l10n.ledgersConflictDownload),
                  ),
                  FilledButton(
                    onPressed: () async {
                      setState(() => isProcessing = true);
                      try {
                        showToast(context, l10n.ledgersConflictUploading);
                        await syncService.uploadCurrentLedger(
                            ledgerId: ledger.id);

                        if (stateContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (!mounted) return;

                        // 刷新列表和同步状态
                        ref.read(ledgerListRefreshProvider.notifier).state++;
                        ref.read(syncStatusRefreshProvider.notifier).state++;

                        showToast(context, l10n.ledgersConflictUploadSuccess);
                      } catch (e) {
                        if (stateContext.mounted) {
                          setState(() => isProcessing = false);
                          await _ledgerError(
                            stateContext,
                            title: l10n.commonFailed,
                            message: '$e',
                          );
                        }
                      }
                    },
                    child: Text(l10n.ledgersConflictUpload),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmLedger(BuildContext _,
      {required String title, required String message, bool danger = false}) {
    final l = AppLocalizations.of(context);
    return showBeeConfirm(context,
        title: title,
        message: message.replaceAll(r'\n', '\n'),
        confirmLabel: l.commonConfirm,
        cancelLabel: l.commonCancel,
        danger: danger);
  }

  Future<void> _ledgerError(BuildContext _,
          {required String title, required String message}) async =>
      showBeeDialog<void>(context,
          title: title,
          child: Text(message.replaceAll(r'\n', '\n')),
          actions: [
            BeeButton(
                label: AppLocalizations.of(context).commonOk,
                onPressed: () => Navigator.pop(context))
          ]);
  Future<void> _ledgerInfo(BuildContext _,
          {required String title, required String message}) async =>
      showBeeDialog<void>(context,
          title: title,
          child: Text(message.replaceAll(r'\n', '\n')),
          actions: [
            BeeButton(
                label: AppLocalizations.of(context).commonOk,
                onPressed: () => Navigator.pop(context))
          ]);
}

// The route owns its controller: disposal follows actual unmount rather than a
// timer racing the route transition or system keyboard animation.
class _LedgerEditorDialog extends StatefulWidget {
  const _LedgerEditorDialog(
      {this.title,
      required this.name,
      required this.currency,
      required this.day});
  final String? title;
  final String name, currency;
  final int day;
  @override
  State<_LedgerEditorDialog> createState() => _LedgerEditorDialogState();
}

class _LedgerEditorDialogState extends State<_LedgerEditorDialog> {
  late final controller = TextEditingController(text: widget.name);
  late String currency = widget.currency;
  late int day = widget.day;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(widget.title ?? l.ledgersEdit),
        content: BeeLedgerEditorForm(
            nameController: controller,
            nameLabel: l.ledgersName,
            currencyLabel: l.ledgerBaseCurrencyLabel,
            currency: displayCurrency(currency, context),
            periodLabel: l.ledgersMonthStartDay,
            period: day == 1
                ? l.ledgersMonthStartDayNatural
                : l.ledgersMonthStartDayValue(day),
            onCurrency: () async {
              final code = await showCurrencyPickerSheet(context,
                  selected: currency,
                  primaryColor: Theme.of(context).colorScheme.primary,
                  title: l.ledgersSelectCurrency);
              if (mounted && code != null) setState(() => currency = code);
            },
            onPeriod: () async {
              final selected = await showBeeSheet<int>(context,
                  title: l.ledgersMonthStartDay,
                  child: SingleChildScrollView(
                      child: BeeMonthStartDayGrid(
                          value: day,
                          hint: l.ledgersMonthStartDayHint,
                          onSelected: (day) => Navigator.pop(context, day))));
              if (mounted && selected != null) setState(() => day = selected);
            }),
        actions: [
          BeeButton(
              label: l.commonCancel,
              kind: BeeButtonKind.secondary,
              onPressed: () => Navigator.pop(context)),
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => BeeButton(
                  label: widget.title == l.ledgersNew
                      ? l.ledgersCreate
                      : l.commonSave,
                  onPressed: value.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, (
                            name: value.text.trim(),
                            currency: currency,
                            monthStartDay: day
                          ))))
        ]);
  }
}
