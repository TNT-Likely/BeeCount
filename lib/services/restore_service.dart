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
  /// 仅做判定，不做 UI。严格早退，发现第一处不匹配即返回 needsRestore=true。
  static Future<RestoreCheckResult> checkNeedRestore(WidgetRef ref) async {
    final sync = ref.read(syncServiceProvider);
    try {
      final listFn = (sync as dynamic).listRemoteBackups;
      if (listFn == null) return RestoreCheckResult.none;
      final backups = await listFn.call();
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

      int? parseRemoteId(dynamic item) {
        try {
          final base = ((item.path as String?) ??
                  (item['path'] as String?) ??
                  (item.name as String?) ??
                  (item['name'] as String?) ??
                  '')
              .trim();
          final m = RegExp(r'ledger_(\d+)\.json').firstMatch(base);
          if (m != null) return int.tryParse(m.group(1)!);
        } catch (_) {}
        return null;
      }

      if (backups.length != existingLedgers.length) {
        return RestoreCheckResult(
            needsRestore: true, backups: backups, reason: 'count_mismatch');
      }

      for (final b in backups) {
        final remoteName =
            (b.ledgerName as String?) ?? (b['ledgerName'] as String?);
        final remoteCount = (b.count as int?) ?? (b['count'] as int?) ?? 0;
        final rid = parseRemoteId(b);
        if (rid == null) {
          return RestoreCheckResult(
              needsRestore: true,
              backups: backups,
              reason: 'missing_remote_id');
        }
        final mappedLocalId = idMap['$rid'] as int?;
        if (mappedLocalId == null) {
          return RestoreCheckResult(
              needsRestore: true, backups: backups, reason: 'no_mapping');
        }
        final local = idToLedger[mappedLocalId];
        if (local == null) {
          return RestoreCheckResult(
              needsRestore: true, backups: backups, reason: 'local_missing');
        }
        if (remoteName != null && remoteName != local.name) {
          return RestoreCheckResult(
              needsRestore: true, backups: backups, reason: 'name_mismatch');
        }
        if ((localCounts[mappedLocalId] ?? 0) != remoteCount) {
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
    final sync = ref.read(syncServiceProvider);
    final repo = ref.read(repositoryProvider);
    final progress = ref.read(cloudRestoreProgressProvider.notifier);
    final summary = ref.read(cloudRestoreSummaryProvider.notifier);
    progress.state = const CloudRestoreProgress(
        running: true,
        totalLedgers: 0,
        currentIndex: 0,
        currentLedgerName: null,
        currentTotal: 0,
        currentDone: 0);
    try {
      final totalLedgers = backups.length;
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

      int? parseRemoteId(dynamic item) {
        try {
          final base = ((item.path as String?) ??
                  (item['path'] as String?) ??
                  (item.name as String?) ??
                  (item['name'] as String?) ??
                  '')
              .trim();
          final m = RegExp(r'ledger_(\d+)\.json').firstMatch(base);
          if (m != null) return int.tryParse(m.group(1)!);
        } catch (_) {}
        return null;
      }

      for (int i = 0; i < totalLedgers; i++) {
        final item = backups[i];
        final path = (item.path as String?) ?? (item['path'] as String?);
        final name = (item.ledgerName as String?) ??
            (item['ledgerName'] as String?) ??
            '账本${i + 1}';
        final currency =
            (item.currency as String?) ?? (item['currency'] as String?);
        final count = (item.count as int?) ?? (item['count'] as int?) ?? 0;
        final remoteLedgerId = parseRemoteId(item);

        progress.state = CloudRestoreProgress(
            running: true,
            totalLedgers: totalLedgers,
            currentIndex: i + 1,
            currentLedgerName: name,
            currentTotal: count,
            currentDone: 0);
        if (path == null) {
          failLedgers++;
          failedDetails.add('[$name] 路径缺失');
          continue;
        }

        int targetLedgerId;
        if (remoteLedgerId != null && idMap['$remoteLedgerId'] is int) {
          final mappedId = idMap['$remoteLedgerId'] as int;
          final cand = idToLedger[mappedId];
          final nameMatch = cand != null && name == cand.name;
          final countMatch =
              cand != null && (localCounts[mappedId] ?? 0) == count;
          if (cand != null &&
              !usedLedgerIds.contains(mappedId) &&
              nameMatch &&
              countMatch) {
            targetLedgerId = mappedId;
          } else {
            targetLedgerId = await repo.createLedger(
                name: name, currency: currency ?? 'CNY');
            nameToId[name] = targetLedgerId;
          }
        } else {
          targetLedgerId =
              await repo.createLedger(name: name, currency: currency ?? 'CNY');
          nameToId[name] = targetLedgerId;
        }
        usedLedgerIds.add(targetLedgerId);
        await repo.updateLedger(
            id: targetLedgerId, name: name, currency: currency);

        final downloadFn = (sync as dynamic).downloadObjectAsString;
        String? jsonStr;
        var delay = const Duration(milliseconds: 300);
        for (int attempt = 0; attempt < 3; attempt++) {
          jsonStr = await downloadFn.call(path);
          if (jsonStr is String) break;
          await Future.delayed(delay);
          delay *= 2;
        }
        if (jsonStr is! String) {
          logW('restore', '下载失败，跳过: $path');
          failedDetails.add('[$name] 下载失败');
          failLedgers++;
          continue;
        }
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final items = (map['items'] as List?)?.length ?? 0;
          progress.state = progress.state.copyWith(currentTotal: items);
        } catch (e) {
          failedDetails.add('[$name] 内容解析失败: $e');
          failLedgers++;
          continue;
        }
        final res = await importTransactionsJson(
          repo,
          targetLedgerId,
          jsonStr,
          onProgress: (done, total) {
            progress.state =
                progress.state.copyWith(currentDone: done, currentTotal: total);
          },
        );
        progress.state =
            progress.state.copyWith(currentDone: res.inserted + res.skipped);
        await repo.deduplicateLedgerTransactions(targetLedgerId);
        okLedgers++;
        totalImported += res.inserted + res.skipped;
        if (remoteLedgerId != null) {
          idMap['$remoteLedgerId'] = targetLedgerId;
        }
        try {
          await sync.uploadCurrentLedger(ledgerId: targetLedgerId);
        } catch (e) {
          logW('restore', '上传云端失败（忽略继续）: ledger=$targetLedgerId $e');
        }
      }

      await prefs.setString('ledger_id_map', jsonEncode(idMap));
      summary.state = CloudRestoreSummary(
          totalLedgers: totalLedgers,
          successLedgers: okLedgers,
          failedLedgers: failLedgers,
          totalImported: totalImported,
          failedDetails: failedDetails);
    } catch (e, st) {
      logE('restore', '云端恢复失败', e, st);
    } finally {
      progress.state = progress.state.copyWith(running: false);
      ref.read(syncStatusRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
    }
  }
}
