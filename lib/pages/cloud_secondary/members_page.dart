/// 消费成员页(Cloud 0024 对接)。
/// 注意：这里的「消费成员」与共享账本协作者 LedgerMembers 完全不同。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/secondary/cloud_secondary_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cloud_secondary_providers.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'base_cloud_list.dart';

class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends CloudListState<MembersPage> {
  @override
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service) =>
      service.listMembers();

  Future<void> _showCreate() async {
    final l = AppLocalizations.of(context);
    final name = await askName(l.cloudMemberNew, l.cloudName);
    if (name == null) return;
    await act((s) => s.createMember({'name': name}),
        successMessage: l.cloudSaveSuccess);
  }

  Future<void> _showStats() async {
    final l = AppLocalizations.of(context);
    final service = await ref.read(cloudSecondaryServiceProvider.future);
    if (service == null || !mounted) return;
    final stats = await service.memberStats();
    if (!mounted) return;
    // member-stats 返回结构：{items: [{name, income, expense, net}...]}
    final items = (stats['items'] as List?) ?? const [];
    await showBeeSheet(
      context,
      title: l.cloudMemberStats,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (items.isEmpty)
          Text(l.cloudMemberEmpty)
        else
          ...items.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return ListTile(
              title: Text((m['name'] ?? '').toString()),
              subtitle: Text(
                '${l.cloudMemberIncome}: ${m['income'] ?? 0}  '
                '${l.cloudMemberExpense}: ${m['expense'] ?? 0}  '
                '${l.cloudMemberNet}: ${m['net'] ?? 0}',
              ),
            );
          }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeatureContacts,
          actions: [
            BeeIconButton(
              label: l.cloudMemberStats,
              icon: const BeeLineIcon('ChartNoAxesCombined'),
              onPressed: _showStats,
            ),
            BeeIconButton(
              label: l.cloudMemberNew,
              icon: const BeeLineIcon('Plus'),
              onPressed: _showCreate,
            ),
          ],
        ),
        Expanded(
          child: buildBody(
            emptyText: l.cloudMemberEmpty,
            itemBuilder: (context, i) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(nameOf(rows[i])),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
