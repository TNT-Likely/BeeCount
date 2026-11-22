/// BeeCount-Cloud 二次开发功能入口页。
///
/// 列出所有从 Cloud 对接过来的业务实体(联系人/借款/储蓄罐/报销/物品/定期/
/// 消费成员)。这些页面依赖 Cloud REST(非 sync),仅 BeeCount Cloud 模式可见。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/cloud_secondary_providers.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'contacts_page.dart';
import 'loans_page.dart';
import 'saving_plans_page.dart';
import 'reimbursements_page.dart';
import 'items_page.dart';
import 'deposits_page.dart';
import 'members_page.dart';
import 'lock_settings_page.dart';

/// 功能项定义：icon 用 BeeLineIcon(Lucide 名称)。
class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });
  final String icon;
  final String title;
  final String subtitle;
  final WidgetBuilder page;
}

class CloudFeaturesPage extends ConsumerWidget {
  const CloudFeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final serviceAsync = ref.watch(cloudSecondaryServiceProvider);

    final features = <_Feature>[
      _Feature(
        icon: 'Users',
        title: l.cloudFeatureContacts,
        subtitle: l.cloudFeatureContactsSub,
        page: (_) => const ContactsPage(),
      ),
      _Feature(
        icon: 'HandCoins',
        title: l.cloudFeatureLoans,
        subtitle: l.cloudFeatureLoansSub,
        page: (_) => const LoansPage(),
      ),
      _Feature(
        icon: 'PiggyBank',
        title: l.cloudFeatureSaving,
        subtitle: l.cloudFeatureSavingSub,
        page: (_) => const SavingPlansPage(),
      ),
      _Feature(
        icon: 'ReceiptText',
        title: l.cloudFeatureReimburse,
        subtitle: l.cloudFeatureReimburseSub,
        page: (_) => const ReimbursementsPage(),
      ),
      _Feature(
        icon: 'Package',
        title: l.cloudFeatureItems,
        subtitle: l.cloudFeatureItemsSub,
        page: (_) => const ItemsPage(),
      ),
      _Feature(
        icon: 'Landmark',
        title: l.cloudFeatureDeposits,
        subtitle: l.cloudFeatureDepositsSub,
        page: (_) => const DepositsPage(),
      ),
      _Feature(
        icon: 'Users',
        title: l.cloudMemberTitle,
        subtitle: l.cloudFeatureContactsSub,
        page: (_) => const MembersPage(),
      ),
    ];

    return V4PageScaffold(
      backgroundColor: BeeCardTheme.of(context).canvas,
      body: Column(children: [
        BeePageHeader(
          title: l.cloudFeaturesTitle,
          actions: [
            BeeIconButton(
              label: l.cloudLockTitle,
              icon: const BeeLineIcon('Lock'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LockSettingsPage()),
              ),
            ),
            BeeIconButton(
              label: l.cloudFeaturesRefresh,
              icon: const BeeLineIcon('RefreshCw'),
              onPressed: () =>
                  ref.invalidate(cloudSecondaryServiceProvider),
            ),
          ],
        ),
        Expanded(
          child: serviceAsync.when(
            data: (service) {
              if (service == null) {
                return Center(child: Text(l.cloudFeatureNeedCloud));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
                itemCount: features.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final f = features[i];
                  return BeeMenuRow(
                    title: f.title,
                    subtitle: f.subtitle,
                    leading: BeeLineIcon(f.icon, size: 20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: f.page),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ]),
    );
  }
}
