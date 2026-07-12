import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/data/note_history_service.dart';
import '../../styles/tokens.dart';
import '../../providers.dart';

/// 备注选择弹窗
/// 支持可选的分类ID和账本ID参数,用于筛选历史备注
class NotePickerDialog extends ConsumerStatefulWidget {
  final int ledgerId;
  final int? categoryId; // 可选：分类ID
  final ValueChanged<String> onNotePicked;

  const NotePickerDialog({
    super.key,
    required this.ledgerId,
    this.categoryId,
    required this.onNotePicked,
  });

  @override
  ConsumerState<NotePickerDialog> createState() => _NotePickerDialogState();
}

class _NotePickerDialogState extends ConsumerState<NotePickerDialog> {
  List<({String note, int count})> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final repo = ref.read(repositoryProvider);
      final notes = await NoteHistoryService.getFrequentNotes(
        repo,
        widget.ledgerId,
        limit: 20,
      );
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      backgroundColor: BeeTokens.surfaceElevated(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              '历史备注',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context)),
            ),
            const SizedBox(height: 12),
            // 备注列表
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_notes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.commonEmpty,
                  style: TextStyle(color: BeeTokens.textSecondary(context)),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _notes.map((item) {
                      return InkWell(
                        onTap: () {
                          widget.onNotePicked(item.note);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: BeeTokens.surfaceChip(context),
                            borderRadius: BorderRadius.circular(16),
                            border: BeeTokens.isDark(context)
                                ? Border.all(color: BeeTokens.border(context))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.note,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: BeeTokens.textSecondary(context),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${item.count}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // 关闭按钮
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.commonClose),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
