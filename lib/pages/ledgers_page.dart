import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import '../widgets/ui/ui.dart';
import '../utils/currencies.dart';
import '../utils/sync_helpers.dart';

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
                  // 复用编辑弹窗的样式：此处作为“新建”用途，允许选择币种
                  String name = '';
                  String currency = 'CNY';
                  final nameCtrl = TextEditingController(text: name);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      final primary = Theme.of(ctx).colorScheme.primary;
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        contentPadding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('新建账本',
                                textAlign: TextAlign.center,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nameCtrl,
                              decoration:
                                  const InputDecoration(labelText: '名称'),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('币种'),
                              subtitle: Text(displayCurrency(currency)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final picked = await _showCurrencyPicker(ctx,
                                    initial: currency);
                                if (picked != null) {
                                  currency = picked;
                                  (ctx as Element).markNeedsBuild();
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
                                  child: const Text('创建'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      );
                    },
                  );
                  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
                    await repo.createLedger(
                        name: nameCtrl.text.trim(), currency: currency);
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
                        // 长按编辑：统一标准弹窗（标题与按钮居中，取消为主题色描边）
                        String name = l.name;
                        String currency = l.currency;
                        final nameCtrl = TextEditingController(text: name);
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            final primary = Theme.of(ctx).colorScheme.primary;
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              contentPadding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('编辑账本',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: nameCtrl,
                                    decoration:
                                        const InputDecoration(labelText: '名称'),
                                  ),
                                  const SizedBox(height: 12),
                                  // 编辑模式下禁用币种修改
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('币种'),
                                    subtitle: Text(displayCurrency(currency)),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: primary,
                                          side: BorderSide(color: primary),
                                        ),
                                        child: const Text('取消'),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('保存'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            );
                          },
                        );
                        if (ok == true) {
                          final newName = nameCtrl.text.trim();
                          final changedName =
                              newName.isNotEmpty && newName != l.name;
                          final changedCcy =
                              currency.isNotEmpty && currency != l.currency;
                          if (changedName || changedCcy) {
                            await repo.updateLedger(
                                id: l.id,
                                name: changedName ? newName : null,
                                currency: changedCcy ? currency : null);
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
                ],
              ),
            )
          ],
        ),
      ),
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
