/// 储蓄罐页(Cloud 0034/0036 对接)。
/// 计划列表/新建 + 存入(双账户 transfer) + 存入记录修改/删除 + 进度详情。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/secondary/cloud_secondary_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cloud_secondary_providers.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'base_cloud_list.dart';

class SavingPlansPage extends ConsumerStatefulWidget {
  const SavingPlansPage({super.key});

  @override
  ConsumerState<SavingPlansPage> createState() => _SavingPlansPageState();
}

class _SavingPlansPageState extends CloudListState<SavingPlansPage> {
  @override
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service) =>
      service.listSavingPlans();

  Future<void> _showCreatePlan() async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final ok = await showBeeDialog<bool>(
      context,
      title: l.cloudPlanNew,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BeeField(label: l.cloudName, controller: nameCtrl),
        const SizedBox(height: 10),
        BeeField(label: l.cloudTarget, controller: targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        BeeButton(label: l.commonSave, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final target = double.tryParse(BeeDecimalInputFormatter.normalize(targetCtrl.text));
    await act((s) => s.createSavingPlan({
      'name': nameCtrl.text.trim(),
      'target_amount': target,
    }), successMessage: l.cloudSaveSuccess);
  }

  Future<void> _showDetail(Map<String, dynamic> plan) async {
    final l = AppLocalizations.of(context);
    final service = await ref.read(cloudSecondaryServiceProvider.future);
    if (service == null || !mounted) return;
    final id = idOf(plan);
    final contributions = await service.contributions(id);
    if (!mounted) return;

    final target = (plan['target_amount'] as num?)?.toDouble() ?? 0;
    final saved = contributions.fold<double>(
        0, (sum, c) => sum + ((c['amount'] as num?)?.toDouble() ?? 0));
    final remaining = target - saved;
    final progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;

    await showBeeSheet(
      context,
      title: nameOf(plan),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Text('${l.cloudTarget}: ${target.toStringAsFixed(2)}'),
          Text('${l.cloudSaved}: ${saved.toStringAsFixed(2)}'),
          Text('${l.cloudRemaining}: ${remaining.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 12),
        BeeButton(
          label: l.cloudDepositTo,
          onPressed: () {
            Navigator.pop(context);
            _showContribute(id);
          },
        ),
        const SizedBox(height: 12),
        if (contributions.isEmpty)
          Text(l.cloudContributionEmpty)
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              itemCount: contributions.length,
              itemBuilder: (context, i) {
                final c = contributions[i];
                return ListTile(
                  title: Text('${l.cloudAmount}: ${c['amount'] ?? 0}'),
                  subtitle: Text(dateText(c['happened_at'])),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _showContribute(id, contribution: c);
                      } else if (action == 'delete') {
                        final ok = await confirmDelete(
                            l.commonDelete, l.cloudDeleteConfirmSimple);
                        if (ok) {
                          await act((s) => s.deleteContribution(idOf(c)));
                          if (context.mounted) Navigator.pop(context);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(l.cloudEdit)),
                      PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
                    ],
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  Future<void> _showContribute(String planId,
      {Map<String, dynamic>? contribution}) async {
    final l = AppLocalizations.of(context);
    final isEdit = contribution != null;
    final amountCtrl = TextEditingController(
        text: isEdit ? (contribution['amount'] ?? '').toString() : '');
    final accountCtrl = TextEditingController(
        text: isEdit ? (contribution['account_id'] ?? '').toString() : '');
    final receiveCtrl = TextEditingController(
        text: isEdit ? (contribution['receive_account_id'] ?? '').toString() : '');
    final noteCtrl = TextEditingController(
        text: isEdit ? (contribution['note'] ?? '').toString() : '');

    final ok = await showBeeDialog<bool>(
      context,
      title: isEdit ? l.cloudContributionEdit : l.cloudContributionNew,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BeeField(label: l.cloudAmount, controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          BeeField(label: l.cloudAccount, controller: accountCtrl,
              helper: 'syncId'),
          const SizedBox(height: 10),
          BeeField(label: l.cloudReceiveAccount, controller: receiveCtrl,
              helper: l.cloudReceiveAccountHint),
          const SizedBox(height: 6),
          Text(l.cloudTransferHint,
              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          const SizedBox(height: 10),
          BeeField(label: l.cloudNote, controller: noteCtrl, maxLines: 2),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        BeeButton(label: l.commonSave, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true) return;
    final amount = double.tryParse(BeeDecimalInputFormatter.normalize(amountCtrl.text));
    if (amount == null || amount <= 0) return;
    final body = <String, dynamic>{
      'amount': amount,
      'account_id': accountCtrl.text.trim().isEmpty ? null : accountCtrl.text.trim(),
      'receive_account_id': receiveCtrl.text.trim().isEmpty ? null : receiveCtrl.text.trim(),
      'note': noteCtrl.text.trim(),
      'happened_at': DateTime.now().toUtc().toIso8601String(),
    };
    final success = isEdit
        ? await act((s) => s.updateContribution(idOf(contribution!), body),
            successMessage: l.cloudSaveSuccess)
        : await act((s) => s.contribute(planId, body),
            successMessage: l.cloudSaveSuccess);
    if (success) await load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeatureSaving,
          actions: [
            BeeIconButton(
              label: l.cloudPlanNew,
              icon: const BeeLineIcon('Plus'),
              onPressed: _showCreatePlan,
            ),
          ],
        ),
        Expanded(
          child: buildBody(
            emptyText: l.cloudPlanEmpty,
            itemBuilder: (context, i) {
              final plan = rows[i];
              final status = plan['status'] ?? 'active';
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.savings)),
                  title: Text(nameOf(plan)),
                  subtitle: Text([
                    '${l.cloudTarget}: ${plan['target_amount'] ?? 0}',
                    status == 'active'
                        ? l.cloudPlanActive
                        : status == 'completed'
                            ? l.cloudPlanCompleted
                            : l.cloudPlanAbandoned,
                  ].join(' · ')),
                  onTap: () => _showDetail(plan),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      final id = idOf(plan);
                      if (action == 'deposit') {
                        await _showContribute(id);
                      } else if (action == 'complete' || action == 'abandon') {
                        await act((s) => s.savingPlanAction(id, action),
                            successMessage: l.cloudSaveSuccess);
                      } else if (action == 'delete') {
                        final ok = await confirmDelete(
                            l.commonDelete, l.cloudDeleteConfirmSimple);
                        if (ok) await act((s) => s.deleteSavingPlan(id));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'deposit', child: Text(l.cloudDepositTo)),
                      PopupMenuItem(value: 'complete', child: Text(l.cloudPlanComplete)),
                      PopupMenuItem(value: 'abandon', child: Text(l.cloudPlanAbandon)),
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
