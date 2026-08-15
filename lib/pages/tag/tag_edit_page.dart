import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/tag_providers.dart';
import '../../providers/database_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/tag_seed_service.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/biz/tag_chip.dart';

/// 标签编辑页面
/// 用于新增或编辑标签
class TagEditPage extends ConsumerStatefulWidget {
  /// 要编辑的标签，为空表示新增
  final Tag? tag;

  const TagEditPage({super.key, this.tag});

  @override
  ConsumerState<TagEditPage> createState() => _TagEditPageState();
}

class _TagEditPageState extends ConsumerState<TagEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedColor;
  bool _isSubmitting = false;

  bool get _isEditing => widget.tag != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _selectedColor = widget.tag?.color ?? TagSeedService.getRandomColor();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: _isEditing ? l10n.tagEditTitle : l10n.tagAddTitle,
            showBack: true,
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(
                  l10n.commonSave,
                  style: TextStyle(
                    color: _isSubmitting
                        ? BeeTokens.textTertiary(context)
                        : BeeTokens.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 预览
                  _buildPreview(),
                  const SizedBox(height: 24),

                  // 标签名称
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            l10n.tagNameLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: BeeTokens.textSecondary(context),
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: l10n.tagNameHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          maxLength: 20,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.tagNameRequired;
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 颜色选择
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            l10n.tagColorLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: BeeTokens.textSecondary(context),
                            ),
                          ),
                        ),
                        _buildColorPicker(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Center(
      child: TagChip(
        name: _nameController.text.isEmpty ? '标签预览' : _nameController.text,
        color: _selectedColor,
        size: TagChipSize.large,
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = TagSeedService.getColorPalette();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((colorHex) {
        final isSelected = _selectedColor == colorHex;
        final color = _parseColor(colorHex);

        return GestureDetector(
          onTap: () => setState(() => _selectedColor = colorHex),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: BeeTokens.isDark(context)
                          ? Colors.white
                          : Colors.black,
                      width: 3,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: _isLightColor(color) ? Colors.black : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Color _parseColor(String hex) {
    try {
      String h = hex;
      if (h.startsWith('#')) {
        h = h.substring(1);
      }
      if (h.length == 6) {
        h = 'FF$h';
      }
      return Color(int.parse(h, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  bool _isLightColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(repositoryProvider);

    // 检查名称是否重复
    final isDuplicate = await repo.isTagNameDuplicate(
      name: name,
      excludeId: widget.tag?.id,
    );

    if (isDuplicate) {
      if (mounted) {
        showToast(context, l10n.tagNameDuplicate);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isEditing) {
        // 更新标签
        await repo.updateTag(
          widget.tag!.id,
          name: name,
          color: _selectedColor,
        );
        if (mounted) {
          showToast(context, l10n.tagUpdateSuccess);
        }
      } else {
        // 创建标签
        await repo.createTag(
          name: name,
          color: _selectedColor,
        );
        if (mounted) {
          showToast(context, l10n.tagCreateSuccess);
        }
      }

      ref.read(tagListRefreshProvider.notifier).state++;

      // 标签是 user-scoped，但 ChangeTracker 记在 ledgerId=0；_push(ledger) 会
      // 顺便把 ledgerId=0 的未推变更一起捎走。用当前激活的 ledgerId 触发 sync
      // 就能把这次重命名实时推到服务端，web 端 WS 收到后 2 秒内就能刷新。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        // 不 await：后台异步推送，不阻塞 UI 关闭。
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, '${l10n.commonError}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
