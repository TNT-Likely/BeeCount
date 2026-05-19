// 共享账本:本地写 tx 后回填创建人 / 编辑人。
// 不阻塞主流程 — auth 取不到 / 单人账本场景静默跳过,不抛错。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/local/local_repository.dart';
import '../../providers.dart';
import '../system/logger_service.dart';

/// 共享账本 tx 作者标记工具。
///
/// 调用场景:
/// - `markCreated`:本地新建 tx 后调,写 createdByUserId + lastEditedByUserId
/// - `markEdited`:本地编辑 tx 后调,只写 lastEditedByUserId(createdByUserId
///   维持 first-write-wins)
///
/// 失败一律 swallow 走 logger.warning — 头像数据不是关键路径,影响仅是 UI
/// 展示稍迟回填(下次 server pull / push 拉回时也会修正)。
class TxAuthorService {
  TxAuthorService._();

  static Future<void> markCreated(WidgetRef ref, int txId) async =>
      _markImpl(ref, txId, isCreate: true);

  static Future<void> markEdited(WidgetRef ref, int txId) async =>
      _markImpl(ref, txId, isCreate: false);

  /// Container variant — service-layer / background 路径用(没 WidgetRef)。
  static Future<void> markCreatedC(ProviderContainer c, int txId) async =>
      _markImplC(c, txId, isCreate: true);

  static Future<void> markEditedC(ProviderContainer c, int txId) async =>
      _markImplC(c, txId, isCreate: false);

  static Future<void> _markImpl(
    WidgetRef ref,
    int txId, {
    required bool isCreate,
  }) async {
    try {
      final cloud = await ref.read(beecountCloudProviderInstance.future);
      if (cloud == null) return;
      final me = await cloud.auth.currentUser;
      final userId = me?.id;
      if (userId == null || userId.isEmpty) return;
      final repo = ref.read(repositoryProvider);
      if (repo is! LocalRepository) return;
      await repo.markTxAuthor(
        txId: txId,
        userId: userId,
        isCreate: isCreate,
      );
    } catch (e, st) {
      logger.error('TxAuthorService',
          'markImpl 失败 txId=$txId isCreate=$isCreate', e, st);
    }
  }

  static Future<void> _markImplC(
    ProviderContainer c,
    int txId, {
    required bool isCreate,
  }) async {
    try {
      final cloud = await c.read(beecountCloudProviderInstance.future);
      if (cloud == null) return;
      final me = await cloud.auth.currentUser;
      final userId = me?.id;
      if (userId == null || userId.isEmpty) return;
      final repo = c.read(repositoryProvider);
      if (repo is! LocalRepository) return;
      await repo.markTxAuthor(
        txId: txId,
        userId: userId,
        isCreate: isCreate,
      );
    } catch (e, st) {
      logger.error('TxAuthorService',
          'markImplC 失败 txId=$txId isCreate=$isCreate', e, st);
    }
  }
}
