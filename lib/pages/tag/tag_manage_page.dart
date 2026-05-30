import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/tag_seed_service.dart';
import '../../services/export/config_export_service.dart';
import '../../services/system/logger_service.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import 'tag_detail_page.dart';
import 'tag_edit_page.dart';

/// 标签管理页面
class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tagsAsync = ref.watch(tagsWithStatsProvider);
    final primaryColor = ref.watch(primaryColorProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.tagManageTitle,
            subtitle: l10n.tagManageSubtitle,
            showBack: true,
            actions: [
              IconButton(
                onPressed: _shareTags,
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.tagShare,
              ),
              _buildMoreMenu(context, l10n, primaryColor),
            ],
          ),
          Expanded(
            child: tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('${l10n.commonError}: $error'),
              ),
              data: (tags) {
                if (tags.isEmpty) {
                  return _buildEmptyState(l10n);
                }
                return _buildTagGrid(tags, l10n);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label_outline,
            size: 64,
            color: BeeTokens.textTertiary(context),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.tagManageEmpty,
            style: TextStyle(
              fontSize: 16,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tagManageEmptyHint,
            style: TextStyle(
              fontSize: 14,
              color: BeeTokens.textTertiary(context),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _generateDefaultTags,
            icon: const Icon(Icons.auto_fix_high),
            label: Text(l10n.tagManageGenerateDefault),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGrid(
    List<({Tag tag, int transactionCount})> tags,
    AppLocalizations l10n,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final item = tags[index];
        return _TagCard(
          tag: item.tag,
          transactionCount: item.transactionCount,
          onTap: () => _viewTagDetail(item.tag),
          onDelete: () => _deleteTag(item.tag, l10n),
        );
      },
    );
  }

  void _addTag() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TagEditPage(),
      ),
    );
  }

  void _viewTagDetail(Tag tag) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TagDetailPage(
          tagId: tag.id,
          tagName: tag.name,
          allLedgers: true,
        ),
      ),
    );
  }

  void _deleteTag(Tag tag, AppLocalizations l10n) async {
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.tagDeleteConfirmTitle,
      message: l10n.tagDeleteConfirmMessage(tag.name),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(repositoryProvider);
      await repo.deleteTag(tag.id);
      ref.read(tagListRefreshProvider.notifier).state++;

      if (mounted) {
        showToast(context, l10n.tagDeleteSuccess);
      }
    }
  }

  void _generateDefaultTags() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.tagManageGenerateDefault,
      message: l10n.tagManageGenerateDefaultConfirm,
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(repositoryProvider);
      await TagSeedService.seedDefaultTags(repo, l10n);
      // 跟普通手工新建的 tag 一样走 sync_changes 路径,这里再顺手 push 一下,
      // 保证云同步页还没被下拉刷新时就已经开始把种子标签推到云端。
      // 标签是用户级、不挂账本,但 PostProcessor.sync 需要 ledgerId —— 用
      // 当前账本即可,sync engine 会把所有 unpushed changes(包括 ledger=0 的)
      // 一起带上。
      final currentLedgerId = ref.read(currentLedgerIdProvider);
      await PostProcessor.sync(ref, ledgerId: currentLedgerId);
      ref.read(tagListRefreshProvider.notifier).state++;

      if (mounted) {
        showToast(context, l10n.tagManageGenerateDefaultSuccess);
      }
    }
  }

  /// 构建更多菜单
  Widget _buildMoreMenu(BuildContext context, AppLocalizations l10n, Color primaryColor) {
    return BeePopupMenu(
      tooltip: l10n.commonMore,
      primaryColor: primaryColor,
      items: [
        BeeMenuItem.action(
          value: 'add',
          icon: Icons.add_circle_outline,
          label: l10n.tagAddTitle,
        ),
        BeeMenuItem.action(
          value: 'generate_default',
          icon: Icons.auto_fix_high,
          label: l10n.tagManageGenerateDefault,
        ),
        BeeMenuItem.action(
          value: 'import',
          icon: Icons.download_outlined,
          label: l10n.tagImport,
        ),
        const BeeMenuItem.divider(),
        BeeMenuItem.action(
          value: 'clear_unused',
          icon: Icons.delete_sweep_outlined,
          label: l10n.tagClearUnused,
          isDanger: true,
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'add':
            _addTag();
            break;
          case 'generate_default':
            _generateDefaultTags();
            break;
          case 'import':
            _importTags();
            break;
          case 'clear_unused':
            _clearUnusedTags();
            break;
        }
      },
    );
  }

  /// 分享标签
  Future<void> _shareTags() async {
    final l10n = AppLocalizations.of(context);

    try {
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      // 生成只包含标签的配置
      final options = ExportOptions(
        categories: false,
        accounts: false,
        tags: true,
        budgets: false,
        recurringTransactions: false,
        appSettings: false,
      );

      final yamlContent = await ConfigExportService.exportToYaml(
        repository: repo,
        ledgerId: ledgerId,
        options: options,
      );

      if (!mounted) return;

      // 生成文件并分享
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'beecount_tags_$timestamp.yml';

      if (Platform.isAndroid) {
        final downloadPath = '/storage/emulated/0/Download/BeeCount';
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final filePath = '$downloadPath/$fileName';
        final file = File(filePath);
        await file.writeAsString(yamlContent);

        if (!mounted) return;
        showToast(context, l10n.tagShareSuccess(filePath.replaceAll('/storage/emulated/0/', '')));
      } else {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(yamlContent);

        if (!mounted) return;
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: l10n.tagShareSubject,
        );
      }
    } catch (e) {
      logger.error('TagManage', '分享标签失败: $e');
      if (!mounted) return;
      showToast(context, l10n.tagShareFailed);
    }
  }

  /// 导入标签
  Future<void> _importTags() async {
    final l10n = AppLocalizations.of(context);

    try {
      // 选择文件
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['yml', 'yaml'],
        );
      } catch (e) {
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      }

      if (result == null || result.files.isEmpty || !mounted) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        showToast(context, l10n.configImportNoFilePath);
        return;
      }

      // 验证文件扩展名
      final fileName = filePath.toLowerCase();
      if (!fileName.endsWith('.yml') && !fileName.endsWith('.yaml')) {
        showToast(context, l10n.tagImportInvalidFile);
        return;
      }

      // 读取文件
      final file = File(filePath);
      final yamlContent = await file.readAsString();

      // 检测内容
      final contentInfo = ConfigExportService.detectContent(yamlContent);
      if (!contentInfo.hasTags) {
        if (!mounted) return;
        showToast(context, l10n.tagImportNoTags);
        return;
      }

      if (!mounted) return;

      // 选择导入模式
      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.tagImportModeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.merge_type),
                title: Text(l10n.tagImportModeMerge),
                subtitle: Text(l10n.tagImportModeMergeDesc),
                onTap: () => Navigator.pop(context, 'merge'),
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(l10n.tagImportModeOverwrite),
                subtitle: Text(l10n.tagImportModeOverwriteDesc),
                onTap: () => Navigator.pop(context, 'overwrite'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      );

      if (mode == null || !mounted) return;

      // 执行导入
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      final options = ExportOptions(
        categories: false,
        accounts: false,
        tags: true,
        budgets: false,
        recurringTransactions: false,
        appSettings: false,
      );

      if (mode == 'overwrite') {
        // 覆盖模式：先清空未使用的标签
        await _clearUnusedTagsSilent();
      }

      await ConfigExportService.importFromFile(
        filePath,
        repository: repo,
        ledgerId: ledgerId,
        options: options,
      );

      if (!mounted) return;
      showToast(context, l10n.tagImportSuccess);
      ref.read(tagListRefreshProvider.notifier).state++;
    } catch (e) {
      logger.error('TagManage', '导入标签失败: $e');
      if (!mounted) return;
      showToast(context, l10n.tagImportFailed);
    }
  }

  /// 清空未使用的标签
  Future<void> _clearUnusedTags() async {
    final l10n = AppLocalizations.of(context);
    final tagsWithStats = ref.read(tagsWithStatsProvider).valueOrNull ?? [];

    // 找出交易数为0的标签
    final unusedTags = tagsWithStats
        .where((item) => item.transactionCount == 0)
        .toList();

    if (unusedTags.isEmpty) {
      showToast(context, l10n.tagClearUnusedEmpty);
      return;
    }

    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tagClearUnusedTitle),
        content: Text(l10n.tagClearUnusedMessage(unusedTags.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      for (final item in unusedTags) {
        await repo.deleteTag(item.tag.id);
      }

      // 显式触发 active ledger 的 sync,把刚才登记的 N 条 user-global
      // tag:delete change(在 ledgerId=0)推到 server。SyncCoordinator 的反应
      // 式触发理论上也能 cover,但显式 trigger 更稳——不依赖 coordinator 是否
      // 启动 / debounce 时序。跟 _clearUnusedCategories 对齐。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      if (!mounted) return;
      showToast(context, l10n.tagClearUnusedSuccess(unusedTags.length));
      ref.read(tagListRefreshProvider.notifier).state++;
    } catch (e) {
      logger.error('TagManage', '清空未使用标签失败: $e');
      if (!mounted) return;
      showToast(context, l10n.tagClearUnusedFailed);
    }
  }

  /// 静默清空未使用的标签（用于覆盖导入）
  Future<void> _clearUnusedTagsSilent() async {
    final tagsWithStats = ref.read(tagsWithStatsProvider).valueOrNull ?? [];
    final unusedTags = tagsWithStats
        .where((item) => item.transactionCount == 0)
        .toList();

    if (unusedTags.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    for (final item in unusedTags) {
      await repo.deleteTag(item.tag.id);
    }
  }
}

/// 标签卡片
class _TagCard extends StatelessWidget {
  final Tag tag;
  final int transactionCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TagCard({
    required this.tag,
    required this.transactionCount,
    required this.onTap,
    required this.onDelete,
  });

  Color _parseColor(BuildContext context) {
    if (tag.color == null || tag.color!.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    try {
      String hex = tag.color!;
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tagColor = _parseColor(context);
    final isDark = BeeTokens.isDark(context);

    return Material(
      color: BeeTokens.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tagColor.withValues(alpha: isDark ? 0.4 : 0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // 背景渐变色块
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tagColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  ),
                ),
              ),
              // 内容
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标签名称
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 颜色指示圆点
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: tagColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tag.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: BeeTokens.textPrimary(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 交易数量
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tagTransactionCount(transactionCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textTertiary(context),
                          ),
                        ),
                        // 删除按钮
                        GestureDetector(
                          onTap: onDelete,
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: BeeTokens.iconTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
