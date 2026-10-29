import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../shared/resources/bindings/recording_category_icon.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers.dart';
import '../../data/db.dart' as db;
import '../../services/billing/post_processor.dart';
import '../../services/category_package_service.dart';
import '../../services/data/seed_service.dart';
import '../../services/system/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';
import 'category_edit_page.dart';

part 'manage/bindings/category_management_actions.dart';
part 'manage/bindings/category_management_bindings.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0: 支出, 1: 收入

  const CategoryManagePage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage>
    with TickerProviderStateMixin, _CategoryManagementActions {
  @override
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      setState(() {}); // 重新构建以更新按钮状态
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesWithCountAsync = ref.watch(categoriesWithCountProvider);
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    return V4PageScaffold(
      body: Column(
        children: [
          BeePageHeader(
            title: l10n.categoryTitle,
            leading: const BackButton(),
            actions: [
              BeeIconButton(
                  label: l10n.categoryNew,
                  icon: const BeeLineIcon('Plus'),
                  onPressed: _addCategory),
              _buildMoreMenu(context, l10n, primaryColor),
            ],
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 6),
              child: BeeSegmented<int>(
                  items: [
                    BeeSegment(0, l10n.categoryExpense),
                    BeeSegment(1, l10n.categoryIncome)
                  ],
                  value: _tabController.index,
                  onChanged: (v) => _tabController.animateTo(v))),
          Expanded(
            child: categoriesWithCountAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                  child: Text(l10n.categoryLoadFailed(error.toString()))),
              data: (categoriesWithCount) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _CategoryGridView(
                      categoriesWithCount: categoriesWithCount,
                      kind: 'expense',
                      tools: _buildMoreMenu(context, l10n, primaryColor,
                          guide: true),
                      transferSetting: _buildTransferIconSetting(
                          context, l10n, primaryColor),
                      onAddCategory: () => _addCategory(kind: 'expense'),
                    ),
                    _CategoryGridView(
                      categoriesWithCount: categoriesWithCount,
                      kind: 'income',
                      tools: _buildMoreMenu(context, l10n, primaryColor,
                          guide: true),
                      transferSetting: _buildTransferIconSetting(
                          context, l10n, primaryColor),
                      onAddCategory: () => _addCategory(kind: 'income'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
