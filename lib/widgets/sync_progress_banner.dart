import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/sync/sync_engine.dart';
import '../providers/sync_providers.dart';
import '../styles/tokens.dart';

/// 同步进度浮层 — 订阅 `syncProgressProvider`,显示在 HomePage 顶部
/// (PrimaryHeader 之下,内容之上)。
///
/// 行为:
/// - null progress → 不渲染(SizedBox.shrink)
/// - applying 阶段 → LinearProgressIndicator + "已处理 X / Y 条"
/// - pushing / pulling / fetchingLedgers → indeterminate spinner + stage 描述
/// - finished + error → 红色错误条,2 秒后被 provider 自动清空
/// - finished + 成功 → 短暂绿条 "同步完成 N 条",1.5 秒后被 provider 自动清空
class SyncProgressBanner extends ConsumerWidget {
  const SyncProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(syncProgressProvider);
    if (p == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _Banner(progress: p, key: ValueKey(p.stage)),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.progress, super.key});

  final SyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final isFinished = progress.stage == SyncProgressStage.finished;
    final hasError = progress.error != null;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final Color bg;
    final Color fg;
    final Color barColor;
    if (hasError) {
      final error = BeeTokens.error(context);
      bg = error.withValues(alpha: 0.10);
      fg = error;
      barColor = error;
    } else if (isFinished) {
      final success = BeeTokens.success(context);
      bg = success.withValues(alpha: 0.10);
      fg = success;
      barColor = success;
    } else {
      bg = primary.withValues(alpha: 0.10);
      fg = primary;
      barColor = primary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        children: [
          // 左侧状态图标
          SizedBox(
            width: 18,
            height: 18,
            child: hasError
                ? Icon(Icons.error_outline, size: 18, color: fg)
                : isFinished
                    ? Icon(Icons.check_circle_outline, size: 18, color: fg)
                    : CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
          ),
          const SizedBox(width: 10),
          // 中间文案 + 进度条
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(progress, context),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // applying stage 才显示线性进度;其它 stage 只显示文字 +
                // 上面的 spinner,避免无意义的 0% 条出现。
                if (progress.stage == SyncProgressStage.applying &&
                    progress.total > 0) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.fraction.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: barColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 右侧:applying 时显示 X/Y, 其它时显示耗时
          const SizedBox(width: 12),
          Text(
            progress.stage == SyncProgressStage.applying && progress.total > 0
                ? '${progress.applied}/${progress.total}'
                : '${(progress.elapsedMs / 1000).toStringAsFixed(1)}s',
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg.withValues(alpha: 0.8),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// stage / error 派生用户能看懂的文案。
  String _label(SyncProgress p, BuildContext context) {
    if (p.error != null) {
      return '同步失败: ${p.error}';
    }
    switch (p.stage) {
      case SyncProgressStage.fetchingLedgers:
        return '正在拉取账本列表…';
      case SyncProgressStage.pushing:
        return '正在推送本地变更…';
      case SyncProgressStage.pulling:
        return '正在拉取远端变更…';
      case SyncProgressStage.applying:
        return '正在应用变更…';
      case SyncProgressStage.finished:
        if (p.applied > 0) return '同步完成 · ${p.applied} 条';
        return '同步完成';
    }
  }
}
