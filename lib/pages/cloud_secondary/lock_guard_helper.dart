/// 锁账体验层助手(0067)。
///
/// 服务端 lock_guard 已在投影层强制拦截(423)，这里只做前端体验：
/// 在用户执行编辑/复制/删除前查询一次锁账配置，命中则友好提示。
/// 用 ref.read(非 watch)避免每个交易行都发网络请求。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/secondary/cloud_secondary_service.dart';

import '../../providers/cloud_secondary_providers.dart';

class LockGuardHelper {
  LockGuardHelper._();

  /// 该交易时间是否落在锁定期。查询失败一律当作未锁定(不影响离线使用)。
  static Future<bool> isTxLocked(WidgetRef ref, DateTime happenedAt) async {
    try {
      final service = await ref.read(cloudSecondaryServiceProvider.future);
      if (service == null) return false;
      final settings = await service.lockSettings();
      if (settings['is_locked'] != true) return false;
      final lockDate = settings['lock_date'] as String?;
      return CloudSecondaryService.isLocked(lockDate, happenedAt);
    } catch (_) {
      return false; // 离线/老服务端无锁账端点 → 不阻塞
    }
  }
}
