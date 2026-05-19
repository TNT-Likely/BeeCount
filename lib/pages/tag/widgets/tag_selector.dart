import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/tag_providers.dart';
import '../../../styles/tokens.dart';
import '../../../widgets/biz/tag_chip.dart';
import '../tag_edit_page.dart';

/// 标签选择器
/// 底部弹窗形式，支持多选
/// 使用 LRU（最近最少使用）算法排序：最近使用的标签排在前面
class TagSelector extends ConsumerStatefulWidget {
  /// 当前已选中的标签ID列表
  final List<int> selectedTagIds;

  /// 选择完成回调
  final void Function(List<int> selectedIds)? onConfirm;

  const TagSelector({
    super.key,
    this.selectedTagIds = const [],
    this.onConfirm,
  });

  /// 显示标签选择器
  static Future<List<int>?> show(
    BuildContext context, {
    List<int> selectedTagIds = const [],
  }) async {
    return await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagSelector(
        selectedTagIds: selectedTagIds,
      ),
    );
  }

  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  late Set<int> _selectedIds;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedTagIds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // §7 共享账本:Editor + 共享账本 picker 只显示 Owner mirror tags
    final allTagsAsync = ref.watch(tagsForCurrentLedgerProvider);
    final recentTagsAsync = ref.watch(recentTagsForCurrentLedgerProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: BeeTokens.surfaceElevated(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: BeeTokens.divider(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                Column(
                  children: [
                    Text(
                      l10n.tagSelectTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                    Text(
                      l10n.tagSelectHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selectedIds.toList()),
                  child: Text(l10n.commonConfirm),
                ),
              ],
            ),
          ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.commonSearch,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: BeeTokens.surfaceSecondary(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) => setState(() => _searchText = value),
            ),
          ),
          const SizedBox(height: 12),

          // 内容区
          Expanded(
            child: allTagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('$error')),
              data: (allTags) {
                // 过滤搜索结果
                final filteredTags = _searchText.isEmpty
                    ? allTags
                    : allTags
                        .where((t) => t.name.toLowerCase().contains(_searchText.toLowerCase()))
                        .toList();

                if (filteredTags.isEmpty && allTags.isEmpty) {
                  return _buildEmptyState(l10n);
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // 最近使用
                    if (_searchText.isEmpty)
                      recentTagsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (recentTags) {
                          if (recentTags.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return _buildSection(
                            l10n.tagSelectRecentlyUsed,
                            recentTags,
                          );
                        },
                      ),

                    // 全部标签
                    if (filteredTags.isNotEmpty)
                      _buildSection(
                        _searchText.isEmpty ? l10n.tagSelectAllTags : '${l10n.commonSearch}结果',
                        filteredTags,
                      ),

                    // 新建标签入口
                    const SizedBox(height: 8),
                    _buildCreateNew(l10n),
                    const SizedBox(height: 16),
                  ],
                );
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
            size: 48,
            color: BeeTokens.textTertiary(context),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无标签',
            style: TextStyle(
              color: BeeTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _createNewTag,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.tagSelectCreateNew),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Tag> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = _selectedIds.contains(tag.id);
            return TagChip(
              name: tag.name,
              color: tag.color,
              size: TagChipSize.medium,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedIds.remove(tag.id);
                  } else {
                    _selectedIds.add(tag.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCreateNew(AppLocalizations l10n) {
    return InkWell(
      onTap: _createNewTag,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: BeeTokens.border(context),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.tagSelectCreateNew,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewTag() async {
    final result = await Navigator.of(context).push<Tag?>(
      MaterialPageRoute(
        builder: (_) => const TagEditPage(),
      ),
    );

    // 如果创建了新标签，自动选中
    if (result != null) {
      setState(() {
        _selectedIds.add(result.id);
      });
    }
    // 刷新标签列表
    ref.read(tagListRefreshProvider.notifier).state++;
  }
}
