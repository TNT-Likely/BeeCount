import 'dart:typed_data';
import 'package:flutter/foundation.dart';

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

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    final user = await auth.currentUser();
    if (user == null) {
      throw StateError('请先登录后再同步');
    }
    final jsonStr = await exportTransactionsJson(db, ledgerId);
    final bytes = Uint8List.fromList(jsonStr.codeUnits);
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
      if (e.statusCode == 403) {
        throw StateError(
            '云端拒绝写入 (403)。请在 Supabase 的 storage.objects 上添加 INSERT/UPDATE 策略：\n'
            "bucket_id = '$bucket' AND (storage.foldername(name))[1] = 'users' AND (storage.foldername(name))[2] = auth.uid()::text\n"
            '并确认对象路径为 users/<uid>/... 当前: $path');
      }
      rethrow;
    }
  }

  @override
  Future<int> downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    final user = await auth.currentUser();
    if (user == null) {
      throw StateError('请先登录后再同步');
    }
    final path = _objectPath(user.id, ledgerId);
    debugPrint('[sync] download -> bucket=$bucket path=$path uid=${user.id}');
    final data = await client.storage.from(bucket).download(path);
    final jsonStr = String.fromCharCodes(data);
    final count = await importTransactionsJson(repo, ledgerId, jsonStr);
    return count;
  }
}
