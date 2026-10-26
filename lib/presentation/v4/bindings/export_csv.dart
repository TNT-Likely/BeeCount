import 'package:csv/csv.dart';

import '../../../data/db.dart';
import '../../../data/repositories/base_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/category_utils.dart';

/// The original CSV contract, extracted from ExportPage without storage or UI.
/// Reads the same current-ledger repository stream and never writes app data.
Future<String> buildTransactionExportCsv({
  required BaseRepository repo,
  required int ledgerId,
  required AppLocalizations l10n,
  void Function(double)? onProgress,
}) async {
  // 获取交易和分类数据
  final transactionsWithCategory =
      await repo.transactionsWithCategoryAll(ledgerId: ledgerId).first;
  final total = transactionsWithCategory.length;
  final rows = <List<dynamic>>[];
  rows.add(exportCsvHeaders(l10n));

  // 批量获取所有交易的标签
  final transactionIds = transactionsWithCategory.map((tx) => tx.t.id).toList();
  final tagsMap = await repo.getTagsForTransactions(transactionIds);

  // 批量获取所有交易的附件
  final attachmentsMap =
      await repo.getAttachmentsForTransactions(transactionIds);

  // 缓存所有账户信息，避免重复查询
  final allAccounts = await repo.getAllAccounts();
  final accountMap = {for (var acc in allAccounts) acc.id: acc};

  // v30 多币种:账本本位币(currencyCode 为 NULL 的历史行按账户/本位币兜底,
  // 与统计读取端同语义 —— 导出自包含,回导不丢币种)
  final ledgerData = await repo.getLedgerById(ledgerId);
  final ledgerBase = ((ledgerData?.currency.isNotEmpty ?? false)
          ? ledgerData!.currency
          : 'CNY')
      .toUpperCase();

  // 缓存所有分类信息（包括父分类）
  final incomeCategories = await repo.getTopLevelCategories('income');
  final expenseCategories = await repo.getTopLevelCategories('expense');
  final allCategories = <int, Category>{};
  for (final cat in [...incomeCategories, ...expenseCategories]) {
    allCategories[cat.id] = cat;
    // 获取子分类
    final subCategories = await repo.getSubCategories(cat.id);
    for (final subCat in subCategories) {
      allCategories[subCat.id] = subCat;
    }
  }

  for (int i = 0; i < transactionsWithCategory.length; i++) {
    final txWithCat = transactionsWithCategory[i];
    final t = txWithCat.t;
    final c = txWithCat.category;
    final a = t.accountId != null ? accountMap[t.accountId] : null;
    // 使用完整的时间格式，包含年份和秒，添加前导空格增加列宽
    final timeStr = () {
      try {
        final localTime = t.happenedAt.toLocal();
        // 完整时间格式: YYYY-MM-DD HH:mm:ss，前面添加空格增加列宽
        return '  ${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}  ';
      } catch (e) {
        return '';
      }
    }();
    final typeStr = exportTypeDisplayName(l10n, t.type);

    // 对于转账类型，需要特殊处理账户信息
    String accountName;
    String fromAccountName;
    String toAccountName;
    String categoryName;
    String subCategoryName;

    if (t.type == 'transfer') {
      // 转账记录：账户列留空，填充转出账户和转入账户
      accountName = '';
      final fromAccount = accountMap[t.accountId];
      final toAccount = accountMap[t.toAccountId];
      fromAccountName = fromAccount?.name ?? '';
      toAccountName = toAccount?.name ?? '';
      categoryName = ''; // 转账没有分类
      subCategoryName = '';
    } else {
      // 收入或支出：正常填充账户列，转出转入账户留空
      accountName = a?.name ?? '';
      fromAccountName = '';
      toAccountName = '';

      // 处理分类信息
      if (c != null) {
        if (c.level == 2 && c.parentId != null) {
          // 二级分类：分类列填一级分类名称，二级分类列填当前分类名称
          final parentCategory = allCategories[c.parentId];
          categoryName = CategoryUtils.displayName(parentCategory?.name, l10n);
          subCategoryName = CategoryUtils.displayName(c.name, l10n);
        } else {
          // 一级分类：分类列填当前分类，二级分类列留空
          categoryName = CategoryUtils.displayName(c.name, l10n);
          subCategoryName = '';
        }
      } else {
        categoryName = '';
        subCategoryName = '';
      }
    }

    // 获取该交易的标签，用逗号分隔
    final transactionTags = tagsMap[t.id] ?? [];
    final tagsStr = transactionTags.map((tag) => tag.name).join(',');

    // 获取该交易的附件，用逗号分隔文件名
    final transactionAttachments = attachmentsMap[t.id] ?? [];
    final attachmentsStr =
        transactionAttachments.map((a) => a.fileName).join(',');

    final currencyStr = (t.currencyCode ??
            (a?.currency.isNotEmpty ?? false ? a!.currency : null) ??
            ledgerBase)
        .toUpperCase();

    rows.add([
      typeStr,
      categoryName,
      subCategoryName,
      t.amount.toStringAsFixed(2),
      currencyStr,
      accountName,
      fromAccountName,
      toAccountName,
      t.note ?? '',
      timeStr,
      tagsStr,
      attachmentsStr,
    ]);
    if (i % 50 == 0) {
      onProgress?.call((i + 1) / (total == 0 ? 1 : total));
    }
  }

  final csvStr = const ListToCsvConverter(eol: '\n').convert(rows);
  return csvStr;
}

List<String> exportCsvHeaders(AppLocalizations l10n) {
  return [
    l10n.exportCsvHeaderType,
    l10n.exportCsvHeaderCategory,
    l10n.exportCsvHeaderSubCategory, // 二级分类名称
    l10n.exportCsvHeaderAmount,
    l10n.exportCsvHeaderCurrency, // v30 多币种:交易原币种(反馈10)
    l10n.exportCsvHeaderAccount,
    l10n.exportCsvHeaderFromAccount, // 转出账户
    l10n.exportCsvHeaderToAccount, // 转入账户
    l10n.exportCsvHeaderNote,
    l10n.exportCsvHeaderTime,
    l10n.exportCsvHeaderTags,
    l10n.exportCsvHeaderAttachments, // 附件文件名（逗号分隔）
  ];
}

String exportTypeDisplayName(AppLocalizations l10n, String type) {
  switch (type) {
    case 'income':
      return l10n.exportTypeIncome;
    case 'expense':
      return l10n.exportTypeExpense;
    case 'transfer':
      return l10n.exportTypeTransfer;
    default:
      return type;
  }
}
