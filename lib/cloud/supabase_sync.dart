import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as s;

import '../data/db.dart';
import '../data/repository.dart';
import 'auth.dart';
import 'sync.dart';

class SupabaseSyncService implements SyncService {
  final s.SupabaseClient client;
  final BeeDatabase db;
  final BeeRepository repo;
  final AuthService auth;
  final String bucket;
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
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    final path = _objectPath(user.id, ledgerId);
    debugPrint('[sync] upload -> bucket=$bucket path=$path uid=${user.id}');
    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const s.FileOptions(
                upsert: true, contentType: 'application/json'),
          );
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
    debugPrint('[sync] download -> bucket=$bucket path=$path uid=${user.id}');
    final data = await client.storage.from(bucket).download(path);
    final jsonStr = _decodeBytesCompat(data);
    final imported = await importTransactionsJson(repo, ledgerId, jsonStr);
    // 二次去重，清理历史重复
    final deleted = await repo.deduplicateLedgerTransactions(ledgerId);
    return (
      inserted: imported.inserted,
      skipped: imported.skipped,
      deletedDup: deleted
    );
  }

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    try {
      final user = await auth.currentUser();
      if (user == null) {
        // 本地指纹
        final local = await exportTransactionsJson(db, ledgerId);
        return SyncStatus(
          diff: SyncDiff.notLoggedIn,
          localCount: (jsonDecode(local)['count'] as num).toInt(),
          localFingerprint: _fingerprint(local),
          message: '未登录',
        );
      }

      // 本地
      final local = await exportTransactionsJson(db, ledgerId);
      final localMap = jsonDecode(local) as Map<String, dynamic>;
      final localFp = _contentFingerprintFromMap(localMap);
      final localCount = (localMap['count'] as num).toInt();

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
        final remoteAt = _maxHappenedAt(map);

        // 对比
        if (remoteFp == localFp) {
          return SyncStatus(
            diff: SyncDiff.inSync,
            localCount: localCount,
            localFingerprint: localFp,
            cloudCount: remoteCount,
            cloudFingerprint: remoteFp,
            cloudExportedAt: remoteAt,
          );
        }

        // 用导出时间粗略判断方向，若缺失则仅提示不同
        if (remoteAt != null) {
          final localAt = _maxHappenedAt(localMap);
          if (localAt != null) {
            if (localAt.isAfter(remoteAt)) {
              return SyncStatus(
                diff: SyncDiff.localNewer,
                localCount: localCount,
                localFingerprint: localFp,
                cloudCount: remoteCount,
                cloudFingerprint: remoteFp,
                cloudExportedAt: remoteAt,
              );
            } else if (remoteAt.isAfter(localAt)) {
              return SyncStatus(
                diff: SyncDiff.cloudNewer,
                localCount: localCount,
                localFingerprint: localFp,
                cloudCount: remoteCount,
                cloudFingerprint: remoteFp,
                cloudExportedAt: remoteAt,
              );
            }
          }
        }
        return SyncStatus(
          diff: SyncDiff.different,
          localCount: localCount,
          localFingerprint: localFp,
          cloudCount: remoteCount,
          cloudFingerprint: remoteFp,
          cloudExportedAt: remoteAt,
        );
      } on s.StorageException catch (e) {
        if ('${e.statusCode}' == '404') {
          return SyncStatus(
            diff: SyncDiff.noRemote,
            localCount: localCount,
            localFingerprint: localFp,
            message: '云端暂无备份',
          );
        }
        if ('${e.statusCode}' == '403') {
          return SyncStatus(
            diff: SyncDiff.error,
            localCount: localCount,
            localFingerprint: localFp,
            message: '403 拒绝访问（检查 storage RLS 策略与路径）',
          );
        }
        rethrow;
      }
    } catch (e) {
      return SyncStatus(
        diff: SyncDiff.error,
        localCount: 0,
        localFingerprint: '',
        message: '$e',
      );
    }
  }
}
