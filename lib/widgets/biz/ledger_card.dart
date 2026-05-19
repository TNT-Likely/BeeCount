/// 账本卡片组件
///
/// 展示账本基本信息，同步状态通过 syncStatusProvider 单独获取
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ledger_display_item.dart';
import '../../cloud/sync_service.dart';
import '../../providers/theme_providers.dart';
import '../../providers/sync_providers.dart';
import '../../utils/format_utils.dart';
import '../../utils/currencies.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';

/// 账本卡片
class LedgerCard extends ConsumerWidget {
  final LedgerDisplayItem ledger;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const LedgerCard({
    super.key,
    required this.ledger,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);

    // 获取同步状态
    final syncStatusAsync = ref.watch(syncStatusProvider(ledger.id));
    final syncStatus = syncStatusAsync.valueOrNull;

    // 检查是否正在上传
    final uploadingIds = ref.watch(uploadingLedgerIdsProvider);
    final isUploading = !ledger.isRemoteOnly && uploadingIds.contains(ledger.id);

    // 判断同步状态
    final isRemote = ledger.isRemoteOnly;
    final isSynced = syncStatus?.diff == SyncDiff.inSync;

    // 非同步状态：除了inSync和noRemote之外的所有状态
    final isNotSynced = syncStatus != null &&
        syncStatus.diff != SyncDiff.inSync &&
        syncStatus.diff != SyncDiff.noRemote &&
        syncStatus.diff != SyncDiff.notConfigured;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: BeeTokens.isDark(context)
              ? Border.all(color: BeeTokens.border(context), width: 1)
              : null,
          boxShadow: BeeTokens.isDark(context)
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 左侧色条：仅选中时显示
              if (selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                ),

              // 底层：账本信息（始终显示）
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部：名称 + 状态图标
                    Row(
                      children: [
                        // 账本名称
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: translateLedgerName(context, ledger.name),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: BeeTokens.textPrimary(context),
                                  ),
                                ),
                                TextSpan(
                                  text: ' (ID:${ledger.id})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isRemote
                                        ? primaryColor.withValues(alpha: 0.8)
                                        : BeeTokens.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // v24: 共享账本 🤝 角标 + 成员数
                        if (ledger.isShared) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.handshake,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${ledger.memberCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                            ),
                          ),
                        ],

                        const SizedBox(width: 8),

                        // 状态图标
                        _buildStatusIcon(
                          context,
                          ref,
                          primaryColor,
                          isSynced,
                          isNotSynced,
                          isRemote,
                          isUploading,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 统计数据（本地和远程都显示）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 币种
                        Text(
                          '${l10n.ledgersCurrency}：${getCurrencyName(ledger.currency, context)}（${ledger.currency}）',
                          style: TextStyle(
                            fontSize: 14,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 记账笔数
                        Text(
                          l10n.ledgersRecords('${ledger.transactionCount}'),
                          style: TextStyle(
                            fontSize: 14,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 余额（根据设置使用简洁或完整格式）
                        Text(
                          l10n.ledgersBalance(
                            ref.watch(compactAmountProvider)
                              ? formatBalance(
                                  ledger.balance,
                                  ledger.currency,
                                  isChineseLocale: Localizations.localeOf(context).languageCode == 'zh',
                                )
                              : formatBalanceFull(ledger.balance, ledger.currency),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: ledger.balance >= 0 ? BeeTokens.success(context) : BeeTokens.error(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 蒙层：仅远程账本显示
              if (isRemote)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: BeeTokens.surface(context).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_download,
                          size: 48,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.ledgerCardDownloadCloud,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 状态图标
  Widget _buildStatusIcon(
    BuildContext context,
    WidgetRef ref,
    Color primaryColor,
    bool isSynced,
    bool isNotSynced,
    bool isRemote,
    bool isUploading,
  ) {
    // 优先显示上传中状态
    if (isUploading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
        ),
      );
    }

    if (isRemote) {
      // 远程账本：云下载图标
      return Icon(
        Icons.cloud_download,
        color: primaryColor,
        size: 20,
      );
    } else if (isSynced) {
      // 已同步：绿色云勾选图标
      return const Icon(
        Icons.cloud_done,
        color: Colors.green,
        size: 20,
      );
    } else if (isNotSynced) {
      // 未同步（包括：localNewer、cloudNewer、different、error、notLoggedIn）：红色云图标
      return const Icon(
        Icons.cloud_off,
        color: Colors.red,
        size: 20,
      );
    } else {
      // 纯本地账本（离线模式/未配置）：灰色云关闭图标
      return const Icon(
        Icons.cloud_off,
        color: Colors.grey,
        size: 20,
      );
    }
  }

}
