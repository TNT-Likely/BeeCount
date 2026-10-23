import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../../providers.dart';
import '../../../data/db.dart' as db;
import '../../../pages/account/accounts_page.dart';
import '../../../pages/account/account_edit_page.dart';
import '../../../pages/attachment/attachment_preview_page.dart';
import '../../../pages/auth/app_lock_screen.dart';
import '../../../pages/auth/pin_setup_page.dart';
import '../../../pages/auth/splash_page.dart';
import '../../../pages/auth/welcome_page.dart';
import '../../../pages/category/category_edit_page.dart';
import '../../../pages/category/category_manage_page.dart';
import '../../../pages/main/home_page.dart';
import '../../../pages/main/ledgers_page_new.dart';
import '../../../pages/main/mine_page.dart';
import '../../../pages/settings/config_import_export_page.dart';
import '../../../pages/transaction/category_detail_page.dart';
import '../../../pages/transaction/search_page.dart';
import '../../../pages/transaction/transaction_editor_page.dart';

/// Debug navigation uses the production routes, providers and persistent data.
/// It does not seed, reset, submit forms, or replace any provider.
class PageMigrationGallery extends ConsumerStatefulWidget {
  const PageMigrationGallery({super.key});
  @override
  ConsumerState<PageMigrationGallery> createState() =>
      _PageMigrationGalleryState();
}

class _PageMigrationGalleryState extends ConsumerState<PageMigrationGallery> {
  String query = '';
  late final _resources = _load();
  Future<({List<db.Category> categories, List<db.Transaction> transactions})>
      _load() async {
    final repo = ref.read(repositoryProvider);
    return (
      categories: await repo.getAllCategories(),
      transactions:
          await repo.getTransactionsByLedger(ref.read(currentLedgerIdProvider))
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final ledgerId = ref.watch(currentLedgerIdProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('页面迁移验收')),
        body: FutureBuilder(
            future: _resources,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return BeeStatus(
                    label: '${snapshot.error}', tone: BeeTone.error);
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.requireData;
              final category =
                  data.categories.isEmpty ? null : data.categories.first;
              final tx =
                  data.transactions.isEmpty ? null : data.transactions.first;
              final routes =
                  <({String id, String title, Widget Function() open})>[
                (id: 'home', title: '明细首页', open: () => const HomePage()),
                (
                  id: 'recording',
                  title: '记账与编辑',
                  open: () => const TransactionEditorPage(
                      initialKind: 'expense', quickAdd: true)
                ),
                (
                  id: 'transfer',
                  title: '转账',
                  open: () => const TransactionEditorPage(
                      initialKind: 'transfer', quickAdd: true)
                ),
                (
                  id: 'search',
                  title: '账单搜索与批量',
                  open: () => const SearchPage()
                ),
                (
                  id: 'category-manage',
                  title: '分类管理',
                  open: () => const CategoryManagePage()
                ),
                (
                  id: 'category-edit',
                  title: '分类编辑',
                  open: () =>
                      CategoryEditPage(kind: 'expense', category: category)
                ),
                if (category != null)
                  (
                    id: 'category-detail',
                    title: '分类详情',
                    open: () => CategoryDetailPage(
                        categoryId: category.id, categoryName: category.name)
                  ),
                (
                  id: 'accounts',
                  title: '资产与账户',
                  open: () => const AccountsPage()
                ),
                (
                  id: 'account-edit',
                  title: '新建账户',
                  open: () => AccountEditPage(ledgerId: ledgerId)
                ),
                (
                  id: 'ledgers',
                  title: '账本管理',
                  open: () => const LedgersPageNew()
                ),
                (id: 'mine', title: '我的', open: () => const MinePage()),
                (
                  id: 'config',
                  title: '配置导入导出',
                  open: () => const ConfigImportExportPage()
                ),
                if (tx != null)
                  (
                    id: 'attachment',
                    title: '附件预览',
                    open: () => AttachmentPreviewPage.fromTransaction(
                        transactionId: tx.id)
                  ),
                (
                  id: 'welcome',
                  title: '初始化五步',
                  open: () => const WelcomePage()
                ),
                (id: 'splash', title: '启动状态', open: () => const SplashPage()),
                (id: 'pin', title: '设置 PIN', open: () => const PinSetupPage()),
                (id: 'lock', title: '应用锁', open: () => const AppLockScreen()),
              ].where((r) => '${r.id} ${r.title}'.contains(query)).toList();
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.all(17),
                    child: BeeSearchField(
                        hint: '搜索验收页面',
                        onChanged: (v) => setState(() => query = v))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 17),
                    child: Text('实际生产页面与当前账本数据；操作会正常保存。打开页面不代表验收通过。',
                        style: TextStyle(fontSize: 12))),
                Expanded(
                    child: BeePageBody(
                        children: routes
                            .map((r) => BeeSurface(
                                padding: EdgeInsets.zero,
                                child: BeeMenuRow(
                                    title: r.title,
                                    subtitle: 'P0 · ${r.id}',
                                    onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => r.open())))))
                            .toList())),
              ]);
            }));
  }
}
