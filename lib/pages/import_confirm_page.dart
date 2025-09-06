import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../widgets/primary_header.dart';
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
  late List<List<String>> rows;
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
  List<String> distinctCategories = [];
  Map<String, int?> categoryMapping = {}; // 源分类名 -> 目标分类ID（null表示保持原名）
  Future<List<schema.Category>>? allCategoriesFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('[ImportConfirm] raw length=${widget.csvText.length}');
    rows = _parseRows(widget.csvText);
    debugPrint(
        '[ImportConfirm] parsed rows=${rows.length} cols=${rows.isNotEmpty ? rows.first.length : 0}');
    _autoDetectMapping();
    // 预取分类列表供第二步选择
    allCategoriesFuture = _loadAllCategories(ref);
  }

  void _autoDetectMapping() {
    if (rows.isEmpty || !widget.hasHeader) return;
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    String? normalizeToKey(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final lower = s.toLowerCase();
      final noSpace = lower.replaceAll(RegExp(r'\s+'), '');
      if (noSpace == 'date' || noSpace == 'time' || noSpace == 'datetime')
        return 'date';
      if (noSpace == 'type' || noSpace == 'inout' || noSpace == 'direction')
        return 'type';
      if (noSpace == 'amount' ||
          noSpace == 'money' ||
          noSpace == 'price' ||
          noSpace == 'value') return 'amount';
      if (noSpace == 'category' ||
          noSpace == 'cate' ||
          noSpace == 'subject' ||
          noSpace == 'tag') return 'category';
      if (noSpace == 'note' ||
          noSpace == 'memo' ||
          noSpace == 'desc' ||
          noSpace == 'description' ||
          noSpace == 'remark' ||
          noSpace == 'title') return 'note';
      containsAny(String t, List<String> ks) => ks.any((k) => t.contains(k));
      if (containsAny(s, ['日期', '时间', '交易时间', '账单时间', '创建时间'])) return 'date';
      if (containsAny(s, ['类型', '收支', '方向', '交易类型'])) return 'type';
      if (containsAny(s, ['金额', '金额(元)', '交易金额', '变动金额', '收支金额']))
        return 'amount';
      if (containsAny(s, ['分类', '类别', '账目名称', '科目', '标签'])) return 'category';
      if (containsAny(s, ['备注', '说明', '标题', '摘要', '附言'])) return 'note';
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
    final columnCount = rows.isNotEmpty ? rows.first.length : 0;
    List<DropdownMenuItem<int>> items() => List.generate(columnCount, (i) {
          final label = (widget.hasHeader &&
                  i < rows.first.length &&
                  rows.first[i].trim().isNotEmpty)
              ? rows.first[i].trim()
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
                if (kDebugMode) ...[
                  Card(
                    elevation: 0,
                    color: Colors.grey.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '调试：rows=${rows.length}, cols=${rows.isNotEmpty ? rows.first.length : 0}'),
                          if (rows.isNotEmpty)
                            Text('表头: ${rows.first.join(', ')}',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(
                              '映射: date=${mapping['date']}, type=${mapping['type']}, amount=${mapping['amount']}, category=${mapping['category']}, note=${mapping['note']}')
                        ],
                      ),
                    ),
                  ),
                ],
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
                  Text('预览：', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 260,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _PreviewTable(rows: rows),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请先选择“分类”列再继续')),
                          );
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
        DropdownButton<int>(
          value: mapping[key],
          hint: const Text('自动'),
          items: items,
          onChanged: (v) => setState(() => mapping[key] = v),
        ),
      ],
    );
  }

  Future<void> _startImport() async {
    setState(() {
      importing = true;
      ok = 0;
      fail = 0;
    });
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);

    for (int i = widget.hasHeader ? 1 : 0; i < rows.length; i++) {
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
        String type;
        if (lower == '收入' || lower == 'income') {
          type = 'income';
        } else {
          type = 'expense';
        }

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
          final chosen = categoryMapping[categoryName.trim()];
          if (chosen != null) {
            categoryId = chosen;
          } else {
            final kind = (type == 'income') ? 'income' : 'expense';
            categoryId = await repo.upsertCategory(
                name: categoryName.trim(), kind: kind);
          }
        }
        await repo.addTransaction(
          ledgerId: ledgerId,
          type: type,
          amount: amount,
          happenedAt: date,
          note: note,
          categoryId: categoryId,
        );
        ok++;
      } catch (_) {
        fail++;
      }
      if (mounted) setState(() {});
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入完成：成功 $ok 条，失败 $fail 条')),
    );
    Navigator.pop(context, ok);
  }

  void _buildDistinctCategories() {
    final catIdx = mapping['category'];
    if (catIdx == null) {
      distinctCategories = [];
      categoryMapping = {};
      return;
    }
    final set = <String>{};
    for (int i = widget.hasHeader ? 1 : 0; i < rows.length; i++) {
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
  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  if (text.contains('\t')) {
    try {
      return const CsvToListConverter(fieldDelimiter: '\t')
          .convert(text)
          .map((r) => r.map((e) => (e?.toString() ?? '').trim()).toList())
          .toList();
    } catch (e) {
      debugPrint('[ImportConfirm] TSV parse error: $e');
    }
  }
  if (text.contains(',')) {
    try {
      return const CsvToListConverter(fieldDelimiter: ',')
          .convert(text)
          .map((r) => r.map((e) => (e?.toString() ?? '').trim()).toList())
          .toList();
    } catch (e) {
      debugPrint('[ImportConfirm] CSV parse error: $e');
    }
  }
  final ws = RegExp(r'[ \t\u00A0\u3000]+');
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
  return lines.map((l) => l.trim().split(ws).toList()).toList();
}

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
