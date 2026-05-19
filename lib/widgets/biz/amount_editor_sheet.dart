import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount/widgets/ui/wheel_date_picker.dart';
import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../services/data/note_history_service.dart';
import '../../services/attachment_service.dart';
import '../../providers.dart';
import '../../pages/tag/widgets/tag_selector.dart';
import 'note_picker_dialog.dart';
import 'account_selector.dart';
import 'tag_chip.dart';
import '../../pages/attachment/attachment_preview_page.dart';

/// 共享账本 tx 作者信息(创建人 + 最后编辑人)— 编辑器底部 sheet 用。
/// editingTransactionId=null(新建 tx)或非共享账本 → 返 null,widget 不渲染。
class _TxAuthorInfo {
  const _TxAuthorInfo({
    required this.creatorUserId,
    required this.lastEditedByUserId,
    required this.currentUserId,
    required this.members,
  });

  final String? creatorUserId;
  final String? lastEditedByUserId;
  final String? currentUserId;
  final List<BeeCountCloudLedgerMember> members;

  BeeCountCloudLedgerMember? memberOf(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }
}

final _txAuthorInfoProvider =
    FutureProvider.autoDispose.family<_TxAuthorInfo?, int>((ref, txId) async {
  final repo = ref.watch(repositoryProvider);
  if (repo is! LocalRepository) return null;
  final db = repo.db;
  final tx = await (db.select(db.transactions)
        ..where((t) => t.id.equals(txId)))
      .getSingleOrNull();
  if (tx == null) return null;
  final ledger = await (db.select(db.ledgers)
        ..where((l) => l.id.equals(tx.ledgerId)))
      .getSingleOrNull();
  if (ledger == null || !ledger.isShared) return null;
  final ledgerSyncId = ledger.syncId;
  if (ledgerSyncId == null || ledgerSyncId.isEmpty) return null;
  if (tx.createdByUserId == null && tx.lastEditedByUserId == null) return null;

  final cloud = await ref.watch(beecountCloudProviderInstance.future);
  if (cloud == null) return null;
  ref.watch(sharedResourceRefreshProvider);
  final me = await cloud.auth.currentUser;
  final members = await cloud.listMembers(ledgerId: ledgerSyncId);
  return _TxAuthorInfo(
    creatorUserId: tx.createdByUserId,
    lastEditedByUserId: tx.lastEditedByUserId,
    currentUserId: me?.id,
    members: members,
  );
});

/// 紧凑头像组 — UX 规则(用户指定):
///   - 创建人 != 编辑人:展示两个头像(long-press tooltip 区分"创建" / "最后编辑")
///   - 创建人 == 编辑人 == 自己:不展示(自己的 tx 看自己头像无意义)
///   - 创建人 == 编辑人 != 自己:展示一个头像(long-press tooltip "X 创建并编辑")
class _TxAuthorAvatars extends ConsumerWidget {
  const _TxAuthorAvatars({required this.editingTransactionId});

  final int editingTransactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final infoAsync = ref.watch(_txAuthorInfoProvider(editingTransactionId));
    final info = infoAsync.valueOrNull;
    if (info == null) return const SizedBox.shrink();

    final creatorId = info.creatorUserId;
    final editorId = info.lastEditedByUserId;
    final meId = info.currentUserId;
    final sameUser = creatorId != null && creatorId == editorId;

    // 单人(创建 == 编辑)且就是自己 → 整体不显示
    if (sameUser && creatorId == meId) return const SizedBox.shrink();

    final cloud = ref.watch(beecountCloudProviderInstance).valueOrNull;
    final baseUrl = cloud?.baseUrl;

    final widgets = <Widget>[];
    if (sameUser) {
      // 同一人(非自己):展示一个头像,tooltip 提示"创建并编辑"
      widgets.add(_AvatarSlot(
        member: info.memberOf(creatorId),
        userIdFallback: creatorId,
        baseUrl: baseUrl,
        tooltipBuilder: (name) => l10n.sharedTxCreatedAndEditedBy(name),
      ));
    } else {
      // 创建人 + 编辑人是两个人:两个头像都展示
      if (creatorId != null) {
        widgets.add(_AvatarSlot(
          member: info.memberOf(creatorId),
          userIdFallback: creatorId,
          baseUrl: baseUrl,
          tooltipBuilder: (name) => l10n.sharedTxCreatedBy(name),
        ));
      }
      if (editorId != null && editorId != creatorId) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(width: 4));
        widgets.add(_AvatarSlot(
          member: info.memberOf(editorId),
          userIdFallback: editorId,
          baseUrl: baseUrl,
          tooltipBuilder: (name) => l10n.sharedTxEditedBy(name),
        ));
      }
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }
}

/// 单个头像槽位 — 不管 member 是否查得到都返回一个 CircleAvatar(带 tooltip)。
/// long-press 触发 Tooltip,tooltip 文案带角色("X 创建" / "X 最后编辑" / ...)。
class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({
    required this.member,
    required this.userIdFallback,
    required this.baseUrl,
    required this.tooltipBuilder,
  });

  final BeeCountCloudLedgerMember? member;
  final String userIdFallback;
  final String? baseUrl;
  final String Function(String name) tooltipBuilder;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final name = m != null
        ? (m.displayName?.isNotEmpty == true
            ? m.displayName!
            : m.email.split('@').first)
        : userIdFallback;
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final rel = m?.avatarUrl;
    final base = baseUrl;
    final absolute = (rel != null && rel.isNotEmpty)
        ? (rel.startsWith('http') ? rel : (base != null ? '$base$rel' : null))
        : null;
    return Tooltip(
      message: tooltipBuilder(name),
      triggerMode: TooltipTriggerMode.longPress,
      child: CircleAvatar(
        radius: 11,
        backgroundColor: BeeTokens.surfaceCapsule(context),
        foregroundImage: absolute != null ? NetworkImage(absolute) : null,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

typedef AmountEditorResult = ({
  double amount,
  String? note,
  DateTime date,
  int? accountId,
  List<int> tagIds,
  List<File> pendingAttachments,
});

class AmountEditorSheet extends ConsumerStatefulWidget {
  final String categoryName; // 仅用于上层提交，不在UI展示
  final DateTime initialDate;
  final double? initialAmount;
  final String? initialNote;
  final int? initialAccountId;
  final List<int>? initialTagIds; // 初始标签ID列表
  final bool showAccountPicker; // 是否显示账户选择
  final ValueChanged<AmountEditorResult> onSubmit;
  final int ledgerId;
  final int? editingTransactionId; // 编辑模式时的交易ID，用于显示已有附件

  const AmountEditorSheet({
    super.key,
    required this.categoryName,
    required this.initialDate,
    this.initialAmount,
    this.initialNote,
    this.initialAccountId,
    this.initialTagIds,
    this.showAccountPicker = false,
    required this.onSubmit,
    required this.ledgerId,
    this.editingTransactionId,
  });

  @override
  ConsumerState<AmountEditorSheet> createState() => _AmountEditorSheetState();
}

class _AmountEditorSheetState extends ConsumerState<AmountEditorSheet> {
  late String _amountStr;
  late DateTime _date;
  int? _selectedAccountId;
  final bool _negative = false; // 显示用途，仅影响UI，不改变保存逻辑
  final TextEditingController _noteCtrl = TextEditingController();
  // 运算缓存：支持简单 + / - 键入累计
  double _acc = 0;
  String? _op; // 最近一次运算符，null 表示尚未进入运算模式

  // 高频备注列表（包含使用次数）
  List<({String note, int count})> _frequentNotes = [];

  // 备注框焦点节点
  final FocusNode _noteFocusNode = FocusNode();
  bool _noteFieldHasFocus = false;

  // 防重复提交标志
  bool _isSubmitting = false;

  // 已选标签ID列表
  late List<int> _selectedTagIds;

  // 待上传的附件列表（新建交易时）
  List<File> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _selectedAccountId = widget.initialAccountId;
    _selectedTagIds = List.from(widget.initialTagIds ?? []);
    // 保留原始小数（最多两位），避免编辑已有记录时小数被截断为整数
    final init = widget.initialAmount ?? 0;
    final s = init.toStringAsFixed(2);
    // 去除多余 0 和结尾的小数点
    final trimmed = s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
    _amountStr = trimmed.isEmpty ? '0' : trimmed;
    _noteCtrl.text = widget.initialNote ?? '';

    // 监听焦点变化
    _noteFocusNode.addListener(() {
      setState(() {
        _noteFieldHasFocus = _noteFocusNode.hasFocus;
      });
    });

    // 加载最近使用的备注
    _loadRecentNotes();
  }

  @override
  void dispose() {
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentNotes() async {
    final repo = ref.read(repositoryProvider);
    final notes = await NoteHistoryService.getFrequentNotes(
      repo,
      widget.ledgerId,
      limit: 20,
    );
    setState(() {
      _frequentNotes = notes;
    });
  }

  void _append(String s) {
    setState(() {
      if (s == '.') {
        if (_amountStr.contains('.')) return;
      }
      // 限制两位小数
      if (_amountStr.contains('.')) {
        final dot = _amountStr.indexOf('.');
        final decimals = _amountStr.length - dot - 1;
        if (s != '.' && decimals >= 2) return;
      }
      // 去除前导 0
      if (_amountStr == '0' && s != '.') {
        _amountStr = s;
      } else if (_amountStr == '-0' && s != '.') {
        _amountStr = '-$s';
      } else {
        _amountStr += s;
      }
    });
    SystemSound.play(SystemSoundType.click);
  }

  void _backspace() {
    setState(() {
      if (_amountStr.isEmpty) return;
      _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      if (_amountStr.isEmpty) _amountStr = '0';
    });
    SystemSound.play(SystemSoundType.click);
  }

  // 旧 _toggleSign 已废弃，符号由类别含义决定

  // _setToday 移除，改为点击日历按钮选择日期

  void _pickDate() async {
    // 关闭键盘，避免选择日期后键盘重新弹出
    FocusManager.instance.primaryFocus?.unfocus();

    // 等待键盘完全关闭
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final showTime = ref.read(showTransactionTimeProvider);

    if (showTime) {
      // 显示时间功能开启时，使用两步选择器（先日期后时间）
      final res = await showWheelDateTimePicker(
        context,
        initial: _date,
        maxDate: DateTime.now(),
      );
      if (res != null) setState(() => _date = res);
    } else {
      // 普通模式，只选择日期
      final res = await showWheelDatePicker(
        context,
        initial: _date,
        mode: WheelDatePickerMode.ymd,
        maxDate: DateTime.now(),
      );
      if (res != null) setState(() => _date = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final text = Theme.of(context).textTheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // 如果备注框有焦点且键盘弹出，固定增加100的padding
    final extraPadding = (_noteFieldHasFocus && keyboardHeight > 0) ? 100.0 : 0.0;

    double parsed() => double.tryParse(_amountStr) ?? 0.0;

    void applyOp(String op) {
      final cur = parsed();
      if (_op == null) {
        // 首次点击运算符，将当前值存入累加器
        _acc = cur;
      } else if (_op == '+') {
        _acc += cur;
      } else if (_op == '-') {
        _acc -= cur;
      }
      _op = op;
      _amountStr = '0';
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
      setState(() {});
    }

    // 计算等号：完成当前运算，将结果存入 _amountStr，清空运算状态
    void applyEquals() {
      if (_op == null) return; // 没有运算符，不执行
      final cur = parsed();
      double total = _acc;
      if (_op == '+') {
        total += cur;
      } else if (_op == '-') {
        total -= cur;
      }
      // 格式化结果
      final s = total.abs().toStringAsFixed(2);
      final trimmed = s.contains('.')
          ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
          : s;
      _amountStr = trimmed.isEmpty ? '0' : trimmed;
      _acc = 0;
      _op = null;
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
      setState(() {});
    }

    Widget keyBtn(String label, {Color? bg, Color? fg, VoidCallback? onTap}) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: bg ?? BeeTokens.surfaceKey(context),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                label,
                style: text.titleMedium?.copyWith(
                  color: fg ?? BeeTokens.textPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    String fmtDate(DateTime d) => '${d.year}/${d.month}/${d.day}';
    String fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    final showTime = ref.watch(showTransactionTimeProvider);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + extraPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 金额显示区域（表达式模式）
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 表达式行:左侧 = 共享账本作者头像(仅编辑模式 + 共享账本时
                // 显示);右侧 = 金额表达式。新建 tx / 单人账本时左侧为空。
                Row(
                  children: [
                    if (widget.editingTransactionId != null)
                      _TxAuthorAvatars(
                          editingTransactionId: widget.editingTransactionId!),
                    const Spacer(),
                    if (_op != null) ...[
                      // 显示累加值
                      Text(
                        (() {
                          final s = _acc.abs().toStringAsFixed(2);
                          final r1 = s.contains('.')
                              ? s.replaceFirst(RegExp(r'0+$'), '')
                              : s;
                          return r1.endsWith('.') ? r1.substring(0, r1.length - 1) : r1;
                        })(),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                      // 显示运算符
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _op == '-' ? '−' : '+',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                    // 当前输入值
                    Text(
                      _amountStr,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.0,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                // 等号行：仅在有运算符时显示
                if (_op != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '= ',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
                      Text(
                        (() {
                          final cur = parsed();
                          final total = _op == '+' ? _acc + cur : _acc - cur;
                          final s = total.abs().toStringAsFixed(2);
                          final r1 = s.contains('.')
                              ? s.replaceFirst(RegExp(r'0+$'), '')
                              : s;
                          return r1.endsWith('.') ? r1.substring(0, r1.length - 1) : r1;
                        })(),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // 备注输入区域 - 带历史备注图标前缀
            TextField(
              focusNode: _noteFocusNode,
              controller: _noteCtrl,
              style: TextStyle(color: BeeTokens.textPrimary(context)),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).commonNoteHint,
                hintStyle: TextStyle(color: BeeTokens.textTertiary(context)),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: BeeTokens.surfaceInput(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                // 历史备注图标作为前缀
                prefixIcon: _frequentNotes.isNotEmpty
                    ? GestureDetector(
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => NotePickerDialog(
                              ledgerId: widget.ledgerId,
                              categoryId: null,
                              onNotePicked: (note) {
                                setState(() {
                                  _noteCtrl.text = note;
                                  _noteCtrl.selection = TextSelection.fromPosition(
                                    TextPosition(offset: note.length),
                                  );
                                });
                              },
                            ),
                          );
                        },
                        child: Icon(
                          Icons.history,
                          color: BeeTokens.iconSecondary(context),
                          size: 20,
                        ),
                      )
                    : null,
                prefixIconConstraints: _frequentNotes.isNotEmpty
                    ? const BoxConstraints(
                        minWidth: 40,
                        minHeight: 20,
                      )
                    : null,
              ),
            ),
            // 账户选择（仅在启用时显示）
            if (widget.showAccountPicker) ...[
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  // 检查账户功能是否启用
                  final accountFeatureAsync =
                      ref.watch(accountFeatureEnabledProvider);
                  return accountFeatureAsync.when(
                    data: (enabled) {
                      if (!enabled) return const SizedBox.shrink();

                      // 使用新的横滑账户选择器
                      return AccountSelector(
                        selectedAccountId: _selectedAccountId,
                        ledgerId: widget.ledgerId,
                        onAccountSelected: (accountId) {
                          setState(() {
                            _selectedAccountId = accountId;
                          });
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ],
            // 标签和附件选择区域（一行）
            const SizedBox(height: 8),
            _buildTagAndAttachmentRow(),
            const SizedBox(height: 10),
            // 数字键盘
            LayoutBuilder(builder: (ctx, c) {
              final w = (c.maxWidth) / 4;
              Widget dateKey() => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      color: BeeTokens.surfaceKeySecondary(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          SystemSound.play(SystemSoundType.click);
                          _pickDate();
                        },
                        child: SizedBox(
                          height: 60,
                          child: Center(
                            child: showTime
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        fmtDate(_date),
                                        style: text.labelSmall?.copyWith(
                                            color: BeeTokens.textPrimary(context),
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        fmtTime(_date),
                                        style: text.labelSmall?.copyWith(
                                            color: BeeTokens.textSecondary(context),
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  )
                                : Text(
                                    fmtDate(_date),
                                    style: text.labelMedium?.copyWith(
                                        color: BeeTokens.textPrimary(context),
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
              Widget closeKey() => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      color: BeeTokens.surfaceKey(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _backspace,
                        child: SizedBox(
                          height: 60,
                          child: Center(
                              child: Icon(Icons.backspace_outlined,
                                  color: BeeTokens.textPrimary(context))),
                        ),
                      ),
                    ),
                  );
              Widget doneKey() {
                // 计算当前总额以判断是否启用完成按钮
                final cur = parsed();
                double total;
                if (_op == '+') {
                  total = _acc + cur;
                } else if (_op == '-') {
                  total = _acc - cur;
                } else {
                  total = cur;
                }

                // 判断是否处于运算模式
                final isInCalcMode = _op != null;
                final isEnabled = (isInCalcMode ? true : total.abs() > 0) && !_isSubmitting;

                return Padding(
                  padding: const EdgeInsets.all(6),
                  child: Material(
                    color: isEnabled ? primary : BeeTokens.surfaceDisabled(context),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isEnabled
                          ? () async {
                              if (isInCalcMode) {
                                // 运算模式：点击等号计算结果
                                applyEquals();
                                return;
                              }

                              // 正常模式：提交
                              // 防重复点击
                              if (_isSubmitting) return;
                              setState(() => _isSubmitting = true);

                              HapticFeedback.lightImpact();
                              SystemSound.play(SystemSoundType.click);
                              widget.onSubmit((
                                amount: total.abs(), // 始终正数
                                note: _noteCtrl.text.isEmpty
                                    ? null
                                    : _noteCtrl.text,
                                date: _date,
                                accountId: _selectedAccountId,
                                tagIds: _selectedTagIds,
                                pendingAttachments: _pendingAttachments,
                              ));

                              // 注意：不需要在这里重置 _isSubmitting
                              // 因为提交后整个 Sheet 会被关闭，State 会被销毁
                            }
                          : null,
                      child: SizedBox(
                        height: 60,
                        child: Center(
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isInCalcMode ? '=' : AppLocalizations.of(context).commonFinish,
                                  style: TextStyle(
                                      color: isEnabled ? Colors.white : BeeTokens.textTertiary(context),
                                      fontSize: isInCalcMode ? 24 : 16,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('7', onTap: () => _append('7'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('8', onTap: () => _append('8'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('9', onTap: () => _append('9'))),
                    SizedBox(width: w, child: dateKey()),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('4', onTap: () => _append('4'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('5', onTap: () => _append('5'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('6', onTap: () => _append('6'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('+',
                            bg: BeeTokens.surfaceKeySecondary(context), onTap: () => applyOp('+'))),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('1', onTap: () => _append('1'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('2', onTap: () => _append('2'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('3', onTap: () => _append('3'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('-',
                            bg: BeeTokens.surfaceKeySecondary(context), onTap: () => applyOp('-'))),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('.', onTap: () => _append('.'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('0', onTap: () => _append('0'))),
                    SizedBox(width: w, child: closeKey()),
                    SizedBox(width: w, child: doneKey()),
                  ]),
                ],
              );
            })
          ],
        ),
      ),
    );
  }

  /// 构建标签和附件选择行（一行显示）
  Widget _buildTagAndAttachmentRow() {
    // §7 共享账本:用按当前 ledger 过滤后的 tags(Editor 视角下走 SharedLedgerTags,
    // synthetic id 跟 tag picker 一致),否则编辑模式 tx 已选的 synthetic id 在
    // 主表里找不到,显示"无标签"。
    final allTagsAsync = ref.watch(tagsForCurrentLedgerProvider);
    final allTags = allTagsAsync.valueOrNull ?? [];

    // 获取已选中的标签详情
    final selectedTags = allTags
        .where((t) => _selectedTagIds.contains(t.id))
        .toList();

    // 获取附件数量
    if (widget.editingTransactionId != null) {
      final attachmentsAsync = ref.watch(transactionAttachmentsProvider(widget.editingTransactionId!));
      // 同样使用 valueOrNull 避免闪烁
      final attachments = attachmentsAsync.valueOrNull ?? [];
      final totalCount = attachments.length + _pendingAttachments.length;
      return _buildRowContent(selectedTags, totalCount, attachments);
    }
    return _buildRowContent(selectedTags, _pendingAttachments.length, []);
  }

  Widget _buildRowContent(List<Tag> selectedTags, int attachmentCount, List<TransactionAttachment> savedAttachments) {
    final l10n = AppLocalizations.of(context);
    final hasAttachments = attachmentCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BeeTokens.surfaceInput(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 标签部分（可点击展开）
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final result = await TagSelector.show(
                  context,
                  selectedTagIds: _selectedTagIds,
                );
                if (result != null) {
                  setState(() {
                    _selectedTagIds = result;
                  });
                }
              },
              behavior: HitTestBehavior.opaque,
              child: selectedTags.isEmpty
                  ? Text(
                      l10n.tagSelectTitle,
                      style: TextStyle(
                        color: BeeTokens.textTertiary(context),
                        fontSize: 14,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: selectedTags.map((tag) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: TagChip(
                              name: tag.name,
                              color: tag.color,
                              size: TagChipSize.small,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
          // 间距代替分隔线
          const SizedBox(width: 16),
          // 附件部分（图标 + 数字）
          GestureDetector(
            onTap: () => _handleAttachmentTap(savedAttachments),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasAttachments ? Icons.image : Icons.image_outlined,
                  size: 18,
                  color: hasAttachments
                      ? Theme.of(context).colorScheme.primary
                      : BeeTokens.iconSecondary(context),
                ),
                if (hasAttachments) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$attachmentCount',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttachmentTap(List<TransactionAttachment> savedAttachments) async {
    final totalCount = savedAttachments.length + _pendingAttachments.length;

    if (totalCount == 0) {
      // 没有附件，直接添加
      await _showAddAttachmentOptions();
    } else {
      // 有附件，打开预览页（支持添加和删除）
      final result = await Navigator.push<List<File>?>(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentPreviewPage(
            attachments: savedAttachments,
            initialIndex: 0,
            allowDelete: true,
            allowAdd: true,
            pendingFiles: _pendingAttachments,
            transactionId: widget.editingTransactionId,
          ),
        ),
      );
      // 如果返回了新的待上传文件列表，更新状态
      if (result != null) {
        setState(() {
          _pendingAttachments = result;
        });
      }
    }
  }

  Future<void> _showAddAttachmentOptions() async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(attachmentServiceProvider);

    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.attachmentTakePhoto),
              onTap: () async {
                Navigator.pop(context);
                final file = await service.takePhoto();
                if (file != null && mounted) {
                  if (widget.editingTransactionId != null) {
                    // 编辑模式：直接保存
                    await service.saveAttachment(
                      transactionId: widget.editingTransactionId!,
                      sourceFile: file,
                      index: 0,
                    );
                    ref.read(attachmentListRefreshProvider.notifier).state++;
                  } else {
                    // 新建模式：添加到待上传列表
                    setState(() {
                      _pendingAttachments = [..._pendingAttachments, file];
                    });
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.attachmentChooseFromGallery),
              onTap: () async {
                Navigator.pop(context);
                final files = await service.pickFromGallery(maxCount: 9 - _pendingAttachments.length);
                if (files.isNotEmpty && mounted) {
                  if (widget.editingTransactionId != null) {
                    // 编辑模式：直接保存
                    await service.saveAttachments(
                      transactionId: widget.editingTransactionId!,
                      sourceFiles: files,
                      startIndex: 0,
                    );
                    ref.read(attachmentListRefreshProvider.notifier).state++;
                  } else {
                    // 新建模式：添加到待上传列表
                    setState(() {
                      _pendingAttachments = [..._pendingAttachments, ...files];
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
