import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import '../widgets/ui/ui.dart';
import '../utils/currencies.dart';
import '../utils/sync_helpers.dart';
import '../utils/logger.dart';

class LedgersPage extends ConsumerWidget {
  const LedgersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final currentId = ref.watch(currentLedgerIdProvider);
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: '账本管理',
            showBack: false,
            actions: [
              IconButton(
                onPressed: () async {
                  final res =
                      await _showLedgerEditorDialog(context, title: '新建账本');
                  if (res != null && res.name.trim().isNotEmpty) {
                    await repo.createLedger(
                        name: res.name.trim(), currency: res.currency);
                  }
                },
                icon: const Icon(Icons.add, color: Colors.black),
              ),
              IconButton(
                tooltip: '清空当前账本',
                onPressed: () async {
                  final id = ref.read(currentLedgerIdProvider);
                  final confirm = await AppDialog.confirm<bool>(context,
                      title: '清空当前账本？', message: '将删除该账本下所有交易记录，且不可恢复。');

                  if (confirm == true) {
                    final n = await repo.clearLedgerTransactions(id);
                    // 清空后触发一次同步处理（后台），并刷新同步状态
                    await handleLocalChange(ref,
                        ledgerId: id, background: true);
                    // 刷新：当前账本计数卡片、我的页全局统计与同步状态
                    ref.invalidate(countsForLedgerProvider(id));
                    ref.read(statsRefreshProvider.notifier).state++;
                    ref.read(syncStatusRefreshProvider.notifier).state++;
                    if (context.mounted) {
                      showToast(context, '已删除 $n 条记录');
                    }
                  }
                },
                icon: const Icon(Icons.delete_sweep_outlined,
                    color: Colors.black),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Ledger>>(
              stream: repo.ledgers(),
              builder: (context, snapshot) {
                final ledgers = snapshot.data ?? [];
                
                // 保护性检查：如果currentId指向的账本不存在，自动切换到第一个账本
                if (ledgers.isNotEmpty && !ledgers.any((l) => l.id == currentId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(currentLedgerIdProvider.notifier).state = ledgers.first.id;
                  });
                }
                
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: ledgers.length,
                  itemBuilder: (ctx, i) {
                    final l = ledgers[i];
                    final selected = l.id == currentId;
                    return _LedgerCard(
                      ledger: l,
                      selected: selected,
                      onTap: () async {
                        // 点击切换账本
                        ref.read(currentLedgerIdProvider.notifier).state = l.id;
                      },
                      onLongPress: () async {
                        // 长按：弹出“编辑 / 删除”居中原生对话框（SimpleDialog）
                        final action = await showDialog<String>(
                          context: context,
                          builder: (dctx) {
                            final primary = Theme.of(dctx).colorScheme.primary;
                            return SimpleDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('操作'),
                              children: [
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(dctx, 'edit'),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: primary),
                                      const SizedBox(width: 8),
                                      const Text('编辑'),
                                    ],
                                  ),
                                ),
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(dctx, 'delete'),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete_forever_outlined,
                                          color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text('删除'),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );

                        if (action == 'edit') {
                          final res = await _showLedgerEditorDialog(context,
                              title: '编辑账本',
                              initialName: l.name,
                              initialCurrency: l.currency);
                          if (res != null && res.name.trim().isNotEmpty) {
                            final repo = ref.read(repositoryProvider);
                            await repo.updateLedger(
                                id: l.id,
                                name: res.name.trim(),
                                currency: res.currency);
                          }
                        } else if (action == 'delete') {
                          final ok = await AppDialog.confirm<bool>(context,
                                  title: '删除账本',
                                  message:
                                      '确定要删除该账本及其全部记录吗？此操作不可恢复。\n若云端存在备份，也会一并删除。') ??
                              false;
                          if (!ok) return;
                          final repo = ref.read(repositoryProvider);
                          final sync = ref.read(syncServiceProvider);
                          final current = ref.read(currentLedgerIdProvider);
                          try {
                            // 先确定新的currentLedgerId，避免删除后的时序问题
                            if (current == l.id) {
                              final allLedgers =
                                  await repo.db.select(repo.db.ledgers).get();
                              final remainAfterDelete = allLedgers.where((ledger) => ledger.id != l.id).toList();
                              int newId = 1;
                              if (remainAfterDelete.isNotEmpty) {
                                newId = remainAfterDelete.first.id;
                              } else {
                                // 若全部删除（极端情况），重新种子并取默认账本
                                await repo.db.ensureSeed();
                                final list =
                                    await repo.db.select(repo.db.ledgers).get();
                                newId = list.first.id;
                              }
                              // 在删除之前就切换到新账本，避免UI闪烁/灰屏
                              ref.read(currentLedgerIdProvider.notifier).state =
                                  newId;
                            }
                            // 现在安全删除账本
                            await repo.deleteLedger(l.id);
                            // 删除云端备份（忽略 404）
                            try {
                              await sync.deleteRemoteBackup(ledgerId: l.id);
                            } catch (e) {
                              logW('ledger', '删除云端备份失败（忽略）：$e');
                            }
                            // 刷新统计与同步状态
                            ref.read(statsRefreshProvider.notifier).state++;
                            ref
                                .read(syncStatusRefreshProvider.notifier)
                                .state++;
                            if (context.mounted) showToast(context, '已删除');
                          } catch (e) {
                            if (context.mounted) {
                              await AppDialog.error(context,
                                  title: '删除失败', message: '$e');
                            }
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // 新建账本移到右上角 + 头部 actions
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final Ledger ledger;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _LedgerCard(
      {required this.ledger,
      required this.selected,
      required this.onTap,
      this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: selected
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.check_circle, color: Colors.green),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ledger.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('币种：${displayCurrency(ledger.currency)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  // 显示该账本的总笔数
                  _LedgerTxCount(ledgerId: ledger.id),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _LedgerTxCount extends ConsumerWidget {
  final int ledgerId;
  const _LedgerTxCount({required this.ledgerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(countsForLedgerProvider(ledgerId));
    final n = counts.asData?.value.txCount;
    return Text(
      '笔数：${n ?? '…'}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

Future<String?> _showCurrencyPicker(BuildContext context,
    {String? initial}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (bctx) {
      String query = '';
      String? selected = initial;
      return StatefulBuilder(builder: (sctx, setState) {
        final filtered = kCurrencies.where((c) {
          final q = query.trim();
          if (q.isEmpty) return true;
          final uq = q.toUpperCase();
          return c.code.contains(uq) || c.name.contains(q);
        }).toList();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(bctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Text('选择币种', style: Theme.of(bctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索：中文或代码',
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final sel = c.code == selected;
                      return ListTile(
                        title: Text('${c.name} (${c.code})'),
                        trailing: sel
                            ? const Icon(Icons.check, color: Colors.black)
                            : null,
                        onTap: () => Navigator.pop(bctx, c.code),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      });
    },
  );
}

// 统一的“新建/编辑账本”弹窗，支持修改名称与币种
Future<({String name, String currency})?> _showLedgerEditorDialog(
  BuildContext context, {
  String title = '编辑账本',
  String? initialName,
  String? initialCurrency,
}) async {
  String name = initialName ?? '';
  String currency = initialCurrency ?? 'CNY';
  final nameCtrl = TextEditingController(text: name);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final primary = Theme.of(ctx).colorScheme.primary;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: StatefulBuilder(builder: (ctx, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('币种'),
                subtitle: Text(displayCurrency(currency)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked =
                      await _showCurrencyPicker(ctx, initial: currency);
                  if (picked != null) {
                    setState(() => currency = picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
                    ),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(title.contains('新建') ? '创建' : '保存'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
      );
    },
  );
  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
    return (name: nameCtrl.text.trim(), currency: currency);
  }
  return null;
}
