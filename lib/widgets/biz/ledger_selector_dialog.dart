import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../../l10n/app_localizations.dart';

/// 显示账本选择器
///
/// [currentLedgerId] 当前选中的账本ID（可选，用于高亮显示）
/// Returns: 选中的账本ID，如果取消则返回null
Future<int?> showLedgerSelector(
  BuildContext context, {
  int? currentLedgerId,
}) async {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => LedgerSelectorDialog(
      currentLedgerId: currentLedgerId,
    ),
  );
}

class LedgerSelectorDialog extends ConsumerWidget {
  final int? currentLedgerId;

  const LedgerSelectorDialog({
    super.key,
    this.currentLedgerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<List<Ledger>>(
      future: repo.getAllLedgers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ledgers = snapshot.data!;
        if (ledgers.isEmpty) {
          return SimpleDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(l10n.ledgerSelectTitle),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.ledgersEmpty),
              ),
            ],
          );
        }

        return SimpleDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.ledgerSelectTitle),
          children: ledgers.map((ledger) {
            final isSelected = ledger.id == currentLedgerId;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ledger.id),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryColor : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ledger.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? primaryColor : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
