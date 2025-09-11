import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:drift/drift.dart' as d;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../widgets/ui/ui.dart';
import '../data/db.dart' as schema;

class ImportConfirmPage extends ConsumerStatefulWidget {
  final String csvText;
  final bool hasHeader;
  const ImportConfirmPage(
      {super.key, required this.csvText, required this.hasHeader});

  @override
  ConsumerState<ImportConfirmPage> createState() => _ImportConfirmPageState();
}

class _ImportConfirmPageState extends ConsumerState<ImportConfirmPage> {
  List<List<String>> rows = const [];
  bool parsing = true;
  // 自动识别到的表头所在行（仅当 hasHeader 为 true 时使用）
  int headerRow = 0;
  final Map<String, int?> mapping = {
    'date': null,
    'type': null,
    'amount': null,
    'category': null,
    'note': null,
  };
  bool importing = false;
  int ok = 0, fail = 0;
  int step = 0; // 0: 字段映射, 1: 分类映射
  bool _cancelled = false;
  List<String> distinctCategories = [];
  Map<String, int?> categoryMapping = {}; // 源分类名 -> 目标分类ID（null表示保持原名）
  Future<List<schema.Category>>? allCategoriesFuture;

  @override
  void initState() {
    super.initState();
    // 解析在后台 isolate 完成，避免主线程卡顿
    () async {
      final parsed = await compute(_parseRowsIsolate, widget.csvText);
      if (!mounted) return;
      setState(() {
        rows = parsed;
        parsing = false;
      });
      // 解析完成
      // 需求：总是将第一行作为表头
      if (widget.hasHeader && rows.isNotEmpty) {
        headerRow = 0;
      }
      _autoDetectMapping();
      // 预取分类列表供第二步选择
      allCategoriesFuture = _loadAllCategories(ref);
    }();
  }

  void _autoDetectMapping() {
    if (rows.isEmpty || !widget.hasHeader) return;
    final headers = rows[headerRow].map((e) => e.toString().trim()).toList();
    String? normalizeToKey(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final lower = s.toLowerCase();
      final noSpace = lower.replaceAll(RegExp(r'\s+'), '');
      if (noSpace == 'date' || noSpace == 'time' || noSpace == 'datetime') {
        return 'date';
      }
      if (noSpace == 'type' || noSpace == 'inout' || noSpace == 'direction') {
        return 'type';
      }
      if (noSpace == 'amount' ||
          noSpace == 'money' ||
          noSpace == 'price' ||
          noSpace == 'value') {
        return 'amount';
      }
      if (noSpace == 'category' ||
          noSpace == 'cate' ||
          noSpace == 'subject' ||
          noSpace == 'tag') {
        return 'category';
      }
      if (noSpace == 'note' ||
          noSpace == 'memo' ||
          noSpace == 'desc' ||
          noSpace == 'description' ||
          noSpace == 'remark' ||
          noSpace == 'title') {
        return 'note';
      }
      containsAny(String t, List<String> ks) => ks.any((k) => t.contains(k));
      if (containsAny(s, ['日期', '时间', '交易时间', '账单时间', '创建时间'])) {
        return 'date';
      }
      if (containsAny(s, ['类型', '收支', '方向', '交易类型'])) {
        return 'type';
      }
      if (containsAny(s, ['金额', '金额(元)', '交易金额', '变动金额', '收支金额'])) {
        return 'amount';
      }
      if (containsAny(s, ['分类', '类别', '账目名称', '科目', '标签'])) {
        return 'category';
      }
      if (containsAny(s, ['备注', '说明', '标题', '摘要', '附言'])) {
        return 'note';
      }
      // 明确忽略
      if (containsAny(s, ['账目编号', '编号', '单号', '流水号', '相关图片', '图片', '附件'])) {
        return null;
      }
      return null;
    }

    for (int i = 0; i < headers.length; i++) {
      final k = normalizeToKey(headers[i]);
      if (k != null && !mapping.containsKey(k)) continue; // skip unknown keys
      if (k != null && mapping[k] == null) mapping[k] = i;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (parsing) {
      return Scaffold(
        body: Column(
          children: const [
            PrimaryHeader(title: '解析中…', showBack: true),
            Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          ],
        ),
      );
    }
    final columnCount =
        rows.isNotEmpty ? rows[widget.hasHeader ? headerRow : 0].length : 0;
    List<DropdownMenuItem<int>> items() => List.generate(columnCount, (i) {
          final header = widget.hasHeader
              ? rows[headerRow]
              : (rows.isNotEmpty ? rows.first : const <String>[]);
          final label = (widget.hasHeader &&
                  i < header.length &&
                  header[i].trim().isNotEmpty)
              ? header[i].trim()
              : '第 ${i + 1} 列';
          return DropdownMenuItem(
              value: i, child: Text(label, overflow: TextOverflow.ellipsis));
        });

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrimaryHeader(title: step == 0 ? '确认映射' : '分类映射', showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (step == 0) ...[
                  if (rows.isEmpty) const Text('未解析到任何数据，请返回上一页检查 CSV 内容或分隔符。'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _mapRow('日期', 'date', items()),
                      _mapRow('类型', 'type', items()),
                      _mapRow('金额', 'amount', items()),
                      _mapRow('分类', 'category', items()),
                      _mapRow('备注', 'note', items()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 预览仅展示前 N 行，避免大文件一次性渲染导致卡顿
                  Text('预览：', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SizedBox(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Builder(builder: (_) {
                        const int maxPreview = 10; // 预览最多 100 行
                        final totalRows = rows.length;
                        final dataStart =
                            widget.hasHeader ? (headerRow + 1) : 0;
                        // 保证包含表头行 + 最多 maxPreview-1 行数据
                        final header = widget.hasHeader
                            ? [rows[headerRow]]
                            : <List<String>>[];
                        final body = totalRows > dataStart
                            ? () {
                                final take = (maxPreview - header.length);
                                final end = (dataStart + take <= totalRows)
                                    ? dataStart + take
                                    : totalRows;
                                return rows.sublist(dataStart, end);
                              }()
                            : const <List<String>>[];
                        final limited = [...header, ...body];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PreviewTable(rows: limited),
                            if (totalRows > limited.length)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  '仅预览前 ${limited.length} 行，共 $totalRows 行',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ] else ...[
                  if (mapping['category'] == null)
                    const Text('未选择“分类”列，请点击“上一步”返回并设置“分类”的列，再继续。'),
                  Text('请将左侧“源分类名”映射到系统内已有分类（或保持原名自动创建/合并）'),
                  const SizedBox(height: 8),
                  FutureBuilder<List<schema.Category>>(
                    future: allCategoriesFuture,
                    builder: (context, snap) {
                      final cats = snap.data ?? [];
                      final items = <DropdownMenuItem<int?>>[
                        const DropdownMenuItem(
                            value: null, child: Text('保持原名（自动创建/合并）')),
                        ...cats.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(
                                  '${c.name} (${c.kind == 'income' ? '收入' : '支出'})'),
                            )),
                      ];
                      return Column(
                        children: [
                          for (final name in distinctCategories)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 12),
                                  DropdownButton<int?>(
                                    value: categoryMapping[name],
                                    items: items,
                                    onChanged: (v) => setState(
                                        () => categoryMapping[name] = v),
                                  ),
                                ],
                              ),
                            )
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (importing) Text('导入中… 成功 $ok，失败 $fail'),
                  const Spacer(),
                  if (step == 0)
                    FilledButton(
                      onPressed: () {
                        if (mapping['category'] == null) {
                          showToast(context, '请先选择“分类”列再继续');
                          return;
                        }
                        _buildDistinctCategories();
                        setState(() => step = 1);
                      },
                      child: const Text('下一步'),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed:
                          importing ? null : () => setState(() => step = 0),
                      child: const Text('上一步'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: importing ? null : _startImport,
                      child: const Text('开始导入'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapRow(String label, String key, List<DropdownMenuItem<int>> items) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 64, child: Text(label)),
        const SizedBox(width: 8),
        SizedBox(
          width: 220,
          child: DropdownButton<int>(
            isExpanded: true,
            value: mapping[key],
            hint: const Text('自动'),
            items: items,
            onChanged: (v) => setState(() => mapping[key] = v),
          ),
        ),
      ],
    );
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

    final dataStart = widget.hasHeader ? (headerRow + 1) : 0;
    final total = rows.length - dataStart;
    // 初始化全局进度
    container.read(importProgressProvider.notifier).state = ImportProgress(
      running: true,
      total: total,
      done: 0,
      ok: 0,
      fail: 0,
    );

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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('正在导入…'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                    value: percent > 0 && percent < 1 ? percent : null),
                const SizedBox(height: 8),
                // 实时进度文案（每50条更新一次，足够流畅）
                Text('已完成：${p.done}/${p.total}，成功 ${p.ok}，失败 ${p.fail}',
                    style: Theme.of(dctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dialogOpen = false;
                  Navigator.of(dctx).pop();
                  // 返回到我的页面继续后台导入
                  if (mounted) {
                    Navigator.of(currentContext).popUntil((r) => r.isFirst);
                  }
                },
                child: const Text('后台导入'),
              ),
              TextButton(
                onPressed: () {
                  _cancelled = true;
                  dialogOpen = false;
                  Navigator.of(dctx).pop();
                },
                child: const Text('取消导入'),
              ),
            ],
          );
        });
      },
    );

    // 分类缓存：当选择“保持原名”时，按 (name, kind) 维度缓存 upsert 结果，避免重复查询
    final Map<String, int> incomeCatCache = {};
    final Map<String, int> expenseCatCache = {};
    // 批量缓冲
    const int batchSize = 500;
    final List<schema.TransactionsCompanion> batch = [];
    int done = 0;

    Future<void> flushBatch() async {
      if (batch.isEmpty) return;
      try {
        final inserted = await repo.insertTransactionsBatch(batch);
        ok += inserted;
      } catch (_) {
        // 回退到逐条插入，尽可能保留成功数
        for (final item in batch) {
          if (_cancelled) break;
          try {
            await repo.db.into(repo.db.transactions).insert(item);
            ok++;
          } catch (_) {
            fail++;
          }
        }
      } finally {
        batch.clear();
        // 批次完成后更新一次进度
        container.read(importProgressProvider.notifier).state = ImportProgress(
            running: true, total: total, done: done, ok: ok, fail: fail);
        await Future<void>.delayed(Duration.zero);
        if (mounted) setState(() {});
      }
    }

    for (int i = dataStart; i < rows.length; i++) {
      if (_cancelled) break;
      final r = rows[i];
      try {
        String? getBy(String key, int fallback) {
          final userIdx = mapping[key];
          if (userIdx != null && userIdx >= 0 && userIdx < r.length) {
            return r[userIdx].toString();
          }
          return fallback < r.length ? r[fallback].toString() : null;
        }

        final dateStr = getBy('date', 0);
        var typeRaw = getBy('type', 1) ?? 'expense';
        final amountStr = getBy('amount', 2);
        final categoryName = getBy('category', 3);
        final note = getBy('note', 4);

        // 类型中文到内部值
        final lower = typeRaw.trim().toLowerCase();
        final type =
            (lower == '收入' || lower == 'income') ? 'income' : 'expense';

        // 金额解析
        final amountClean =
            (amountStr ?? '0').toString().replaceAll(RegExp(r'[¥$,]'), '');
        final amount = double.parse(amountClean);

        // 日期解析
        DateTime date;
        if (dateStr == null || dateStr.trim().isEmpty) {
          date = DateTime.now();
        } else {
          DateTime? tryParse(String s) {
            try {
              return DateTime.parse(s);
            } catch (_) {
              return null;
            }
          }

          DateTime? d = tryParse(dateStr);
          d ??= _tryParseWithFormats(dateStr, [
            'yyyy-MM-dd HH:mm:ss',
            'yyyy-MM-dd HH:mm',
            'yyyy/MM/dd HH:mm:ss',
            'yyyy/MM/dd HH:mm',
            'yyyy-MM-dd',
            'yyyy/M/d',
            'yyyy/MM/dd',
          ]);
          date = (d ?? DateTime.now()).toLocal();
        }

        int? categoryId;
        if (categoryName != null && categoryName.trim().isNotEmpty) {
          final name = categoryName.trim();
          final chosen = categoryMapping[name];
          if (chosen != null) {
            categoryId = chosen;
          } else {
            if (type == 'income') {
              final cached = incomeCatCache[name];
              if (cached != null) {
                categoryId = cached;
              } else {
                final id =
                    await repo.upsertCategory(name: name, kind: 'income');
                incomeCatCache[name] = id;
                categoryId = id;
              }
            } else {
              final cached = expenseCatCache[name];
              if (cached != null) {
                categoryId = cached;
              } else {
                final id =
                    await repo.upsertCategory(name: name, kind: 'expense');
                expenseCatCache[name] = id;
                categoryId = id;
              }
            }
          }
        }

        // 构造行
        final item = schema.TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: type,
          amount: amount,
          categoryId: d.Value(categoryId),
          accountId: const d.Value(null),
          toAccountId: const d.Value(null),
          happenedAt: d.Value(date),
          note: d.Value(note),
        );
        batch.add(item);
      } catch (_) {
        fail++;
      }
      done++;

      // 达到批量阈值则落库一次
      if (batch.length >= batchSize) {
        await flushBatch();
        // 当文件巨大时，主动让出一帧，避免 UI 卡顿
        await Future<void>.delayed(Duration.zero);
      }
      // 降低频率的进度更新（不依赖落库）
      if (done % 50 == 0 || done == total || _cancelled) {
        container.read(importProgressProvider.notifier).state = ImportProgress(
            running: true, total: total, done: done, ok: ok, fail: fail);
        await Future<void>.delayed(Duration.zero);
        if (mounted) setState(() {});
      }
    }

    // 刷新剩余缓冲
    await flushBatch();

    // 即使页面已被关闭（mounted=false），也要继续更新全局进度供"我的"页展示
    // 先切换为"完成"以驱动 UI 展示成功动画/提示（不等待云上传）
    try {
      container.read(importProgressProvider.notifier).state = ImportProgress(
        running: false,
        total: total,
        done: done,
        ok: ok,
        fail: fail,
      );
    } catch (e) {}

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
        } catch (e) {}
      });
    }

    // Check if context is still mounted for UI operations
    if (!context.mounted) {
      return;
    }

    // 显示导入完成提示
    final cancelledText = _cancelled ? '（已取消）' : '';
    showToast(context, '导入完成$cancelledText：成功 $ok 条，失败 $fail 条');

    // Handle UI operations before cloud upload
    if (dialogOpen) {
      Navigator.of(currentContext).pop();
    }
    // 关闭确认页 -> 返回到我的页面
    Navigator.of(currentContext).popUntil((r) => r.isFirst);
    // 返回后再显式刷新一次全局统计，确保顶部汇总即时更新
    try {
      container.read(statsRefreshProvider.notifier).state++;
    } catch (_) {}

    // 导入完成后，云上传改为后台并行执行，不阻塞 UI
    () async {
      try {
        final sync = container.read(syncServiceProvider);
        await sync.uploadCurrentLedger(ledgerId: ledgerId);
        // 上传完成后再触发一次状态刷新（若站点有变更则更新）
        container.read(syncStatusRefreshProvider.notifier).state++;
      } catch (_) {}
    }();
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
    categoryMapping = {for (final n in distinctCategories) n: null};
  }
}

DateTime? _tryParseWithFormats(String input, List<String> formats) {
  for (final f in formats) {
    try {
      final d = DateFormat(f).parse(input, true);
      return d;
    } catch (_) {}
  }
  return null;
}

List<List<String>> _parseRows(String input) {
  // 规范化换行并移除 UTF-8 BOM
  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }

  final lines = text
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) return const [];

  // 1. 先尝试自动检测常规分隔符（逗号/制表符/分号/竖线）
  final delimiter = _detectDelimiter(lines);

  List<List<String>> parsed;
  if (delimiter == 'space') {
    parsed = lines.map((l) => _splitSpaceSeparatedLine(l)).toList();
  } else {
    parsed = lines.map((l) => _splitDelimitedLine(l, delimiter)).toList();
  }

  // 2. 如果仍然全部只有 1 列（说明可能不是上述分隔符），且文本出现了连续双空格/制表符，再次尝试空白分隔
  final multiColumn = parsed.any((r) => r.length > 1);
  if (!multiColumn) {
    final hasMultiSpaces = RegExp(r' {2,}').hasMatch(text);
    final hasTab = text.contains('\t');
    if (hasTab) {
      final tabParsed = lines.map((l) => _splitDelimitedLine(l, '\t')).toList();
      if (tabParsed.any((r) => r.length > 1)) return tabParsed;
    }
    if (hasMultiSpaces) {
      final spaceParsed = lines.map(_splitSpaceSeparatedLine).toList();
      if (spaceParsed.any((r) => r.length > 1)) return spaceParsed;
    }
  }

  return parsed;
}

// isolate 入口函数：在后台解析 CSV 文本
List<List<String>> _parseRowsIsolate(String input) {
  return _parseRows(input);
}

// 自动检测首若干行的分隔符（不进入引号内部）：优先级：逗号 > 制表符 > 分号 > 竖线；都没有再考虑空格
String _detectDelimiter(List<String> lines) {
  final maxLines = lines.length < 20 ? lines.length : 20;
  final counts = <String, int>{',': 0, '\t': 0, ';': 0, '|': 0};
  for (int i = 0; i < maxLines; i++) {
    final l = lines[i];
    bool inQuotes = false;
    for (int j = 0; j < l.length; j++) {
      final ch = l[j];
      if (ch == '"') {
        if (inQuotes && j + 1 < l.length && l[j + 1] == '"') {
          j++; // 跳过转义
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes) {
        if (counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
      }
    }
  }
  // 选择出现次数最多的分隔符（>0）
  String? best;
  int bestCount = 0;
  counts.forEach((k, v) {
    if (v > bestCount) {
      best = k;
      bestCount = v;
    }
  });
  if (best != null && bestCount > 0) return best!;
  // 检查是否存在连续多空格用于分隔
  final hasMultiSpaces =
      lines.take(maxLines).any((l) => RegExp(r' {2,}').hasMatch(l));
  if (hasMultiSpaces) return 'space';
  // 默认回退逗号（保持与以前行为兼容）
  return ',';
}

// 拆分一行：适用于明确单字符分隔符（逗号/制表符/分号/竖线），支持双引号转义
List<String> _splitDelimitedLine(String line, String delimiter) {
  final out = <String>[];
  final buf = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes && ch == delimiter) {
      out.add(_cleanCsvField(buf.toString()));
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  out.add(_cleanCsvField(buf.toString()));
  return out;
}

// 空格（或多个空格）分隔的行拆分：忽略引号内空格；多个连续空格视为一个分隔
List<String> _splitSpaceSeparatedLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  bool inQuotes = false;
  int spaceRun = 0;
  void pushBuf() {
    out.add(_cleanCsvField(buf.toString()));
    buf.clear();
  }

  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      spaceRun = 0;
      continue;
    }
    if (!inQuotes && ch == ' ') {
      spaceRun++;
      if (spaceRun == 1) {
        // 先标记一次空格，等待看是否为分隔符（需要 >=1 且前面已有内容）
      }
      continue;
    }
    // 碰到非空格字符
    if (!inQuotes && spaceRun > 0) {
      // 之前累积的空格作为分隔符（忽略行首空格）
      if (buf.isNotEmpty) {
        pushBuf();
      }
      spaceRun = 0;
    }
    buf.write(ch);
  }
  // 行尾 push
  if (buf.isNotEmpty) {
    pushBuf();
  }
  return out;
}

String _cleanCsvField(String raw) {
  var s = raw.trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    s = s.substring(1, s.length - 1).replaceAll('""', '"').trim();
  }
  return s;
}

//（保留占位注释：以前这里有自动表头行识别，现固定第一行作为表头）

Future<List<schema.Category>> _loadAllCategories(WidgetRef ref) async {
  final db = ref.read(databaseProvider);
  final expense = await (db.select(db.categories)
        ..where((c) => c.kind.equals('expense')))
      .get();
  final income = await (db.select(db.categories)
        ..where((c) => c.kind.equals('income')))
      .get();
  return [...expense, ...income];
}

class _PreviewTable extends StatelessWidget {
  final List<List<String>> rows;
  // 预览表格: 固定单元格宽度，避免在横向滚动环境中使用 Expanded 触发布局错误
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    const double cellWidth = 140;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (int r = 0; r < rows.length; r++)
              Container(
                color: r == 0 ? Colors.grey.shade100 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  children: [
                    for (final cell in rows[r])
                      SizedBox(
                        width: cellWidth,
                        child: Text(
                          cell,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: r == 0 ? FontWeight.w600 : null,
                          ),
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
