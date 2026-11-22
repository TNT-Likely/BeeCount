/// 联系人管理页(Cloud 0026/0042/0066 对接)。
/// 列表 + 状态筛选 + 新建 + 归档/恢复/停用/启用动作。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/secondary/cloud_secondary_service.dart';
import '../../l10n/app_localizations.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'base_cloud_list.dart';

final _contactStateProvider = StateProvider<String>((ref) => 'active');

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends CloudListState<ContactsPage> {
  @override
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service) =>
      service.listContacts(state: ref.read(_contactStateProvider));

  Future<void> _showCreate() async {
    final l = AppLocalizations.of(context);
    final name = await askName(l.cloudContactNew, l.cloudContactName);
    if (name == null) return;
    await act((s) => s.createContact({'name': name}),
        successMessage: l.cloudContactCreated);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(_contactStateProvider);
    ref.listen<String>(_contactStateProvider, (_, __) => load());

    final states = [
      ('active', l.cloudContactStateActive),
      ('all', l.cloudContactStateAll),
      ('archived', l.cloudContactStateArchived),
      ('disabled', l.cloudContactStateDisabled),
    ];

    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeatureContacts,
          actions: [
            BeeIconButton(
              label: l.cloudContactNew,
              icon: const BeeLineIcon('UserRoundPlus'),
              onPressed: _showCreate,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (key, label) in states) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: state == key,
                    onSelected: (_) =>
                        ref.read(_contactStateProvider.notifier).state = key,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: buildBody(
            emptyText: l.cloudContactEmpty,
            itemBuilder: (context, i) {
              final c = rows[i];
              final archived = c['is_archived'] == true;
              final active = c['is_active'] != false;
              final tags = <String>[
                if (archived) l.cloudContactStateArchived,
                if (!active) l.cloudContactStateDisabled,
              ];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(nameOf(c)),
                  subtitle: tags.isEmpty ? null : Text(tags.join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == '__delete') {
                        final ok = await confirmDelete(
                            l.commonDelete, l.cloudContactDeleteConfirm);
                        if (ok) await act((s) => s.deleteContact(idOf(c)));
                        return;
                      }
                      await act((s) => s.contactAction(idOf(c), action));
                    },
                    itemBuilder: (_) => [
                      if (archived)
                        PopupMenuItem(
                            value: 'unarchive',
                            child: Text(l.cloudContactUnarchive))
                      else
                        PopupMenuItem(
                            value: 'archive', child: Text(l.cloudContactArchive)),
                      if (active)
                        PopupMenuItem(
                            value: 'disable', child: Text(l.cloudContactDisable))
                      else
                        PopupMenuItem(
                            value: 'enable', child: Text(l.cloudContactEnable)),
                      PopupMenuItem(
                          value: '__delete', child: Text(l.commonDelete)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
