import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import '../widgets/primary_header.dart';

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
            showBack: true,
            actions: [
              IconButton(
                onPressed: () async {
                  final result =
                      await showDialog<(String name, String currency)?>(
                    context: context,
                    builder: (ctx) {
                      final c = TextEditingController();
                      String currency = 'CNY';
                      return AlertDialog(
                        title: const Text('新建账本'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                                controller: c,
                                decoration:
                                    const InputDecoration(labelText: '名称')),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration:
                                  const InputDecoration(labelText: '币种'),
                              value: currency,
                              items: const [
                                DropdownMenuItem(
                                    value: 'CNY', child: Text('CNY 人民币')),
                                DropdownMenuItem(
                                    value: 'USD', child: Text('USD 美元')),
                                DropdownMenuItem(
                                    value: 'EUR', child: Text('EUR 欧元')),
                                DropdownMenuItem(
                                    value: 'JPY', child: Text('JPY 日元')),
                              ],
                              onChanged: (v) => currency = v ?? 'CNY',
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, (c.text, currency)),
                              child: const Text('确定')),
                        ],
                      );
                    },
                  );
                  if (result != null && result.$1.trim().isNotEmpty) {
                    await repo.createLedger(
                        name: result.$1.trim(), currency: result.$2);
                  }
                },
                icon: const Icon(Icons.add, color: Colors.black),
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
                        // 长按编辑
                        final newName = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            final c = TextEditingController(text: l.name);
                            return AlertDialog(
                              title: const Text('编辑账本'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: c,
                                    decoration:
                                        const InputDecoration(labelText: '名称'),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('币种：${l.currency}（不可修改）',
                                      style: Theme.of(ctx).textTheme.bodySmall),
                                ],
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, c.text.trim()),
                                    child: const Text('保存')),
                              ],
                            );
                          },
                        );
                        if (newName != null && newName.isNotEmpty) {
                          await repo.updateLedgerName(id: l.id, name: newName);
                          // 提示同步中（占位）
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                    SizedBox(width: 12),
                                    Text('同步账本中...'),
                                  ],
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
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
              color: Colors.black.withValues(alpha: 0.05),
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
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
                  Text('币种：${ledger.currency}',
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
