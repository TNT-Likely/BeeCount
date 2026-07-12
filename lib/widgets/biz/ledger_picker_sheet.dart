import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/ledger_display_item.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../pages/main/ledgers_page_new.dart';

/// 账本选择弹窗组件
///
/// 居中显示的优雅弹窗，用于快速切换账本
class LedgerPickerDialog extends ConsumerWidget {
  const LedgerPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ledgersAsync = ref.watch(localLedgersProvider);
    final currentId = ref.watch(currentLedgerIdProvider);
    final primaryColor = ref.watch(primaryColorProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: BeeTokens.surface(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 320,
          maxHeight: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.homeSwitchLedger,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  // 关闭按钮
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: BeeTokens.scaffoldBackground(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: BeeTokens.iconSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 分割线
            Divider(height: 1, color: BeeTokens.divider(context)),
            // 账本列表
            Flexible(
              child: ledgersAsync.when(
                data: (ledgers) => _buildLedgerList(
                  context,
                  ref,
                  ledgers,
                  currentId,
                  primaryColor,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error: $e',
                    style: TextStyle(color: BeeTokens.textSecondary(context)),
                  ),
                ),
              ),
            ),
            // 底部管理按钮
            Divider(height: 1, color: BeeTokens.divider(context)),
            _buildManageButton(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerList(
    BuildContext context,
    WidgetRef ref,
    List<LedgerDisplayItem> ledgers,
    int currentId,
    Color primaryColor,
  ) {
    if (ledgers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 48,
              color: BeeTokens.iconTertiary(context),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).ledgersEmpty,
              style: TextStyle(color: BeeTokens.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ledgers.length,
      itemBuilder: (context, index) {
        final ledger = ledgers[index];
        final isSelected = ledger.id == currentId;

        return _LedgerItem(
          ledger: ledger,
          isSelected: isSelected,
          primaryColor: primaryColor,
          onTap: () {
            if (!isSelected) {
              ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
            }
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildManageButton(BuildContext context, AppLocalizations l10n) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LedgersPageNew(),
          ),
        );
      },
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_outlined,
              size: 18,
              color: BeeTokens.iconSecondary(context),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.homeManageLedgers,
              style: TextStyle(
                fontSize: 14,
                color: BeeTokens.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账本列表项
class _LedgerItem extends StatelessWidget {
  final LedgerDisplayItem ledger;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _LedgerItem({
    required this.ledger,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
              )
            : null,
        child: Row(
          children: [
            // 选中标记
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryColor : BeeTokens.border(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // 账本信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ledger.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? primaryColor
                          : BeeTokens.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ledger.currency} · ${ledger.transactionCount} 笔',
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 显示账本选择弹窗
void showLedgerPicker(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const LedgerPickerDialog(),
  );
}
