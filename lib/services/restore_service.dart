import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';
import '../utils/logger.dart';
import '../cloud/sync.dart';

class RestoreCheckResult {
  final bool needsRestore;
  final List backups; // 供后续恢复使用
  final String? reason; // 仅用于记录/日志
  const RestoreCheckResult(
      {required this.needsRestore, required this.backups, this.reason});

  static const none = RestoreCheckResult(
    needsRestore: false,
    backups: [],
  );
}

class RestoreService {
  // 内部模型：一个云端账本条目（已标准化）
  static String? _mapGetString(dynamic item, String key) {
    if (item is Map) {
      final v = item[key];
      if (v is String) return v;
      if (v is num) return v.toString();
      return null;
    }
    try {
      final v = (item as dynamic);
      switch (key) {
        case 'path':
          return v.path as String?;
        case 'name':
          return v.name as String?;
        case 'ledgerName':
          return v.ledgerName as String?;
        case 'currency':
          return v.currency as String?;
      }
    } catch (_) {}
    return null;
  }

  static int? _mapGetInt(dynamic item, String key) {
    if (item is Map) {
      final v = item[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    }
    try {
      final v = (item as dynamic);
      if (key == 'count') return v.count as int?;
    } catch (_) {}
    return null;
  }

  static int? _parseRemoteId(dynamic item) {
    final base =
        (_mapGetString(item, 'path') ?? _mapGetString(item, 'name') ?? '')
            .trim();
    final m = RegExp(r'ledger_(\d+)\.json').firstMatch(base);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  static String? _pathOf(dynamic item) =>
      _mapGetString(item, 'path') ?? _mapGetString(item, 'name');

  static String _nameOf(dynamic item, int index) =>
      _mapGetString(item, 'ledgerName') ??
      _mapGetString(item, 'name') ??
      '账本${index + 1}';

  static String? _currencyOf(dynamic item) => _mapGetString(item, 'currency');

  static int? _declaredCountOf(dynamic item) => _mapGetInt(item, 'count');

  /// 仅做判定，不做 UI。严格早退，发现第一处不匹配即返回 needsRestore=true。
  static Future<RestoreCheckResult> checkNeedRestore(WidgetRef ref) async {
    final sync = ref.read(syncServiceProvider);
    try {
      logI('restore', '检测是否需要恢复…');
      final listFn = (sync as dynamic).listRemoteBackups;
      if (listFn == null) return RestoreCheckResult.none;
      final backups = await listFn.call();
      logI('restore', '远端备份条目数: ${backups is List ? backups.length : -1}');
      if (backups is! List || backups.isEmpty) return RestoreCheckResult.none;

      final repo = ref.read(repositoryProvider);
      final existingLedgers = await repo.db.select(repo.db.ledgers).get();
      final idToLedger = {for (final l in existingLedgers) l.id: l};
      final countsList = await Future.wait(existingLedgers.map((l) async {
        final c = await repo.countsForLedger(ledgerId: l.id);
        return MapEntry(l.id, c.txCount);
      }));
      final localCounts = {for (final e in countsList) e.key: e.value};
      final prefs = await SharedPreferences.getInstance();
      final mapStr = prefs.getString('ledger_id_map') ?? '{}';
      final Map<String, dynamic> idMap =
          (jsonDecode(mapStr) as Map).map((k, v) => MapEntry('$k', v));

      // 已由 _parseRemoteId 提供

      if (backups.length != existingLedgers.length) {
        logI('restore',
            '需要恢复：数量不匹配 local=${existingLedgers.length} remote=${backups.length}');
        return RestoreCheckResult(
            needsRestore: true, backups: backups, reason: 'count_mismatch');
      }

      for (final b in backups) {
        final remoteName =
            (b.ledgerName as String?) ?? (b['ledgerName'] as String?);
        final remoteCount =
            (b.count as int?) ?? (b['count'] as int?); // 允许为 null
        final rid = _parseRemoteId(b);
        if (rid == null) {
          logI('restore', '需要恢复：缺少远端ID');
          return RestoreCheckResult(
              needsRestore: true,
              backups: backups,
              reason: 'missing_remote_id');
        }
        final mappedLocalId = idMap['$rid'] as int?;
        if (mappedLocalId == null) {
          logI('restore', '需要恢复：无映射 rid=$rid');
          return RestoreCheckResult(
              needsRestore: true, backups: backups, reason: 'no_mapping');
        }
        final local = idToLedger[mappedLocalId];
        if (local == null) {
          logI('restore', '需要恢复：本地缺少 ledgerId=$mappedLocalId');
          return RestoreCheckResult(
              needsRestore: true, backups: backups, reason: 'local_missing');
        }
        if (remoteName != null && remoteName != local.name) {
          logI('restore', '需要恢复：名称不同 remote=$remoteName local=${local.name}');
          return RestoreCheckResult(
              needsRestore: true, backups: backups, reason: 'name_mismatch');
        }
        // 若远端未提供 count，则跳过“笔数一致性”校验
        if (remoteCount != null &&
            (localCounts[mappedLocalId] ?? 0) != remoteCount) {
          logI('restore',
              '需要恢复：笔数不同 remote=$remoteCount local=${localCounts[mappedLocalId] ?? 0}');
          return RestoreCheckResult(
              needsRestore: true,
              backups: backups,
              reason: 'tx_count_mismatch');
        }
      }

      return RestoreCheckResult.none;
    } catch (e) {
      logW('restore', '检测恢复失败（忽略）：$e');
      return RestoreCheckResult.none;
    }
  }

  /// 后台恢复逻辑（无 UI），进度/汇总通过 provider 暴露。
  static Future<void> startBackgroundRestore(
      List backups, WidgetRef ref) async {
    logI('restore', '开始后台恢复：待处理对象数=${backups.length}');
    final sync = ref.read(syncServiceProvider);
    final repo = ref.read(repositoryProvider);
    final progress = ref.read(cloudRestoreProgressProvider.notifier);
    final summary = ref.read(cloudRestoreSummaryProvider.notifier);
    final logState = ref.read(cloudRestoreLogProvider.notifier);
    void addLog(String msg) {
      final list = List<String>.from(logState.state);
      list.add(msg);
      // 保留最近 500 行，避免内存过大
      final start = list.length > 500 ? list.length - 500 : 0;
      logState.state = list.sublist(start);
    }

    // 标准化列表并初始化进度（先给出总数，避免 UI 显示 0/0）
    final items = <({
      String path,
      int? rid,
      String name,
      String? currency,
      int? declaredCount,
    })>[];
    for (var i = 0; i < backups.length; i++) {
      final b = backups[i];
      final path = _pathOf(b);
      if (path == null || path.isEmpty) {
        addLog('跳过无效备份条目：index=$i 缺少 path');
        continue; // 跳过无效项
      }
      final rid = _parseRemoteId(b);
      final name = _nameOf(b, i);
      final cur = _currencyOf(b);
      final dc = _declaredCountOf(b);
      addLog(
          '规范化：#${i + 1} path=$path rid=${rid ?? '-'} name=$name count=${dc ?? '-'}');
      items.add((
        path: path,
        rid: rid,
        name: name,
        currency: cur,
        declaredCount: dc,
      ));
    }
    addLog('规范化备份列表完成：有效条目=${items.length}');
    // 清理旧的摘要，避免进度页误判为已完成而自动返回
    summary.state = null;
    progress.state = CloudRestoreProgress(
        running: true,
        totalLedgers: items.length,
        currentIndex: 0,
        currentLedgerName: null,
        currentTotal: 0,
        currentDone: 0);
    logState.state = const <String>[];
    addLog('开始恢复：共 ${items.length} 个账本');
    if (items.isEmpty) {
      addLog('无可恢复账本，直接完成');
      summary.state = const CloudRestoreSummary(
        totalLedgers: 0,
        successLedgers: 0,
        failedLedgers: 0,
        totalImported: 0,
        failedDetails: <String>[],
      );
      progress.state = progress.state.copyWith(running: false);
      ref.read(syncStatusRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
      return;
    }
    try {
      final totalLedgers = items.length;
      final existingLedgers = await repo.db.select(repo.db.ledgers).get();
      final nameToId = {for (final l in existingLedgers) l.name: l.id};
      final idToLedger = {for (final l in existingLedgers) l.id: l};
      final countsList = await Future.wait(existingLedgers.map((l) async {
        final c = await repo.countsForLedger(ledgerId: l.id);
        return MapEntry(l.id, c.txCount);
      }));
      final localCounts = {for (final e in countsList) e.key: e.value};
      final usedLedgerIds = <int>{};
      int okLedgers = 0;
      int failLedgers = 0;
      int totalImported = 0;
      final failedDetails = <String>[];
      final prefs = await SharedPreferences.getInstance();
      final mapStr = prefs.getString('ledger_id_map') ?? '{}';
      final Map<String, dynamic> idMap =
          (jsonDecode(mapStr) as Map).map((k, v) => MapEntry('$k', v));
      for (int i = 0; i < totalLedgers; i++) {
        final it = items[i];
        try {
          addLog('[${i + 1}/$totalLedgers] 处理账本：${it.name}');
          final r = await _restoreSingleLedger(
            ref: ref,
            sync: sync,
            repo: repo,
            idMap: idMap,
            idToLedger: idToLedger,
            nameToId: nameToId,
            localCounts: localCounts,
            usedLedgerIds: usedLedgerIds,
            item: it,
            index: i,
            total: totalLedgers,
          );
          if (r.ok) {
            okLedgers++;
            totalImported += r.imported;
            addLog('  完成：导入 ${r.imported} 条');
          } else {
            failLedgers++;
            if (r.failMessage != null) failedDetails.add(r.failMessage!);
            addLog('  失败：${r.failMessage ?? '未知错误'}');
          }
        } catch (e) {
          failLedgers++;
          failedDetails.add('[${it.name}] 失败: $e');
          addLog('  异常：$e');
        }
      }

      await prefs.setString('ledger_id_map', jsonEncode(idMap));
      summary.state = CloudRestoreSummary(
          totalLedgers: totalLedgers,
          successLedgers: okLedgers,
          failedLedgers: failLedgers,
          totalImported: totalImported,
          failedDetails: failedDetails);
      addLog('全部完成：成功 $okLedgers / $totalLedgers，导入 $totalImported 条');
      if (failedDetails.isNotEmpty) {
        addLog('失败账本汇总：');
        for (final d in failedDetails) {
          addLog(' - $d');
        }
      }
      logI('restore',
          '恢复完成：ok=$okLedgers fail=$failLedgers imported=$totalImported');
    } catch (e, st) {
      logE('restore', '云端恢复失败', e, st);
      addLog('恢复失败：$e');
    } finally {
      progress.state = progress.state.copyWith(running: false);
      ref.read(syncStatusRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
    }
  }

  // 单本账本恢复（无重试），明确更新进度供“我的”页面展示
  static Future<({bool ok, int imported, String? failMessage})>
      _restoreSingleLedger({
    required WidgetRef ref,
    required dynamic sync,
    required dynamic repo,
    required Map<String, dynamic> idMap,
    required Map<int, dynamic> idToLedger,
    required Map<String, int> nameToId,
    required Map<int, int> localCounts,
    required Set<int> usedLedgerIds,
    required ({
      String path,
      int? rid,
      String name,
      String? currency,
      int? declaredCount
    }) item,
    required int index,
    required int total,
  }) async {
    final progress = ref.read(cloudRestoreProgressProvider.notifier);
    final logState = ref.read(cloudRestoreLogProvider.notifier);
    void addLog(String msg) {
      final list = List<String>.from(logState.state);
      list.add(msg);
      final start = list.length > 500 ? list.length - 500 : 0;
      logState.state = list.sublist(start);
    }

    // 开始该账本：先设置标题与总数（若服务端声明了 count）
    progress.state = CloudRestoreProgress(
      running: true,
      totalLedgers: total,
      currentIndex: index + 1,
      currentLedgerName: item.name,
      currentTotal: item.declaredCount ?? 0,
      currentDone: 0,
    );
    logI('restore',
        '开始恢复：#${index + 1}/$total ${item.name} path=${item.path} rid=${item.rid}');
    addLog('· 准备下载：${item.path}');

    // 选择目标账本：
    // - 优先复用映射到的本地账本（若未被占用）
    // - 若本地该账本的条数为 0，则直接复用它并填充（即使与远端条数不一致）
    // - 否则仅在名称一致且（如声明了 count 则）笔数一致时复用；不满足则新建
    int targetLedgerId;
    bool reusedLedger = false;
    final rid = item.rid;
    if (rid != null && idMap['$rid'] is int) {
      final mappedId = idMap['$rid'] as int;
      final cand = idToLedger[mappedId];
      final localCount = localCounts[mappedId] ?? 0;
      final nameMatch = cand != null && item.name == cand.name;
      final countMatch = item.declaredCount == null
          ? true
          : (cand != null &&
              (localCounts[mappedId] ?? 0) == item.declaredCount);
      final canReuseWhenZero = cand != null && localCount == 0;
      if (cand != null &&
          !usedLedgerIds.contains(mappedId) &&
          (canReuseWhenZero || (nameMatch && countMatch))) {
        targetLedgerId = mappedId;
        reusedLedger = true;
      } else {
        targetLedgerId = await repo.createLedger(
            name: item.name, currency: item.currency ?? 'CNY');
        nameToId[item.name] = targetLedgerId;
        reusedLedger = false;
      }
    } else {
      // 无映射：若存在同名账本，且本地条数为0且未被占用，则优先复用
      final sameNameId = nameToId[item.name];
      if (sameNameId != null &&
          !usedLedgerIds.contains(sameNameId) &&
          (localCounts[sameNameId] ?? 0) == 0) {
        targetLedgerId = sameNameId;
        reusedLedger = true;
      } else {
        targetLedgerId = await repo.createLedger(
            name: item.name, currency: item.currency ?? 'CNY');
        nameToId[item.name] = targetLedgerId;
        reusedLedger = false;
      }
    }
    usedLedgerIds.add(targetLedgerId);
    if (reusedLedger) {
      final lc = localCounts[targetLedgerId] ?? 0;
      if (lc == 0) {
        addLog('· 复用本地账本（本地为空，直接填充）：${item.name} (#$targetLedgerId)');
      } else {
        addLog('· 复用本地账本：${item.name} (#$targetLedgerId)');
      }
    } else {
      addLog('· 新建本地账本：${item.name} (#$targetLedgerId)');
    }

    // 采用“沿用远端ID”的策略：
    // 若存在 rid 且当前目标账本ID != rid，则：
    // 1) 若本地已有 ledger 占用 rid，则将其迁移到一个新的空闲ID；
    // 2) 将当前目标账本ID迁移为 rid；
    // 3) 更新内存结构/映射/当前账本ID，确保后续上传使用 rid，避免远端备份越积越多。
    if (rid != null && targetLedgerId != rid) {
      try {
        // 1) 释放 rid
        final occupied = idToLedger[rid];
        if (occupied != null) {
          // 选择一个不与已使用集合冲突的新ID
          int newId = await repo.nextFreeLedgerId();
          while (usedLedgerIds.contains(newId) || newId == targetLedgerId) {
            newId += 1;
          }
          await repo.reassignLedgerId(fromId: rid, toId: newId);
          addLog('· 释放远端ID：将本地账本 #$rid 迁移为 #$newId');
          // 更新映射缓存
          final occ = idToLedger.remove(rid);
          if (occ != null) {
            idToLedger[newId] = occ; // 占位引用即可
            // 名称映射
            try {
              final occName = (occ as dynamic).name as String?;
              if (occName != null && nameToId[occName] == rid) {
                nameToId[occName] = newId;
              }
            } catch (_) {}
          }
          final oldCnt = localCounts.remove(rid);
          if (oldCnt != null) localCounts[newId] = oldCnt;
          if (usedLedgerIds.remove(rid)) usedLedgerIds.add(newId);
          // 当前账本若指向 rid，需同步
          try {
            final cur = ref.read(currentLedgerIdProvider);
            if (cur == rid) {
              ref.read(currentLedgerIdProvider.notifier).state = newId;
            }
          } catch (_) {}
        }

        // 2) 将目标账本迁移为 rid
        await repo.reassignLedgerId(fromId: targetLedgerId, toId: rid);
        addLog('· 采用远端ID：将目标账本 #$targetLedgerId 迁移为 #$rid');
        // 更新本地缓存/集合
        final tgt = idToLedger.remove(targetLedgerId);
        if (tgt != null) idToLedger[rid] = tgt;
        nameToId[item.name] = rid;
        final tgtCnt = localCounts.remove(targetLedgerId);
        if (tgtCnt != null) localCounts[rid] = tgtCnt;
        usedLedgerIds.remove(targetLedgerId);
        usedLedgerIds.add(rid);
        // 当前账本若指向旧ID，切换到 rid
        try {
          final cur = ref.read(currentLedgerIdProvider);
          if (cur == targetLedgerId) {
            ref.read(currentLedgerIdProvider.notifier).state = rid;
          }
        } catch (_) {}
        // 让后续流程使用 rid
        targetLedgerId = rid;
      } catch (e) {
        addLog('· 沿用远端ID失败（忽略，继续使用本地ID #$targetLedgerId）：$e');
      }
    }
    // 避免把币种覆盖为 null
    try {
      final cand = (idToLedger[targetLedgerId]);
      final safeCurrency = item.currency ?? (cand?.currency as String?);
      await repo.updateLedger(
          id: targetLedgerId, name: item.name, currency: safeCurrency);
      if (safeCurrency != null) {
        addLog('· 更新账本信息：币种 $safeCurrency');
      }
    } catch (_) {
      await repo.updateLedger(
          id: targetLedgerId, name: item.name, currency: item.currency);
      if (item.currency != null) {
        addLog('· 更新账本信息：币种 ${item.currency}');
      }
    }

    // 下载（无重试）
    final downloadFn = (sync as dynamic).downloadObjectAsString;
    final jsonStr = await downloadFn.call(item.path);
    if (jsonStr is! String) {
      addLog('· 下载失败');
      return (ok: false, imported: 0, failMessage: '[${item.name}] 下载失败');
    }

    // 解析条数，尽量给出准确 currentTotal
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final n = (map['items'] as List?)?.length ?? 0;
      progress.state = progress.state.copyWith(currentTotal: n);
      addLog('· 解析成功：共 $n 条记录');
    } catch (_) {}

    // 导入 + 进度
    final res = await importTransactionsJson(
      repo,
      targetLedgerId,
      jsonStr,
      onProgress: (done, total2) {
        progress.state =
            progress.state.copyWith(currentDone: done, currentTotal: total2);
      },
    );
    addLog('· 导入完成：插入 ${res.inserted} 条，跳过 ${res.skipped} 条');
    progress.state =
        progress.state.copyWith(currentDone: res.inserted + res.skipped);
    await repo.deduplicateLedgerTransactions(targetLedgerId);
    addLog('· 去重完成');
    // 刷新该账本的笔数显示（用于账本页面）
    try {
      ref.invalidate(countsForLedgerProvider(targetLedgerId));
    } catch (_) {}

    if (rid != null) {
      // 此时 targetLedgerId 已尽量等于 rid
      idMap['$rid'] = targetLedgerId;
    }
    try {
      await sync.uploadCurrentLedger(ledgerId: targetLedgerId);
      addLog('· 已回传到云端');
    } catch (e) {
      logW('restore', '上传云端失败（忽略继续）: ledger=$targetLedgerId $e');
      addLog('· 回传失败（忽略）：$e');
    }

    return (
      ok: true,
      imported: res.inserted + res.skipped,
      failMessage: null,
    );
  }
}
