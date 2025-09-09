import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as s;

import '../data/db.dart';
import '../data/repository.dart';
import 'auth.dart';
import 'sync.dart';
import '../utils/logger.dart';

class SupabaseSyncService implements SyncService {
  final s.SupabaseClient client;
  final BeeDatabase db;
  final BeeRepository repo;
  final AuthService auth;
  final String bucket;
  final Map<int, SyncStatus> _statusCache = {};
  // 近期上传窗口：上传成功后，在短时间内（避免对象存储/CDN 读到旧版本）直接信任本地指纹为已同步
  final Map<int, _RecentUpload> _recentUpload = {};
  // 本地最近更改时间：用于基于“更新时间”判断方向（本地较新/云端较新）
  final Map<int, DateTime> _recentLocalChangeAt = {};
  SupabaseSyncService({
    required this.client,
    required this.db,
    required this.repo,
    required this.auth,
    this.bucket = 'beecount-backups',
  });

  String _objectPath(String uid, int ledgerId) =>
      'users/$uid/ledger_$ledgerId.json';

  String _fingerprint(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  String _contentFingerprintFromMap(Map<String, dynamic> payload) {
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    final canon = items
        .map((it) => {
              // 固定键顺序，填默认值，避免 null/缺键差异
              'happenedAt': it['happenedAt'] as String? ?? '',
              'type': it['type'] as String? ?? '',
              'amount': (it['amount'] as num?)?.toString() ?? '0',
              'categoryName': it['categoryName'] as String? ?? '',
              'categoryKind': it['categoryKind'] as String? ?? '',
              'note': it['note'] as String? ?? '',
            })
        .toList();
    canon.sort((a, b) {
      final c1 =
          (a['happenedAt'] as String).compareTo(b['happenedAt'] as String);
      if (c1 != 0) return c1;
      final c2 = (a['type'] as String).compareTo(b['type'] as String);
      if (c2 != 0) return c2;
      final c3 = (a['amount'] as String).compareTo(b['amount'] as String);
      if (c3 != 0) return c3;
      final c4 =
          (a['categoryName'] as String).compareTo(b['categoryName'] as String);
      if (c4 != 0) return c4;
      final c5 =
          (a['categoryKind'] as String).compareTo(b['categoryKind'] as String);
      if (c5 != 0) return c5;
      return (a['note'] as String).compareTo(b['note'] as String);
    });
    return _fingerprint(jsonEncode(canon));
  }

  DateTime? _maxHappenedAt(Map<String, dynamic> payload) {
    DateTime? maxAt;
    for (final it in (payload['items'] as List).cast<Map<String, dynamic>>()) {
      final s = it['happenedAt'] as String?;
      if (s == null) continue;
      final dt = DateTime.tryParse(s);
      if (dt == null) continue;
      if (maxAt == null || dt.isAfter(maxAt)) maxAt = dt;
    }
    return maxAt;
  }

  // 兼容历史备份（可能以 UTF-16 方式写入），优先 UTF-8，失败则回退到 fromCharCodes
  String _decodeBytesCompat(Uint8List data) {
    try {
      return utf8.decode(data);
    } catch (_) {
      try {
        return String.fromCharCodes(data);
      } catch (e) {
        rethrow;
      }
    }
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    final user = await auth.currentUser();
    if (user == null) {
      throw StateError('请先登录后再同步');
    }
    final jsonStr = await exportTransactionsJson(db, ledgerId);
    // 计算本地指纹（用于对比/缓存）
    String? localFp;
    int? localCount;
    DateTime? localMaxAt;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      localFp = _contentFingerprintFromMap(map);
      localCount = (map['count'] as num?)?.toInt() ?? 0;
      localMaxAt = _maxHappenedAt(map);
      logI('sync', '上传前本地指纹: 指纹=$localFp 条数=$localCount 时间=$localMaxAt');
    } catch (e) {
      logW('sync', '上传前本地指纹解析失败: $e');
    }
    // 写入导出时间（用于云端“更新时间”判断）。向后兼容：导入逻辑可忽略未知键。
    Uint8List bytes;
    try {
      final base = jsonDecode(jsonStr) as Map<String, dynamic>;
      base['exportedAt'] = DateTime.now().toUtc().toIso8601String();
      bytes = Uint8List.fromList(utf8.encode(jsonEncode(base)));
    } catch (_) {
      // 回退原始字节
      bytes = Uint8List.fromList(utf8.encode(jsonStr));
    }
    final path = _objectPath(user.id, ledgerId);
    logI('sync', '上传: 桶=$bucket 路径=$path 用户=${user.id}');
    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const s.FileOptions(
                upsert: true, contentType: 'application/json'),
          );
      // 记录近期上传，并“立即将云端视为与本地一致”，提升实时性
      if (localFp != null && localCount != null) {
        _recentUpload[ledgerId] = _RecentUpload(
          at: DateTime.now(),
          fp: localFp,
          count: localCount,
          maxAt: localMaxAt,
        );
        _statusCache[ledgerId] = SyncStatus(
          diff: SyncDiff.inSync,
          localCount: localCount,
          localFingerprint: localFp,
          cloudCount: localCount,
          cloudFingerprint: localFp,
          cloudExportedAt: localMaxAt,
        );
      } else {
        // 若解析失败，仅清理状态缓存，后续由轮询兜底
        _statusCache.remove(ledgerId);
      }
    } on s.StorageException catch (e) {
      // 常见为 403（RLS 拒绝），给出指导
      if ('${e.statusCode}' == '403') {
        throw StateError(
            '云端拒绝写入 (403)。请在 Supabase 的 storage.objects 上添加 INSERT/UPDATE 策略：\n'
            "bucket_id = '$bucket' AND (storage.foldername(name))[1] = 'users' AND (storage.foldername(name))[2] = auth.uid()::text\n"
            '并确认对象路径为 users/<uid>/... 当前: $path');
      }
      rethrow;
    }
  }

  @override
  Future<({int inserted, int skipped, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    final user = await auth.currentUser();
    if (user == null) {
      throw StateError('请先登录后再同步');
    }
    final path = _objectPath(user.id, ledgerId);
    logI('sync', '下载: 桶=$bucket 路径=$path 用户=${user.id}');
    Uint8List data;
    try {
      data = await client.storage.from(bucket).download(path);
    } on s.StorageException catch (e) {
      if ('${e.statusCode}' == '404') {
        // 对象不存在：创建一个空的备份对象，随后返回“无可恢复”
        final emptyJson = jsonEncode({
          'count': 0,
          'items': <Map<String, dynamic>>[],
        });
        final bytes = Uint8List.fromList(utf8.encode(emptyJson));
        await client.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: const s.FileOptions(
                  upsert: true, contentType: 'application/json'),
            );
        // 无任何可导入内容，直接返回空变更
        return (inserted: 0, skipped: 0, deletedDup: 0);
      }
      rethrow;
    }
    final jsonStr = _decodeBytesCompat(data);
    final imported = await importTransactionsJson(repo, ledgerId, jsonStr);
    // 二次去重，清理历史重复
    final deleted = await repo.deduplicateLedgerTransactions(ledgerId);
    // invalidate cache after restore
    _statusCache.remove(ledgerId);
    _recentUpload.remove(ledgerId);
    return (
      inserted: imported.inserted,
      skipped: imported.skipped,
      deletedDup: deleted
    );
  }

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    // return cached if available
    final cached = _statusCache[ledgerId];
    if (cached != null) return cached;
    try {
      final user = await auth.currentUser();
      if (user == null) {
        // 本地指纹
        final local = await exportTransactionsJson(db, ledgerId);
        final st = SyncStatus(
          diff: SyncDiff.notLoggedIn,
          localCount: (jsonDecode(local)['count'] as num).toInt(),
          localFingerprint: _fingerprint(local),
          message: '未登录',
        );
        _statusCache[ledgerId] = st;
        return st;
      }

      // 本地
      final local = await exportTransactionsJson(db, ledgerId);
      final localMap = jsonDecode(local) as Map<String, dynamic>;
      final localFp = _contentFingerprintFromMap(localMap);
      final localCount = (localMap['count'] as num).toInt();
      logI('sync', '获取状态 本地: 指纹=$localFp 条数=$localCount');
      // 本地“更新时间”：优先使用最近更改时间（由 markLocalChanged 记录），否则回退到内容最大发生时间
      final localUpdatedAt =
          _recentLocalChangeAt[ledgerId] ?? _maxHappenedAt(localMap);

      // 若刚刚上传成功且在短时间窗口内，并且本地指纹与上传时一致，则直接认定已同步
      final ru = _recentUpload[ledgerId];
      if (ru != null) {
        final age = DateTime.now().difference(ru.at);
        if (age < const Duration(seconds: 15) && ru.fp == localFp) {
          final st = SyncStatus(
            diff: SyncDiff.inSync,
            localCount: localCount,
            localFingerprint: localFp,
            cloudCount: ru.count,
            cloudFingerprint: ru.fp,
            cloudExportedAt: ru.maxAt,
          );
          _statusCache[ledgerId] = st;
          return st;
        }
      }

      // 远端
      final path = _objectPath(user.id, ledgerId);
      try {
        final data = await client.storage.from(bucket).download(path);
        final remote = _decodeBytesCompat(data);
        Map<String, dynamic> map;
        try {
          map = jsonDecode(remote) as Map<String, dynamic>;
        } on FormatException {
          return SyncStatus(
            diff: SyncDiff.error,
            localCount: localCount,
            localFingerprint: localFp,
            message: '云端备份内容无法解析，可能是早期版本编码问题造成的损坏。请点击“上传当前账本到云端”覆盖修复。',
          );
        }
        final remoteFp = _contentFingerprintFromMap(map);
        final remoteCount = (map['count'] as num?)?.toInt();
        // 云端“更新时间”：优先使用导出时间 exportedAt，否则回退到内容最大发生时间
        DateTime? remoteAt;
        final exportedAtStr = map['exportedAt'] as String?;
        if (exportedAtStr != null) {
          remoteAt = DateTime.tryParse(exportedAtStr);
        }
        remoteAt ??= _maxHappenedAt(map);
        logI('sync', '获取状态 云端: 指纹=$remoteFp 条数=$remoteCount 时间=$remoteAt');

        // 对比
        if (remoteFp == localFp) {
          final st = SyncStatus(
            diff: SyncDiff.inSync,
            localCount: localCount,
            localFingerprint: localFp,
            cloudCount: remoteCount,
            cloudFingerprint: remoteFp,
            cloudExportedAt: remoteAt,
          );
          logI('sync', '获取状态: 已同步');
          _statusCache[ledgerId] = st;
          return st;
        }

        // 用“更新时间”（本地 recentChangeAt / 云端 exportedAt）判断方向，若缺失则仅提示不同
        if (remoteAt != null && localUpdatedAt != null) {
          if (localUpdatedAt.isAfter(remoteAt)) {
            final st = SyncStatus(
              diff: SyncDiff.localNewer,
              localCount: localCount,
              localFingerprint: localFp,
              cloudCount: remoteCount,
              cloudFingerprint: remoteFp,
              cloudExportedAt: remoteAt,
            );
            logI('sync', '获取状态: 本地较新');
            _statusCache[ledgerId] = st;
            return st;
          } else if (remoteAt.isAfter(localUpdatedAt)) {
            final st = SyncStatus(
              diff: SyncDiff.cloudNewer,
              localCount: localCount,
              localFingerprint: localFp,
              cloudCount: remoteCount,
              cloudFingerprint: remoteFp,
              cloudExportedAt: remoteAt,
            );
            logI('sync', '获取状态: 云端较新');
            _statusCache[ledgerId] = st;
            return st;
          }
        }
        final st = SyncStatus(
          diff: SyncDiff.different,
          localCount: localCount,
          localFingerprint: localFp,
          cloudCount: remoteCount,
          cloudFingerprint: remoteFp,
          cloudExportedAt: remoteAt,
        );
        logI('sync', '获取状态: 本地与云端不同');
        _statusCache[ledgerId] = st;
        return st;
      } on s.StorageException catch (e) {
        if ('${e.statusCode}' == '404') {
          final st = SyncStatus(
            diff: SyncDiff.noRemote,
            localCount: localCount,
            localFingerprint: localFp,
            message: '云端暂无备份',
          );
          logI('sync', '获取状态: 云端暂无备份');
          _statusCache[ledgerId] = st;
          return st;
        }
        if ('${e.statusCode}' == '403') {
          final st = SyncStatus(
            diff: SyncDiff.error,
            localCount: localCount,
            localFingerprint: localFp,
            message: '403 拒绝访问（检查 storage RLS 策略与路径）',
          );
          logW('sync', '获取状态: 403 拒绝访问');
          _statusCache[ledgerId] = st;
          return st;
        }
        rethrow;
      }
    } catch (e) {
      final st = SyncStatus(
        diff: SyncDiff.error,
        localCount: 0,
        localFingerprint: '',
        message: '$e',
      );
      logE('sync', '获取状态: 异常 $e');
      _statusCache[ledgerId] = st;
      return st;
    }
  }

  @override
  void markLocalChanged({required int ledgerId}) {
    _statusCache.remove(ledgerId);
    _recentLocalChangeAt[ledgerId] = DateTime.now();
    // 不立即清除 _recentUpload，让“上传后短窗”继续生效，避免瞬时误判
  }

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    final user = await auth.currentUser();
    if (user == null) {
      return (fingerprint: null, count: null, exportedAt: null);
    }
    final path = _objectPath(user.id, ledgerId);
    logI('sync', '刷新云端指纹: 桶=$bucket 路径=$path 用户=${user.id}');
    try {
      final data = await client.storage.from(bucket).download(path);
      final remote = _decodeBytesCompat(data);
      Map<String, dynamic> map;
      try {
        map = jsonDecode(remote) as Map<String, dynamic>;
      } on FormatException {
        logW('sync', '刷新云端指纹解析失败：非 JSON 内容');
        return (fingerprint: null, count: null, exportedAt: null);
      }
      final fp = _contentFingerprintFromMap(map);
      final cnt = (map['count'] as num?)?.toInt();
      final at = _maxHappenedAt(map);
      logI('sync', '刷新云端指纹成功: 指纹=$fp 条数=$cnt 时间=$at');
      // 若与本地一致，直接更新缓存为已同步，帮助 UI 立即显示正确结果
      try {
        final local = await exportTransactionsJson(db, ledgerId);
        final localMap = jsonDecode(local) as Map<String, dynamic>;
        final localFp = _contentFingerprintFromMap(localMap);
        final localCount = (localMap['count'] as num).toInt();
        if (localFp == fp) {
          final st = SyncStatus(
            diff: SyncDiff.inSync,
            localCount: localCount,
            localFingerprint: localFp,
            cloudCount: cnt,
            cloudFingerprint: fp,
            cloudExportedAt: at,
          );
          _statusCache[ledgerId] = st;
        }
      } catch (_) {}
      return (fingerprint: fp, count: cnt, exportedAt: at);
    } on s.StorageException catch (e) {
      logW('sync', '刷新云端指纹错误: 状态码=${e.statusCode} 信息=${e.message}');
      return (fingerprint: null, count: null, exportedAt: null);
    } catch (e) {
      logE('sync', '刷新云端指纹错误: $e');
      return (fingerprint: null, count: null, exportedAt: null);
    }
  }
}

class _RecentUpload {
  final DateTime at;
  final String fp;
  final int count;
  final DateTime? maxAt;
  _RecentUpload({
    required this.at,
    required this.fp,
    required this.count,
    required this.maxAt,
  });
}
