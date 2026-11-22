/// 定期存款页(Cloud 0031 对接)。存单列表 + 新建 + 支取/转存。
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

class DepositsPage extends ConsumerStatefulWidget {
  const DepositsPage({super.key});

  @override
  ConsumerState<DepositsPage> createState() => _DepositsPageState();
}

class _DepositsPageState extends CloudListState<DepositsPage> {
  @override
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service) =>
      service.listDeposits();

  String _statusText(String? s) {
    final l = AppLocalizations.of(context);
    switch (s) {
      case 'matured': return l.cloudDepositMatured;
      case 'withdrawn': return l.cloudDepositWithdrawn;
      case 'renewed': return l.cloudDepositRenewed;
      default: return l.cloudDepositHolding;
    }
  }

  Future<void> _showCreate() async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final principalCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final termCtrl = TextEditingController(text: '12');
    DateTime started = DateTime.now();

    final ok = await showBeeDialog<bool>(
      context,
      title: l.cloudDepositNew,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BeeField(label: l.cloudName, controller: nameCtrl),
          const SizedBox(height: 10),
          BeeField(label: l.cloudDepositPrincipal, controller: principalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          BeeField(label: l.cloudDepositRate, controller: rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          BeeField(label: l.cloudDepositTerm, controller: termCtrl,
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          BeeMenuRow(
            title: l.cloudDate,
            subtitle: dateText(started.toIso8601String()),
            leading: const BeeLineIcon('CalendarDays', size: 20),
            onTap: () async {
              final picked = await showWheelDatePicker(context, initial: started);
              if (picked != null) started = picked;
            },
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        BeeButton(label: l.commonSave, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final principal = double.tryParse(BeeDecimalInputFormatter.normalize(principalCtrl.text));
    final rate = double.tryParse(BeeDecimalInputFormatter.normalize(rateCtrl.text));
    final term = int.tryParse(termCtrl.text.trim());
    await act((s) => s.createDeposit({
      'name': nameCtrl.text.trim(),
      'principal': principal,
      'annual_rate': rate,
      'term_months': term,
      'started_at': started.toUtc().toIso8601String(),
    }), successMessage: l.cloudSaveSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeatureDeposits,
          actions: [
            BeeIconButton(
              label: l.cloudDepositNew,
              icon: const BeeLineIcon('Plus'),
              onPressed: _showCreate,
            ),
          ],
        ),
        Expanded(
          child: buildBody(
            emptyText: l.cloudDepositEmpty,
            itemBuilder: (context, i) {
              final dep = rows[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.account_balance)),
                  title: Text(nameOf(dep)),
                  subtitle: Text([
                    '${l.cloudDepositPrincipal}: ${dep['principal'] ?? 0}',
                    '${l.cloudDepositRate}: ${dep['annual_rate'] ?? 0}',
                    _statusText(dep['status'] as String?),
                    dateText(dep['maturity_at']),
                  ].join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      final id = idOf(dep);
                      if (action == 'withdraw' || action == 'renew') {
                        await act((s) => s.depositAction(id, action),
                            successMessage: l.cloudSaveSuccess);
                      } else if (action == 'delete') {
                        final ok = await confirmDelete(
                            l.commonDelete, l.cloudDeleteConfirmSimple);
                        if (ok) await act((s) => s.deleteDeposit(id));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'withdraw', child: Text(l.cloudDepositWithdraw)),
                      PopupMenuItem(value: 'renew', child: Text(l.cloudDepositRenew)),
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
