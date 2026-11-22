/// 物品页(Cloud 0038/0040 对接)。物品档案 + 关联流水 + 成本展示。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/secondary/cloud_secondary_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cloud_secondary_providers.dart';
import '../shared/pickers/wheel_date_picker.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'base_cloud_list.dart';

class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends CloudListState<ItemsPage> {
  @override
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service) =>
      service.listItems();

  Future<void> _showCreate() async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime purchased = DateTime.now();

    final ok = await showBeeDialog<bool>(
      context,
      title: l.cloudItemNew,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BeeField(label: l.cloudName, controller: nameCtrl),
          const SizedBox(height: 10),
          BeeField(label: l.cloudItemPrice, controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          BeeMenuRow(
            title: l.cloudItemPurchasedAt,
            subtitle: dateText(purchased.toIso8601String()),
            leading: const BeeLineIcon('CalendarDays', size: 20),
            onTap: () async {
              final picked = await showWheelDatePicker(context, initial: purchased);
              if (picked != null) purchased = picked;
            },
          ),
          const SizedBox(height: 10),
          BeeField(label: l.cloudItemLocation, controller: locationCtrl),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        BeeButton(label: l.commonSave, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final price = double.tryParse(BeeDecimalInputFormatter.normalize(priceCtrl.text));
    await act((s) => s.createItem({
      'name': nameCtrl.text.trim(),
      'price': price,
      'purchased_at': purchased.toUtc().toIso8601String(),
      'location': locationCtrl.text.trim(),
    }), successMessage: l.cloudSaveSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeatureItems,
          actions: [
            BeeIconButton(
              label: l.cloudItemNew,
              icon: const BeeLineIcon('Plus'),
              onPressed: _showCreate,
            ),
          ],
        ),
        Expanded(
          child: buildBody(
            emptyText: l.cloudItemEmpty,
            itemBuilder: (context, i) {
              final item = rows[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
                  title: Text(nameOf(item)),
                  subtitle: Text([
                    '${l.cloudItemPrice}: ${item['price'] ?? 0}',
                    (item['location'] ?? '').toString(),
                    dateText(item['purchased_at']),
                  ].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'delete') {
                        final ok = await confirmDelete(
                            l.commonDelete, l.cloudDeleteConfirmSimple);
                        if (ok) await act((s) => s.deleteItem(idOf(item)));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
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
