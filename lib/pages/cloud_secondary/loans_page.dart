/// 借款页(Cloud 0026-0033/0039 对接)。
/// 借入/借出列表 + 状态 + 还款 + 还款记录 + 虚拟账户汇总。
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

class LoansPage extends ConsumerStatefulWidget {
  const LoansPage({super.key});

  @override
  ConsumerState<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends CloudListState<LoansPage> {
  @override
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service) =>
      service.listLoans();

  String _statusText(String? s) {
    final l = AppLocalizations.of(context);
    switch (s) {
      case 'partial': return l.cloudLoanPartial;
      case 'overdue': return l.cloudLoanOverdue;
      case 'settled': return l.cloudLoanSettled;
      default: return l.cloudLoanUnpaid;
    }
  }

  Future<void> _showCreate({required String direction}) async {
    final l = AppLocalizations.of(context);
    final contacts = await _loadContacts();
    if (!mounted) return;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? contactId;
    DateTime due = DateTime.now().add(const Duration(days: 30));

    final ok = await showBeeDialog<bool>(
      context,
      title: direction == 'lend' ? l.cloudLoanLend : l.cloudLoanBorrow,
      child: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BeeField(
            label: l.cloudAmount,
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            BeeSelectField<String>(
              label: l.cloudLoanContact,
              items: [
                for (final c in contacts)
                  BeeSegment((c['id'] ?? c['sync_id']).toString(),
                      (c['name'] ?? '').toString()),
              ],
              value: contactId,
              onChanged: (v) => contactId = v,
            ),
          ],
          const SizedBox(height: 10),
          BeeMenuRow(
            title: l.cloudLoanDueDate,
            subtitle: dateText(due.toIso8601String()),
            leading: const BeeLineIcon('CalendarDays', size: 20),
            onTap: () async {
              final picked = await showWheelDatePicker(context, initial: due);
              if (picked != null) due = picked;
            },
          ),
          const SizedBox(height: 10),
          BeeField(label: l.cloudNote, controller: noteCtrl, maxLines: 2),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        BeeButton(
          label: l.commonSave,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true) return;
    final amount = double.tryParse(BeeDecimalInputFormatter.normalize(amountCtrl.text));
    if (amount == null || amount <= 0) {
      showBeeToast(context, l.cloudAmount, tone: BeeTone.error);
      return;
    }
    await act((s) => s.createLoan({
      'direction': direction,
      'amount': amount,
      'contact_id': contactId,
      'happened_at': DateTime.now().toUtc().toIso8601String(),
      'due_at': due.toUtc().toIso8601String(),
      'note': noteCtrl.text.trim(),
    }), successMessage: l.cloudSaveSuccess);
  }

  Future<List<Map<String, dynamic>>> _loadContacts() async {
    try {
      final service = await ref.read(cloudSecondaryServiceProvider.future);
      return service == null ? const [] : await service.listContacts();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _showRepayments(Map<String, dynamic> loan) async {
    final l = AppLocalizations.of(context);
    final id = idOf(loan);
    final service = await ref.read(cloudSecondaryServiceProvider.future);
    if (service == null || !mounted) return;
    final reps = await service.loanRepayments(id);
    if (!mounted) return;

    await showBeeSheet(
      context,
      title: l.cloudLoanRepayments,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (reps.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.cloudRepaymentEmpty),
          )
        else
          ...reps.map((r) => ListTile(
                title: Text('${l.cloudAmount}: ${r['amount'] ?? 0}'),
                subtitle: Text(dateText(r['repaid_at'])),
              )),
        const SizedBox(height: 12),
        BeeButton(
          label: l.cloudRepaymentNew,
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
    // 关闭后弹还款输入
    _showRepayInput(id);
  }

  Future<void> _showRepayInput(String loanId) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showBeeDialog<bool>(
      context,
      title: l.cloudRepaymentNew,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BeeField(label: l.cloudAmount, controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 10),
        BeeField(label: l.cloudNote, controller: noteCtrl, maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        BeeButton(label: l.commonSave, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true) return;
    final amount = double.tryParse(BeeDecimalInputFormatter.normalize(ctrl.text));
    if (amount == null || amount <= 0) return;
    await act((s) => s.addRepayment(loanId, {
      'amount': amount,
      'repaid_at': DateTime.now().toUtc().toIso8601String(),
      'note': noteCtrl.text.trim(),
    }), successMessage: l.cloudSaveSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeatureLoans,
          actions: [
            BeeIconButton(
              label: l.cloudLoanLend,
              icon: const BeeLineIcon('HandCoins'),
              onPressed: () => _showCreate(direction: 'lend'),
            ),
            BeeIconButton(
              label: l.cloudLoanBorrow,
              icon: const BeeLineIcon('ArrowDownToLine'),
              onPressed: () => _showCreate(direction: 'borrow'),
            ),
          ],
        ),
        Expanded(
          child: buildBody(
            emptyText: l.cloudLoanEmpty,
            itemBuilder: (context, i) {
              final loan = rows[i];
              final direction = loan['direction'] ?? 'lend';
              final amount = loan['amount'] ?? 0;
              final settled = loan['status'] == 'settled';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: direction == 'lend'
                        ? Colors.orange.shade100
                        : Colors.blue.shade100,
                    child: Icon(direction == 'lend' ? Icons.arrow_upward : Icons.arrow_downward),
                  ),
                  title: Text(
                    '${direction == 'lend' ? l.cloudLoanLend : l.cloudLoanBorrow} · $amount',
                    style: settled
                        ? const TextStyle(decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  subtitle: Text([
                    (loan['contact_name'] ?? loan['contactName'] ?? '').toString(),
                    _statusText(loan['status'] as String?),
                    if (loan['due_at'] != null) dateText(loan['due_at']),
                  ].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'repay') {
                        await _showRepayments(loan);
                      } else if (action == 'delete') {
                        final ok = await confirmDelete(l.commonDelete, l.cloudDeleteConfirmSimple);
                        if (ok) await act((s) => s.deleteLoan(idOf(loan)));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'repay', child: Text(l.cloudLoanRepay)),
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
