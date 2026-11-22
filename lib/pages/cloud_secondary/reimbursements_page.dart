/// 报销页(Cloud 0035/0037 对接)。
/// 待报销项列表 + 合并生成报销单 + 公司管理。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/secondary/cloud_secondary_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cloud_secondary_providers.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'base_cloud_list.dart';

class ReimbursementsPage extends ConsumerStatefulWidget {
  const ReimbursementsPage({super.key});

  @override
  ConsumerState<ReimbursementsPage> createState() => _ReimbursementsPageState();
}

class _ReimbursementsPageState extends CloudListState<ReimbursementsPage> {
  int _tab = 0; // 0=待报销项 1=报销单

  @override
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service) =>
      _tab == 0 ? service.reimbursementItems() : service.reimbursements();

  void switchTab(int tab) {
    setState(() => _tab = tab);
    load();
  }

  Future<void> _showCompanies() async {
    final l = AppLocalizations.of(context);
    final service = await ref.read(cloudSecondaryServiceProvider.future);
    if (service == null || !mounted) return;
    final companies = await service.listCompanies();
    if (!mounted) return;
    await showBeeSheet(
      context,
      title: l.cloudCompanyManage,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (companies.isEmpty) Text(l.cloudCompanyEmpty),
        ...companies.map((c) => ListTile(title: Text(nameOf(c)))),
        const SizedBox(height: 12),
        BeeButton(
          label: l.cloudCompanyNew,
          onPressed: () {
            Navigator.pop(context);
            _newCompany();
          },
        ),
      ]),
    );
  }

  Future<void> _newCompany() async {
    final l = AppLocalizations.of(context);
    final name = await askName(l.cloudCompanyNew, l.cloudName);
    if (name == null) return;
    await act((s) => s.createCompany({'name': name}),
        successMessage: l.cloudSaveSuccess);
  }

  Future<void> _createReimbursement() async {
    final l = AppLocalizations.of(context);
    final service = await ref.read(cloudSecondaryServiceProvider.future);
    if (service == null) return;
    final companies = await service.listCompanies();
    if (!mounted) return;
    if (companies.isEmpty) {
      showBeeToast(context, l.cloudCompanyEmpty, tone: BeeTone.warning);
      return;
    }
    final pending = rows.where((r) => r['status'] == 'pending').toList();
    if (pending.isEmpty) {
      showBeeToast(context, l.cloudReimburseEmpty, tone: BeeTone.warning);
      return;
    }
    final companyId = await showBeeDialog<String?>(
      context,
      title: l.cloudReimburseNew,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${l.cloudReimburseItemsCount}: ${pending.length}'),
        const SizedBox(height: 10),
        BeeSelectField<String>(
          label: l.cloudReimburseCompany,
          items: [
            for (final c in companies)
              BeeSegment((c['id'] ?? c['sync_id']).toString(), nameOf(c)),
          ],
          value: null,
          onChanged: (v) => Navigator.pop(context, v),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
      ],
    );
    if (companyId == null) return;
    final total = pending.fold<double>(
        0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
    await act((s) => s.createReimbursement({
      'amount': total,
      'company_id': companyId,
      'happened_at': DateTime.now().toUtc().toIso8601String(),
      'item_ids': pending.map((r) => idOf(r)).toList(),
    }), successMessage: l.cloudSaveSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeatureReimburse,
          actions: [
            BeeIconButton(
              label: l.cloudCompanyManage,
              icon: const BeeLineIcon('Building2'),
              onPressed: _showCompanies,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
          child: BeeSegmented<int>(
            items: [
              BeeSegment(0, l.cloudReimburseItems),
              BeeSegment(1, l.cloudReimburseByCompany),
            ],
            value: _tab,
            onChanged: switchTab,
          ),
        ),
        Expanded(
          child: buildBody(
            emptyText: l.cloudReimburseEmpty,
            itemBuilder: (context, i) {
              final row = rows[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_tab == 0 ? Icons.receipt : Icons.account_balance_wallet),
                  ),
                  title: Text(
                      '${l.cloudAmount}: ${row['amount'] ?? 0}'),
                  subtitle: Text([
                    (row['company_name'] ?? '').toString(),
                    dateText(row['happened_at']),
                    if (_tab == 0) (row['status'] ?? '').toString(),
                  ].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: _tab == 0
                      ? PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'delete') {
                              final ok = await confirmDelete(
                                  l.commonDelete, l.cloudDeleteConfirmSimple);
                              if (ok) await act((s) => s.deleteReimbursementItem(idOf(row)));
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
                          ],
                        )
                      : PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'delete') {
                              final ok = await confirmDelete(
                                  l.commonDelete, l.cloudDeleteConfirmSimple);
                              if (ok) await act((s) => s.deleteReimbursement(idOf(row)));
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
        if (_tab == 0)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 4, 17, 12),
              child: SizedBox(
                width: double.infinity,
                child: BeeButton(
                  label: l.cloudReimburseNew,
                  onPressed: _createReimbursement,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
