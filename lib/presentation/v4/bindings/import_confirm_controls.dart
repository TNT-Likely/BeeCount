import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';
import '../../../widgets/ui/ui.dart';
import '../../../data/db.dart' as schema;
import '../../../l10n/app_localizations.dart';
import '../../../services/import/csv_parser.dart';
import '../../../utils/category_utils.dart';
import '../../../services/import/bill_parser.dart';
import '../../../services/import/parsers/generic_parser.dart';
import '../../../services/import/parsers/alipay_parser.dart';
import '../../../services/import/parsers/wechat_parser.dart';
import '../../../services/billing/post_processor.dart';
import '../../../services/data_import_service.dart';
import '../../../services/import/account_currency_plan.dart';
import '../../../utils/date_parser.dart';
import 'import_source.dart';
import 'page_scaffold.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/transaction_import.dart';

class ImportConfirmControls extends ConsumerStatefulWidget {
  final String csvText;
  final bool hasHeader;
  final BillSourceType billType;
  const ImportConfirmControls({
    super.key,
    required this.csvText,
    required this.hasHeader,
    required this.billType,
  });

  @override
  ConsumerState<ImportConfirmControls> createState() =>
      _ImportConfirmControlsState();
}

class _ImportConfirmControlsState extends ConsumerState<ImportConfirmControls> {
  List<List<String>> rows = const [];
  bool parsing = true;
  // 自动识别到的表头所在行（仅当 hasHeader 为 true 时使用）
  int headerRow = 0;
  final Map<String, int?> mapping = {
    'date': null,
    'type': null,
    'amount': null,
    'currency': null, // v30 多币种:币种列(反馈10)
    'category': null,
    'sub_category': null, // 二级分类
    'account': null,
    'from_account': null,
    'to_account': null,
    'note': null,
    'tags': null, // 标签（逗号分隔）
    'attachments': null, // 附件文件名（逗号分隔）
  };
  bool importing = false;
  int ok = 0, fail = 0, skipped = 0; // skipped: 跳过的非收支类型记录
  int step = 0; // 0: 字段映射, 1: 分类映射
  bool _cancelled = false;
  List<String> distinctCategories = [];
  Map<String, int?> categoryMapping = {}; // 源分类名 -> 目标分类ID（null表示保持原名）
  Future<List<schema.Category>>? allCategoriesFuture;
  late final BillParser _billParser;

  @override
  void initState() {
    super.initState();
    // 根据账单类型选择解析器
    _billParser = _getParser(widget.billType);

    // 解析在后台 isolate 完成，避免主线程卡顿
    () async {
      final parsed = await compute(_parseRowsIsolate, widget.csvText);
      if (!mounted) return;
      setState(() {
        rows = parsed;
        parsing = false;
      });
      // 解析完成
      // 使用解析器查找表头
      if (widget.hasHeader && rows.isNotEmpty) {
        headerRow = _billParser.findHeaderRow(rows);
        if (headerRow < 0) headerRow = 0; // 兜底
      }
      _autoDetectMapping();
      // 预取分类列表供第二步选择
      allCategoriesFuture = _loadAllCategories(ref);
    }();
  }

  /// 根据账单类型获取解析器
  BillParser _getParser(BillSourceType type) {
    switch (type) {
      case BillSourceType.generic:
        return GenericBillParser();
      case BillSourceType.alipay:
        return AlipayBillParser();
      case BillSourceType.wechat:
        return WechatBillParser();
    }
  }

  void _autoDetectMapping() {
    if (rows.isEmpty || !widget.hasHeader) return;
    final headers = rows[headerRow].map((e) => e.toString().trim()).toList();

    // 使用解析器的列映射功能
    final detectedMapping = _billParser.mapColumns(headers);

    // 更新 mapping
    detectedMapping.forEach((key, index) {
      if (mapping.containsKey(key)) {
        mapping[key] = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (parsing) {
      return V4PageScaffold(
          body: Column(children: [
        BeePageHeader(title: l.importPreparing, leading: const BackButton()),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ]));
    }
    final columnCount =
        rows.isNotEmpty ? rows[widget.hasHeader ? headerRow : 0].length : 0;
    final header = rows.isEmpty
        ? const <String>[]
        : rows[widget.hasHeader ? headerRow : 0];
    final options = List.generate(
        columnCount,
        (i) => BeeImportOption(
            i,
            widget.hasHeader && i < header.length && header[i].trim().isNotEmpty
                ? header[i].trim()
                : l.importColumnNumber(i + 1)));
    final fields = <(String, String)>[
      (l.importFieldDate, 'date'),
      (l.importFieldType, 'type'),
      (l.importFieldAmount, 'amount'),
      (l.importFieldCurrency, 'currency'),
      (l.importFieldCategory, 'category'),
      (l.exportCsvHeaderSubCategory, 'sub_category'),
      (l.importFieldAccount, 'account'),
      (l.exportCsvHeaderFromAccount, 'from_account'),
      (l.exportCsvHeaderToAccount, 'to_account'),
      (l.importFieldNote, 'note'),
      (l.exportCsvHeaderTags, 'tags'),
      (l.exportCsvHeaderAttachments, 'attachments'),
    ];
    return V4PageScaffold(
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (importing)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(l.importProgress(ok, fail),
                                style: const TextStyle(fontSize: 12))),
                      if (step == 0)
                        BeeButton(label: l.importNextStep, onPressed: _nextStep)
                      else
                        Row(children: [
                          Expanded(
                              child: BeeButton(
                                  label: l.importPreviousStep,
                                  kind: BeeButtonKind.secondary,
                                  onPressed: importing
                                      ? null
                                      : () => setState(() => step = 0))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: BeeButton(
                                  label: l.importStartImport,
                                  onPressed: importing ? null : _startImport)),
                        ]),
                    ]))),
        body: Column(children: [
          BeePageHeader(
              title:
                  step == 0 ? l.importConfirmMapping : l.importCategoryMapping,
              leading: const BackButton()),
          Expanded(
              child: BeePageBody(eager: true, children: [
            BeeImportSteps(labels: [
              l.importChooseFile,
              l.importConfirmMapping,
              l.importCategoryMapping
            ], current: step + 1),
            if (step == 0) ...[
              if (rows.isEmpty)
                BeeEmptyState(
                    title: l.importNoDataParsed,
                    icon: const BeeLineIcon('FileSpreadsheet', size: 36)),
              BeeImportSection(
                  title: l.importConfirmMapping,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final width = constraints.maxWidth >= 560
                        ? (constraints.maxWidth - 14) / 2
                        : constraints.maxWidth;
                    return Wrap(spacing: 14, runSpacing: 14, children: [
                      for (final field in fields)
                        SizedBox(
                            width: width,
                            child: BeeImportMappingField<int>(
                                key: ValueKey('import-field-${field.$2}'),
                                label: field.$1,
                                value: mapping[field.$2],
                                options: options,
                                hint: l.importAutoDetect,
                                onChanged: (value) =>
                                    setState(() => mapping[field.$2] = value))),
                    ]);
                  })),
              _previewSection(),
            ] else ...[
              if (mapping['category'] == null)
                Text(l.importCategoryNotSelected),
              BeeImportSection(
                  title: l.importCategoryMapping,
                  description: l.importCategoryMappingDescription,
                  child: FutureBuilder<List<schema.Category>>(
                      future: allCategoriesFuture,
                      builder: (context, snap) {
                        final cats = snap.data ?? [];
                        final options = <BeeImportOption<int?>>[
                          BeeImportOption(null, l.importKeepOriginalName),
                          ...cats.map((c) => BeeImportOption(c.id,
                              '${CategoryUtils.getDisplayName(c.name, context, kind: c.kind)} (${c.kind == 'income' ? l.categoryIncome : l.categoryExpense})')),
                        ];
                        // Preserve the original name matching and fallback behavior.
                        if (categoryMapping.values.every((v) => v == null) &&
                            cats.isNotEmpty) {
                          bool hasMatch = false;
                          for (final sourceName in distinctCategories) {
                            try {
                              final matchingCategory =
                                  cats.firstWhere((c) => c.name == sourceName);
                              categoryMapping[sourceName] = matchingCategory.id;
                              hasMatch = true;
                            } catch (_) {}
                          }
                          if (hasMatch) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() {});
                            });
                          }
                        }
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var index = 0;
                                  index < distinctCategories.length;
                                  index++) ...[
                                if (index > 0) const SizedBox(height: 14),
                                BeeImportMappingField<int?>(
                                    key: ValueKey(
                                        'import-category-${distinctCategories[index]}'),
                                    label: distinctCategories[index],
                                    value: categoryMapping[
                                        distinctCategories[index]],
                                    options: options,
                                    onChanged: (value) => setState(() =>
                                        categoryMapping[
                                                distinctCategories[index]] =
                                            value)),
                              ],
                            ]);
                      })),
            ],
          ])),
        ]));
  }

  Widget _previewSection() {
    const maxPreview = 10;
    final l = AppLocalizations.of(context);
    final totalRows = rows.length;
    final dataStart = widget.hasHeader ? headerRow + 1 : 0;
    final header = widget.hasHeader && rows.isNotEmpty
        ? [rows[headerRow]]
        : <List<String>>[];
    final take = maxPreview - header.length;
    final end = dataStart + take <= totalRows ? dataStart + take : totalRows;
    final body = totalRows > dataStart
        ? rows.sublist(dataStart, end)
        : const <List<String>>[];
    final limited = [...header, ...body];
    return BeeImportSection(
        title: l.importPreview,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BeeImportPreviewTable(rows: limited, hasHeader: widget.hasHeader),
          if (totalRows > limited.length) ...[
            const SizedBox(height: 10),
            Text(l.importPreviewLimit(limited.length, totalRows),
                style:
                    TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
          ],
        ]));
  }

  void _nextStep() {
    if (mapping['category'] == null) {
      if (mapping['from_account'] != null || mapping['to_account'] != null) {
        _startImport();
      } else {
        showToast(
            context, AppLocalizations.of(context).importSelectCategoryFirst);
      }
      return;
    }
    _buildDistinctCategories();
    setState(() => step = 1);
  }

  Future<void> _startImport() async {
    // 使用根容器，保证页面被销毁后仍可更新全局进度供"我的"页展示
    final container = ProviderScope.containerOf(context, listen: false);
    final currentContext = context;
    setState(() {
      importing = true;
      ok = 0;
      fail = 0;
    });
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);

    // v1.15.0: 获取当前账本的币种信息
    final currentLedger = await repo.getLedgerById(ledgerId);
    final ledgerCurrency = currentLedger?.currency ?? 'CNY';

    final dataStart = widget.hasHeader ? (headerRow + 1) : 0;
    final total = rows.length - dataStart;
    final Map<String, int> skippedTypes = {};
    late final ImportData importData;
    try {
      final raw = _buildImportDataFromCsv(
        rows: rows,
        dataStart: dataStart,
        mapping: mapping,
        categoryMapping: categoryMapping,
        skippedTypes: skippedTypes,
        ledgerCurrency: ledgerCurrency,
      );
      final existing = await repo.getAllAccounts();
      final plan = planExternalAccountCurrencies(
        raw,
        ledgerCurrency: ledgerCurrency,
        existingCurrencies: {
          for (final account in existing) account.name: account.currency
        },
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                title: Text(l10n.importAccountCurrencyPreview),
                content: SingleChildScrollView(
                    child: BeeImportAccountCurrencyReview(
                  description: l10n.importAccountCurrencyPreviewHint,
                  accounts: [
                    for (final account in plan.data.accounts)
                      '${account.name} · ${account.currency}'
                  ],
                  mappings: plan.mappings,
                )),
                actions: [
                  BeeButton(
                      label: l10n.commonCancel,
                      kind: BeeButtonKind.quiet,
                      onPressed: () => Navigator.pop(ctx, false)),
                  BeeButton(
                      label: l10n.importStartImport,
                      onPressed: () => Navigator.pop(ctx, true)),
                ],
              ));
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => importing = false);
        return;
      }
      importData = plan.data;
    } catch (error) {
      if (mounted) {
        setState(() => importing = false);
        showToast(context,
            AppLocalizations.of(context).importTransactionFailed('$error'));
      }
      return;
    }
    // 初始化全局进度
    container.read(importProgressProvider.notifier).state = ImportProgress(
      running: true,
      total: total,
      done: 0,
      ok: 0,
      fail: 0,
    );

    if (!currentContext.mounted) return;
    bool dialogOpen = true;
    // 进度弹窗（可转后台）
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dctx) {
        return Consumer(builder: (dctx, r, _) {
          final p = r.watch(importProgressProvider);
          final percent =
              p.total == 0 ? 0.0 : (p.done / p.total).clamp(0.0, 1.0);
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            content: BeeImportStatusPanel(
              title: AppLocalizations.of(context).importInProgress,
              message: AppLocalizations.of(context)
                  .importProgressDetail(p.done, p.fail, p.ok, p.total),
              progress: percent > 0 && percent < 1 ? percent : null,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dialogOpen = false;
                  Navigator.of(dctx).pop();
                  // 返回到数据管理页面继续后台导入
                  if (mounted) {
                    // Pop回DataManagementPage: ImportConfirmControls -> ImportPage
                    Navigator.of(currentContext)
                        .pop(); // Close ImportConfirmControls
                    Navigator.of(currentContext)
                        .pop(); // Close ImportPage, back to DataManagementPage
                  }
                },
                child:
                    Text(AppLocalizations.of(context).importBackgroundImport),
              ),
              TextButton(
                onPressed: () {
                  _cancelled = true;
                  dialogOpen = false;
                  Navigator.of(dctx).pop();
                },
                child: Text(AppLocalizations.of(context).importCancelImport),
              ),
            ],
          );
        });
      },
    );

    // 定义进度变量
    int done = 0;

    try {
      // 调用统一导入服务
      final result = await dataImportService.importData(
        repo,
        ledgerId,
        importData,
        defaultCurrency: ledgerCurrency,
        onProgress: (processed, progressTotal) {
          done = processed;
          // 更新全局进度
          container.read(importProgressProvider.notifier).state =
              ImportProgress(
            running: true,
            total: total,
            done: done,
            ok: ok,
            fail: fail,
          );
          if (mounted) setState(() {});
        },
      );

      ok = result.inserted;
      fail = result.failed;
      skipped = skippedTypes.values.fold(0, (a, b) => a + b);
      done = total;

      // 显式触发一次同步上推。SyncCoordinator 监听 local_changes 表已经会
      // 自动调度,这里作为兜底:provider 重建瞬间 / 边界条件下 coordinator
      // 还没就位时,UI 显式触发也能把刚导入的数据推上云端。
      // fire-and-forget:不阻塞导入完成动画。
      try {
        // ignore: unawaited_futures
        PostProcessor.syncC(container, ledgerId: ledgerId);
      } catch (_) {
        // 忽略同步触发错误,导入本身已经成功
      }
    } catch (e) {
      // 导入失败
      if (mounted) {
        showToast(context,
            AppLocalizations.of(context).importTransactionFailed('$e'));
      }
      fail = total - ok; // 更新失败数
    }

    // 即使页面已被关闭（mounted=false），也要继续更新全局进度供"我的"页展示
    // 先切换为"完成"以驱动 UI 展示成功动画/提示（不等待云上传）
    try {
      container.read(importProgressProvider.notifier).state = ImportProgress(
        running: false,
        total: total,
        done: done,
        ok: ok,
        fail: fail,
        ledgerId: ledgerId, // 设置账本ID，用于触发账本列表页面刷新
        skipped: skipped, // 跳过的记录数
        skippedTypes: skippedTypes, // 跳过的类型及数量
      );
    } catch (_) {
      // 忽略进度更新错误
    }

    // 延迟清空和刷新（不依赖页面状态，即使页面销毁也要执行）
    if (!_cancelled) {
      Future<void>.delayed(const Duration(seconds: 5), () {
        // 延长到5秒，让用户看到动画
        try {
          container.read(importProgressProvider.notifier).state =
              ImportProgress.empty;
          // 刷新"我的"页统计（笔数/天数）
          container.invalidate(countsForLedgerProvider(ledgerId));
          // 触发全局统计刷新（用于"我的"页顶部聚合信息）
          container.read(statsRefreshProvider.notifier).state++;
          // 触发一次同步状态刷新（UI 端会复用缓存避免闪烁）
          container.read(syncStatusRefreshProvider.notifier).state++;
        } catch (_) {
          // 忽略延迟刷新错误
        }
      });
    }

    // Check if context is still mounted for UI operations
    if (!currentContext.mounted) {
      return;
    }

    // 显示导入完成提示
    final cancelledText =
        _cancelled ? AppLocalizations.of(currentContext).importCancelled : '';
    final l10nToast = AppLocalizations.of(currentContext);

    // 构建提示信息
    String message = l10nToast.importCompleted(cancelledText, fail, ok);
    bool hasSkipped = skipped > 0;

    if (hasSkipped) {
      // 显示类型不匹配的跳过记录
      final typeSkipped = skippedTypes.values.fold(0, (a, b) => a + b);

      if (typeSkipped > 0) {
        final skippedList =
            skippedTypes.entries.map((e) => '${e.key}(${e.value})').join('、');
        message +=
            '\n${l10nToast.importSkippedNonTransactionTypes(typeSkipped)}\n$skippedList';
      }
    }

    // Handle UI operations before cloud upload
    if (dialogOpen) {
      Navigator.of(currentContext).pop();
    }

    // 判断显示方式: 完全成功用toast,有失败或跳过用弹窗
    if (fail == 0 && !hasSkipped) {
      // 完全成功: 使用toast,然后关闭页面
      showToast(currentContext, message);
      // 关闭确认页 -> 返回到数据管理页面
      // Pop回DataManagementPage: ImportConfirmControls -> ImportPage
      Navigator.of(currentContext).pop(); // Close ImportConfirmControls
      Navigator.of(currentContext)
          .pop(); // Close ImportPage, back to DataManagementPage
    } else {
      // 有失败或跳过: 使用弹窗显示详细信息,等待用户确认后再关闭页面
      await showDialog(
        context: currentContext,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(l10nToast.importCompleteTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10nToast.commonConfirm),
            ),
          ],
        ),
      );

      // 用户确认后再关闭页面
      if (currentContext.mounted) {
        Navigator.of(currentContext).pop(); // Close ImportConfirmControls
        Navigator.of(currentContext)
            .pop(); // Close ImportPage, back to DataManagementPage
      }
    }
    // 返回后再显式刷新一次全局统计，确保顶部汇总即时更新
    try {
      container.read(statsRefreshProvider.notifier).state++;
    } catch (_) {}

    // 导入完成后，账本列表页面会通过监听 importProgressProvider 自动刷新
    // ledgerId 已经在上面的 importProgressProvider 中设置
  }

  /// 将CSV数据转换为统一的ImportData格式
  ImportData _buildImportDataFromCsv({
    required List<List<String>> rows,
    required int dataStart,
    required Map<String, int?> mapping,
    required Map<String, int?> categoryMapping,
    required Map<String, int> skippedTypes,
    required String ledgerCurrency,
  }) {
    final accounts = <ImportAccount>[];
    final categories = <ImportCategory>[];
    final tags = <ImportTag>[];
    final transactions = <ImportTransaction>[];

    final accountIdx = mapping['account'];
    final fromAccountIdx = mapping['from_account'];
    final toAccountIdx = mapping['to_account'];
    final tagsIdx = mapping['tags'];

    // 收集唯一账户和标签
    final uniqueAccountNames = <String>{};
    final uniqueTagNames = <String>{};
    // 收集分类信息（用于创建分类）
    final categoryInfoMap =
        <String, ({String kind, String? icon, String? parentName})>{};

    // 第一遍：收集账户、标签、分类信息
    for (int i = dataStart; i < rows.length; i++) {
      final r = rows[i];

      String? getBy(String key) {
        final userIdx = mapping[key];
        if (userIdx != null && userIdx >= 0 && userIdx < r.length) {
          final val = r[userIdx].toString().trim();
          return val.isNotEmpty ? val : null;
        }
        return null;
      }

      // 收集账户名
      if (accountIdx != null && accountIdx < r.length) {
        final name = r[accountIdx].toString().trim();
        if (name.isNotEmpty) uniqueAccountNames.add(name);
      }
      if (fromAccountIdx != null && fromAccountIdx < r.length) {
        final name = r[fromAccountIdx].toString().trim();
        if (name.isNotEmpty) uniqueAccountNames.add(name);
      }
      if (toAccountIdx != null && toAccountIdx < r.length) {
        final name = r[toAccountIdx].toString().trim();
        if (name.isNotEmpty) uniqueAccountNames.add(name);
      }

      // 收集标签名
      if (tagsIdx != null && tagsIdx < r.length) {
        final tagsStr = r[tagsIdx].toString().trim();
        if (tagsStr.isNotEmpty) {
          for (final tagName in tagsStr.split(',')) {
            final trimmed = tagName.trim();
            if (trimmed.isNotEmpty) uniqueTagNames.add(trimmed);
          }
        }
      }

      // 解析类型用于分类收集
      final typeRaw = getBy('type') ?? 'expense';
      final typeStr = typeRaw.trim().toLowerCase();
      String? type;
      if (typeStr == '收入' ||
          typeStr == '收' ||
          typeStr == '入账' ||
          typeStr == '进账' ||
          typeStr == '入帳' ||
          typeStr == '進帳' || // 繁体
          typeStr == 'income' ||
          typeStr == 'revenue' ||
          typeStr == 'earning') {
        type = 'income';
      } else if (typeStr == '支出' ||
          typeStr == '支' ||
          typeStr == '出账' ||
          typeStr == '消费' ||
          typeStr == '花费' ||
          typeStr == '出帳' ||
          typeStr == '消費' ||
          typeStr == '花費' || // 繁体
          typeStr == 'expense' ||
          typeStr == 'spending' ||
          typeStr == 'expenditure') {
        type = 'expense';
      } else if (typeStr == '转账' || typeStr == '轉帳' || typeStr == 'transfer') {
        // 添加繁体
        type = 'transfer';
      }

      // 收集分类信息（仅非转账）
      if (type != null && type != 'transfer') {
        final categoryName = getBy('category');
        final subCategoryName = getBy('sub_category');
        final categoryIcon = getBy('category_icon');
        final subCategoryIcon = getBy('sub_category_icon');

        if (subCategoryName != null && categoryName != null) {
          // 有二级分类
          final parentKey = '$categoryName:$type';
          categoryInfoMap.putIfAbsent(
              parentKey,
              () => (
                    kind: type!,
                    icon: categoryIcon,
                    parentName: null,
                  ));
          final subKey = '$subCategoryName:$type:$categoryName';
          categoryInfoMap.putIfAbsent(
              subKey,
              () => (
                    kind: type!,
                    icon: subCategoryIcon,
                    parentName: categoryName,
                  ));
        } else if (categoryName != null) {
          // 只有一级分类（仅当用户选择"保持原名"时才需要创建）
          final chosen = categoryMapping[categoryName];
          if (chosen == null) {
            final key = '$categoryName:$type';
            categoryInfoMap.putIfAbsent(
                key,
                () => (
                      kind: type!,
                      icon: categoryIcon,
                      parentName: null,
                    ));
          }
        }
      }
    }

    // 构建账户列表
    for (final name in uniqueAccountNames) {
      accounts.add(ImportAccount(
        name: name,
        type: 'cash',
        currency: ledgerCurrency,
      ));
    }

    // 构建标签列表
    for (final name in uniqueTagNames) {
      tags.add(ImportTag(name: name));
    }

    // 构建分类列表（先一级后二级）
    final level1Categories = categoryInfoMap.entries
        .where((e) => e.value.parentName == null)
        .toList();
    final level2Categories = categoryInfoMap.entries
        .where((e) => e.value.parentName != null)
        .toList();

    for (final entry in level1Categories) {
      final parts = entry.key.split(':');
      final name = parts[0];
      final kind = parts[1];
      categories.add(ImportCategory(
        name: name,
        kind: kind,
        level: 1,
        icon: entry.value.icon,
      ));
    }
    for (final entry in level2Categories) {
      final parts = entry.key.split(':');
      final name = parts[0];
      final kind = parts[1];
      final parentName = parts[2];
      categories.add(ImportCategory(
        name: name,
        kind: kind,
        level: 2,
        icon: entry.value.icon,
        parentName: parentName,
      ));
    }

    // 第二遍：构建交易列表
    for (int i = dataStart; i < rows.length; i++) {
      final r = rows[i];

      String? getBy(String key) {
        final userIdx = mapping[key];
        if (userIdx != null && userIdx >= 0 && userIdx < r.length) {
          final val = r[userIdx].toString().trim();
          return val.isNotEmpty ? val : null;
        }
        return null;
      }

      final dateStr = getBy('date');
      final typeRaw = getBy('type') ?? 'expense';
      final amountStr = getBy('amount');
      final currencyStr = getBy('currency')?.trim().toUpperCase();
      final categoryName = getBy('category');
      final subCategoryName = getBy('sub_category');
      final accountName = getBy('account');
      final fromAccountName = getBy('from_account');
      final toAccountName = getBy('to_account');
      final note = getBy('note');
      final tagsStr = getBy('tags');
      final attachmentsStr = getBy('attachments');

      // 类型识别
      final typeStr = typeRaw.trim().toLowerCase();
      String? type;
      if (typeStr == '收入' ||
          typeStr == '收' ||
          typeStr == '入账' ||
          typeStr == '进账' ||
          typeStr == '入帳' ||
          typeStr == '進帳' || // 繁体
          typeStr == 'income' ||
          typeStr == 'revenue' ||
          typeStr == 'earning') {
        type = 'income';
      } else if (typeStr == '支出' ||
          typeStr == '支' ||
          typeStr == '出账' ||
          typeStr == '消费' ||
          typeStr == '花费' ||
          typeStr == '出帳' ||
          typeStr == '消費' ||
          typeStr == '花費' || // 繁体
          typeStr == 'expense' ||
          typeStr == 'spending' ||
          typeStr == 'expenditure') {
        type = 'expense';
      } else if (typeStr == '转账' || typeStr == '轉帳' || typeStr == 'transfer') {
        // 添加繁体
        type = 'transfer';
      } else {
        // 未识别的类型：记录并跳过
        skippedTypes[typeRaw.trim()] = (skippedTypes[typeRaw.trim()] ?? 0) + 1;
        continue;
      }

      // 金额解析
      final amountClean = (amountStr ?? '0').replaceAll(RegExp(r'[¥$,+-]'), '');
      final amount = double.tryParse(amountClean)?.abs() ?? 0.0;

      // 日期解析
      final date = DateParser.parse(dateStr);

      // 解析标签名称列表
      List<String>? tagNames;
      if (tagsStr != null && tagsStr.isNotEmpty) {
        tagNames = tagsStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      // 解析附件文件名列表
      List<ImportAttachment>? attachments;
      if (attachmentsStr != null && attachmentsStr.isNotEmpty) {
        final fileNames = attachmentsStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (fileNames.isNotEmpty) {
          attachments = fileNames
              .asMap()
              .entries
              .map((entry) => ImportAttachment(
                    fileName: entry.value,
                    sortOrder: entry.key,
                  ))
              .toList();
        }
      }

      // 处理分类：支持用户映射和二级分类
      String? finalCategoryName;
      String? categoryKind;
      int? categoryId;

      if (type != 'transfer') {
        if (subCategoryName != null && categoryName != null) {
          // 有二级分类：使用二级分类名称
          finalCategoryName = subCategoryName;
          categoryKind = type;
        } else if (categoryName != null) {
          // 只有一级分类：检查用户映射
          final chosen = categoryMapping[categoryName];
          if (chosen != null) {
            // 用户选择了现有分类，使用预解析的ID
            categoryId = chosen;
          } else {
            // 保持原名
            finalCategoryName = categoryName;
            categoryKind = type;
          }
        }
      }

      if (currencyStr != null &&
          !RegExp(r'^[A-Z]{3,8}$').hasMatch(currencyStr)) {
        throw FormatException(
            '${AppLocalizations.of(context).importCurrencyInvalid} ${i + 1}: $currencyStr');
      }
      transactions.add(ImportTransaction(
        type: type,
        amount: amount,
        currencyCode: currencyStr,
        categoryName: finalCategoryName,
        categoryKind: categoryKind,
        categoryId: categoryId,
        happenedAt: date,
        note: note,
        accountName: type != 'transfer' ? accountName : null,
        fromAccountName: type == 'transfer' ? fromAccountName : null,
        toAccountName: type == 'transfer' ? toAccountName : null,
        tagNames: tagNames,
        attachments: attachments,
      ));
    }

    return ImportData(
      accounts: accounts,
      categories: categories,
      tags: tags,
      transactions: transactions,
    );
  }

  void _buildDistinctCategories() {
    final catIdx = mapping['category'];
    if (catIdx == null) {
      distinctCategories = [];
      categoryMapping = {};
      return;
    }
    final set = <String>{};
    final dataStart = widget.hasHeader ? (headerRow + 1) : 0;
    for (int i = dataStart; i < rows.length; i++) {
      if (catIdx < rows[i].length) {
        final name = rows[i][catIdx].trim();
        if (name.isNotEmpty) set.add(name);
      }
    }
    distinctCategories = set.toList()..sort();

    // 初始化分类映射为null，后续在FutureBuilder中进行自动匹配
    categoryMapping = {for (final n in distinctCategories) n: null};
  }
}

// isolate 入口函数：在后台解析 CSV 文本
List<List<String>> _parseRowsIsolate(String input) {
  return CsvParser.parse(input);
}

Future<List<schema.Category>> _loadAllCategories(WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  final expenseTopLevel = await repo.getTopLevelCategories('expense');
  final incomeTopLevel = await repo.getTopLevelCategories('income');

  final allCategories = <schema.Category>[];
  allCategories.addAll(expenseTopLevel);
  allCategories.addAll(incomeTopLevel);

  // 获取所有子分类
  for (final category in [...expenseTopLevel, ...incomeTopLevel]) {
    final subCategories = await repo.getSubCategories(category.id);
    allCategories.addAll(subCategories);
  }

  return allCategories;
}
