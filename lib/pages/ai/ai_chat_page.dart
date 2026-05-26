import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/bee_icon.dart';
import '../../widgets/ai/typewriter_text.dart';
import '../../widgets/ai/bill_card_widget.dart';
import '../../widgets/ai/ai_quick_commands_bar.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../services/billing/post_processor.dart';
import '../../providers.dart';
import '../../providers/ai_chat_providers.dart';
import '../../ai/core/bill_info.dart';
import '../../pages/transaction/transaction_editor_page.dart';
import '../../pages/ai/ai_settings_page.dart';
import '../../widgets/biz/ledger_selector_dialog.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ai_quick_command.dart';
import '../../services/ui/avatar_service.dart';
import '../../services/system/logger_service.dart';
import '../../services/ai/ai_chat_service.dart';
import '../../services/ai/ai_quick_command_service.dart';

/// AI 对话页面
class AIChatPage extends ConsumerStatefulWidget {
  const AIChatPage({super.key});

  @override
  ConsumerState<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends ConsumerState<AIChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _conversationId;
  bool _isLoading = false;
  int? _animatingMessageId; // 正在播放动画的消息ID
  String? _userAvatarPath; // 用户头像路径
  AIConfigValidationResult? _apiValidation; // API配置验证结果
  bool _showScrollToBottom = false; // 是否显示"回到底部"按钮
  bool _isFirstLoad = true; // 是否首次加载

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConversation();
    _loadUserAvatar();
    // 在下一帧后执行 API 验证，完全不阻塞页面渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateApiConfig();
    });
    _scrollController.addListener(_handleScroll);
  }

  /// 处理滚动事件
  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final scrollOffset = position.pixels;
    final maxScroll = position.maxScrollExtent;

    // 列表可滚动 且 距离底部超过50像素时显示按钮
    final shouldShow = maxScroll > 0 && (maxScroll - scrollOffset) > 50;

    if (shouldShow != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用从后台恢复到前台时，重新验证API配置
    if (state == AppLifecycleState.resumed) {
      _validateApiConfig();
    }
  }

  /// 验证 API 配置（仅检查本地配置，不发网络请求）
  Future<void> _validateApiConfig() async {
    try {
      final result = await AIChatService.validateApiKey();
      if (!mounted) return;
      setState(() => _apiValidation = result);
    } catch (e, st) {
      logger.error('AIChat', 'API 配置检查失败', e, st);
      if (!mounted) return;
      setState(() {
        _apiValidation = AIConfigValidationResult.invalid('配置检查失败');
      });
    }
  }

  Future<void> _loadUserAvatar() async {
    final path = await AvatarService.getAvatarPath();
    if (mounted) {
      setState(() {
        _userAvatarPath = path;
      });
    }
  }

  Future<void> _initConversation() async {
    final repo = ref.read(repositoryProvider);

    // 查找全局活跃对话（不限制账本）
    final conv = await repo.getActiveConversation();

    if (conv != null) {
      setState(() => _conversationId = conv.id);
    } else {
      // 创建新对话（全局对话，不关联账本）
      final id = await repo.createConversation(
        ConversationsCompanion.insert(
          title: const Value('AI对话'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      setState(() => _conversationId = id);
    }

    ref.read(currentConversationIdProvider.notifier).state = _conversationId;
  }

  @override
  Widget build(BuildContext context) {
    if (_conversationId == null) {
      return Scaffold(
        backgroundColor: BeeTokens.scaffoldBackground(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(_conversationId!));

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // Header
          PrimaryHeader(
            title: AppLocalizations.of(context).aiChatTitle,
            showBack: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: AppLocalizations.of(context).aiChatClearHistory,
                onPressed: _showClearHistoryDialog,
              ),
            ],
          ),

          // API配置警告横幅
          if (_apiValidation != null && !_apiValidation!.isValid)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              padding: EdgeInsets.all(12.0.scaled(context, ref)),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red[700],
                    size: 20.0.scaled(context, ref),
                  ),
                  SizedBox(width: 8.0.scaled(context, ref)),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).aiChatConfigWarning,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13.0.scaled(context, ref),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AISettingsPage(),
                        ),
                      );
                      // 返回后重新验证
                      if (mounted) {
                        await _validateApiConfig();
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).aiChatGoToSettings,
                      style: TextStyle(
                        color: ref.watch(primaryColorProvider),
                        fontSize: 13.0.scaled(context, ref),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: Stack(
              children: [
                messagesAsync.when(
                  data: (messages) {
                    // 首次加载完成且有消息时，自动滚动到底部
                    if (_isFirstLoad && messages.isNotEmpty) {
                      _isFirstLoad = false;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });
                    }

                    if (messages.isEmpty) {
                      return const Center(child: Text('暂无消息'));
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.0.scaled(context, ref),
                        vertical: 8.0.scaled(context, ref),
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(messages[index]);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('加载失败: $e')),
                ),

                // 回到底部按钮
                if (_showScrollToBottom)
                  Positioned(
                    right: 16.0.scaled(context, ref),
                    bottom: 16.0.scaled(context, ref),
                    child: Material(
                      color: ref.watch(primaryColorProvider),
                      borderRadius:
                          BorderRadius.circular(24.0.scaled(context, ref)),
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.4),
                      child: InkWell(
                        onTap: _scrollToBottomWithAnimation,
                        borderRadius:
                            BorderRadius.circular(24.0.scaled(context, ref)),
                        child: Container(
                          width: 48.0.scaled(context, ref),
                          height: 48.0.scaled(context, ref),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 30.0.scaled(context, ref),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 加载指示器
          if (_isLoading)
            Container(
              padding: EdgeInsets.symmetric(
                vertical: 8.0.scaled(context, ref),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16.0.scaled(context, ref),
                    height: 16.0.scaled(context, ref),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ref.watch(primaryColorProvider),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.0.scaled(context, ref)),
                  Text(
                    AppLocalizations.of(context).aiChatThinking,
                    style: TextStyle(
                      color: BeeTokens.textSecondary(context),
                      fontSize: 13.0.scaled(context, ref),
                    ),
                  ),
                ],
              ),
            ),

          // 快捷指令横条
          AIQuickCommandsBar(
            onCommandTap: _handleQuickCommand,
          ),

          // 输入区域
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.role == 'user';

    // 只对正在播放动画的消息ID启用动画
    final shouldAnimate = !isUser && message.id == _animatingMessageId;

    // 记账卡片
    if (message.messageType == 'bill_card' && message.metadata != null) {
      final parsed = _parseBillMetadata(message);

      // 单笔走原有 UI(保持视觉一致)
      if (parsed.bills.length == 1) {
        final bill = parsed.bills.first;
        final txId = parsed.txIds.isNotEmpty ? parsed.txIds.first : null;
        final isUndone = txId != null && parsed.undoneIds.contains(txId);
        return GestureDetector(
          onLongPressStart: (details) => _showBillCardMenu(
            details.globalPosition,
            message,
          ),
          child: BillCardWidget(
            billInfo: bill,
            transactionId: txId,
            isUndone: isUndone,
            onUndo: txId != null && !isUndone
                ? () => _handleUndoOne(message.id, txId)
                : null,
            onEdit: txId != null && !isUndone
                ? () => _handleEdit(message.id, txId)
                : null,
            onChangeLedger: txId != null && !isUndone
                ? () => _handleChangeLedger(message.id, txId)
                : null,
          ),
        );
      }

      // 多笔
      return _buildMultiBillBubble(message, parsed);
    }

    // 普通文字消息 - 带头像
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0.scaled(context, ref)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // AI头像（左侧）
          if (!isUser) ...[
            _buildAIAvatar(),
            SizedBox(width: 8.0.scaled(context, ref)),
          ],
          // 消息气泡
          Flexible(
            child: GestureDetector(
              onLongPressStart: (details) => _showTextMessageMenu(
                details.globalPosition,
                message,
                isUser,
              ),
              child: Container(
                margin: EdgeInsets.only(
                  left: isUser ? 60.0.scaled(context, ref) : 0,
                  right: isUser ? 0 : 60.0.scaled(context, ref),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 12.0.scaled(context, ref),
                  vertical: 10.0.scaled(context, ref),
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? ref.watch(primaryColorProvider).withOpacity(0.1)
                      : BeeTokens.surface(context),
                  borderRadius:
                      BorderRadius.circular(12.0.scaled(context, ref)),
                  border: Border.all(
                    color: isUser
                        ? ref.watch(primaryColorProvider).withOpacity(0.3)
                        : BeeTokens.border(context),
                  ),
                ),
                child: TypewriterText(
                  text: message.content,
                  animate: shouldAnimate, // 只对标记的消息启用动画
                  onTextChange: shouldAnimate
                      ? () {
                          // 每次文本更新时滚动到底部
                          _scrollToBottomSmooth();
                        }
                      : null,
                  onComplete: shouldAnimate
                      ? () {
                          // 动画完成后清除标记
                          if (mounted) {
                            setState(() {
                              _animatingMessageId = null;
                            });
                          }
                        }
                      : null,
                  style: TextStyle(
                    color: BeeTokens.textPrimary(context),
                    fontSize: 14.0.scaled(context, ref),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          // 用户头像（右侧，仅在有头像时显示）
          if (isUser && _userAvatarPath != null) ...[
            SizedBox(width: 8.0.scaled(context, ref)),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  // 构建AI头像
  Widget _buildAIAvatar() {
    return Container(
      width: 32.0.scaled(context, ref),
      height: 32.0.scaled(context, ref),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ref.watch(primaryColorProvider).withOpacity(0.3),
          width: 1.5,
        ),
        color: ref.watch(primaryColorProvider).withOpacity(0.1),
      ),
      child: Center(
        child: BeeIcon(
          color: ref.watch(primaryColorProvider),
          size: 18.0.scaled(context, ref),
        ),
      ),
    );
  }

  // 构建用户头像
  Widget _buildUserAvatar() {
    return Container(
      width: 32.0.scaled(context, ref),
      height: 32.0.scaled(context, ref),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: BeeTokens.border(context),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Image.file(
          File(_userAvatarPath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 加载失败时不显示
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16.0.scaled(context, ref)),
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        border: Border(
          top: BorderSide(
            color: BeeTokens.divider(context),
          ),
        ),
      ),
      child: SafeArea(
        top: false, // 不保护顶部，避免额外空白
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).aiChatInputHint,
                  hintStyle: TextStyle(
                    color: BeeTokens.textTertiary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(20.0.scaled(context, ref)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: BeeTokens.scaffoldBackground(context),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0.scaled(context, ref),
                    vertical: 10.0.scaled(context, ref),
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isLoading,
              ),
            ),
            SizedBox(width: 8.0.scaled(context, ref)),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _isLoading
                    ? BeeTokens.textTertiary(context)
                    : ref.watch(primaryColorProvider),
              ),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  /// 处理快捷指令点击
  Future<void> _handleQuickCommand(AIQuickCommand command) async {
    if (_isLoading) return;

    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      final commandService = ref.read(aiQuickCommandServiceProvider(ledgerId));
      final l10n = AppLocalizations.of(context);

      // 生成完整的 Prompt
      final prompt = await commandService.generatePrompt(command, context);

      // 获取快捷指令的标题作为显示文本
      String displayText;
      switch (command.titleKey) {
        case 'aiQuickCommandFinancialHealthTitle':
          displayText = l10n.aiQuickCommandFinancialHealthTitle;
          break;
        case 'aiQuickCommandMonthlyExpenseTitle':
          displayText = l10n.aiQuickCommandMonthlyExpenseTitle;
          break;
        case 'aiQuickCommandCategoryAnalysisTitle':
          displayText = l10n.aiQuickCommandCategoryAnalysisTitle;
          break;
        case 'aiQuickCommandBudgetPlanningTitle':
          displayText = l10n.aiQuickCommandBudgetPlanningTitle;
          break;
        case 'aiQuickCommandAbnormalExpenseTitle':
          displayText = l10n.aiQuickCommandAbnormalExpenseTitle;
          break;
        case 'aiQuickCommandSavingTipsTitle':
          displayText = l10n.aiQuickCommandSavingTipsTitle;
          break;
        default:
          displayText = command.titleKey;
      }

      // 发送完整prompt给AI，但在对话中只显示标题
      await _sendMessageText(
        prompt,
        displayText: displayText,
        forceChat: true,
      );
    } catch (e, st) {
      logger.error('AIChat', '处理快捷指令失败', e, st);
      if (mounted) {
        showToast(context, '${AppLocalizations.of(context).commonFailed}: $e');
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();
    await _sendMessageText(text);
  }

  /// 发送消息文本
  ///
  /// [text] - 发送给AI的完整文本
  /// [displayText] - 在对话框中显示的文本（可选，默认使用text）
  /// [forceChat] - 强制为自由对话模式
  Future<void> _sendMessageText(
    String text, {
    String? displayText,
    bool forceChat = false,
  }) async {
    if (text.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(repositoryProvider);

      // 保存用户消息（使用displayText作为显示内容，如果没有则使用text）
      await repo.createMessage(
        MessagesCompanion.insert(
          conversationId: _conversationId!,
          role: 'user',
          content: displayText ?? text,
          messageType: 'text',
          createdAt: Value(DateTime.now()),
        ),
      );

      _scrollToBottom();

      // chat_service 内部走 BillExtractionService.forLedger,会自动查
      // 当前账本可用分类 + 同币种账户,page 层不再预查。
      final chatService = ref.read(aiChatServiceProvider);
      final currentLocale = Localizations.localeOf(context);
      final ledgerId = ref.read(currentLedgerIdProvider);
      final l10n = AppLocalizations.of(context);

      logger.info('AIChat', '当前账本ID: $ledgerId');

      final response = await chatService.processMessage(
        text,
        ledgerId: ledgerId,
        languageCode: currentLocale.languageCode,
        forceChat: forceChat, // 快捷指令强制为自由对话
        l10n: l10n,
      );

      // 保存 AI 回复。多笔 metadata 用新格式 {bills, txIds, undoneIds};
      // transactionId 列仍存第一笔 id(getMessageByTransactionId 兼容)。
      final messageId = await repo.createMessage(
        MessagesCompanion.insert(
          conversationId: _conversationId!,
          role: 'assistant',
          content: response.text,
          messageType: response.type,
          metadata: response.bills.isNotEmpty
              ? Value(_encodeBillMetadata(
                  response.bills,
                  response.transactionIds,
                  const <int>{},
                ))
              : const Value.absent(),
          transactionId: response.transactionId != null
              ? Value(response.transactionId)
              : const Value.absent(),
          createdAt: Value(DateTime.now()),
        ),
      );

      // 如果是记账成功，刷新统计信息
      if (response.type == 'bill_card' && response.transactionId != null) {
        // 刷新全局统计信息
        ref.read(statsRefreshProvider.notifier).state++;

        // 触发云同步
        final billLedgerId = response.billInfo?.ledgerId ?? ledgerId;
        await PostProcessor.sync(ref, ledgerId: billLedgerId);

        logger.info('AIChat', '记账成功，已刷新统计信息和触发云同步');
      }

      // 设置动画消息ID
      setState(() {
        _animatingMessageId = messageId;
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        showToast(
            context, '${AppLocalizations.of(context).aiChatSendFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 点击按钮时滚动到底部（立即执行）
  void _scrollToBottomWithAnimation() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 平滑滚动到底部（用于打字机效果期间）
  /// 使用 jumpTo 避免频繁调用 animateTo 造成性能问题
  void _scrollToBottomSmooth() {
    // 使用 postFrameCallback 确保在布局完成后滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _showClearHistoryDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiChatClearHistoryDialogTitle),
        content: Text(l10n.aiChatClearHistoryDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              _clearHistory();
              Navigator.pop(context);
            },
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _clearHistory() async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteMessagesByConversation(_conversationId!);

    if (mounted) {
      showToast(context, AppLocalizations.of(context).aiChatHistoryCleared);
    }
  }

  /// 撤销单笔(多笔卡片里的某一笔,或单笔卡片)
  Future<void> _handleUndoOne(int messageId, int transactionId) async {
    final chatService = ref.read(aiChatServiceProvider);
    final success = await chatService.undoTransaction(transactionId);

    if (!success) {
      if (mounted) {
        showToast(context, AppLocalizations.of(context).aiChatUndoFailed);
      }
      return;
    }

    final repo = ref.read(repositoryProvider);
    final message = await repo.getMessageById(messageId);
    if (message == null || message.metadata == null) {
      if (mounted) showToast(context, AppLocalizations.of(context).aiChatUndone);
      return;
    }

    final parsed = _parseBillMetadata(message);
    final newUndone = {...parsed.undoneIds, transactionId};
    await repo.updateMessage(message.copyWith(
      metadata: Value(_encodeBillMetadata(
        parsed.bills,
        parsed.txIds,
        newUndone,
      )),
    ));

    ref.read(statsRefreshProvider.notifier).state++;

    // 找出这笔对应的账本触发同步
    final idx = parsed.txIds.indexOf(transactionId);
    if (idx >= 0 && idx < parsed.bills.length) {
      final ledgerId = parsed.bills[idx].ledgerId;
      if (ledgerId != null) {
        await PostProcessor.sync(ref, ledgerId: ledgerId);
        logger.info('AIChat', '撤销单笔成功 txId=$transactionId,已同步');
      }
    }

    if (mounted) {
      showToast(context, AppLocalizations.of(context).aiChatUndone);
    }
  }

  Future<void> _handleEdit(int messageId, int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);

      final transaction = await repo.getTransactionById(transactionId);

      if (transaction == null) {
        if (mounted) {
          showToast(
              context, AppLocalizations.of(context).aiChatTransactionNotFound);
        }
        return;
      }

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionEditorPage(
              initialKind: transaction.type,
              quickAdd: true,
              initialCategoryId: transaction.categoryId,
              initialAmount: transaction.amount,
              initialDate: transaction.happenedAt,
              initialNote: transaction.note,
              editingTransactionId: transaction.id,
              initialAccountId: transaction.accountId,
              initialToAccountId: transaction.toAccountId,
            ),
          ),
        );

        // 从编辑页面返回后，无论是否保存，都刷新账单卡片
        if (mounted) {
          logger.info('AIChat',
              '编辑页面返回,刷新账单卡片: messageId=$messageId, txId=$transactionId');
          await _refreshBillCard(messageId, transactionId);
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(context, AppLocalizations.of(context).aiChatOpenEditorFailed);
      }
    }
  }

  /// 刷新账单卡片信息(根据 messageId 定位消息,根据 txId 在多笔里定位行)
  Future<void> _refreshBillCard(int messageId, int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final message = await repo.getMessageById(messageId);
      if (message == null || message.metadata == null) return;

      final transaction = await repo.getTransactionById(transactionId);
      if (transaction == null) return;

      String? categoryName;
      if (transaction.categoryId != null) {
        final category = await repo.getCategoryById(transaction.categoryId!);
        categoryName = category?.name;
      }
      String? accountName;
      if (transaction.accountId != null) {
        final account = await repo.getAccount(transaction.accountId!);
        accountName = account?.name;
      }

      final updatedBillInfo = BillInfo(
        amount: transaction.amount,
        time: transaction.happenedAt,
        note: transaction.note,
        category: categoryName,
        type: transaction.type == 'expense'
            ? BillType.expense
            : (transaction.type == 'transfer'
                ? BillType.transfer
                : BillType.income),
        account: accountName,
        ledgerId: transaction.ledgerId,
        confidence: 1.0,
      );

      final parsed = _parseBillMetadata(message);
      final idx = parsed.txIds.indexOf(transactionId);
      if (idx < 0 || idx >= parsed.bills.length) {
        logger.warning('AIChat',
            '_refreshBillCard: 在 message $messageId 中找不到 txId=$transactionId');
        return;
      }
      final newBills = List<BillInfo>.from(parsed.bills);
      newBills[idx] = updatedBillInfo;

      await repo.updateMessage(message.copyWith(
        metadata: Value(_encodeBillMetadata(
          newBills,
          parsed.txIds,
          parsed.undoneIds,
        )),
      ));

      logger.info(
          'AIChat', '账单卡片已刷新: messageId=$messageId, txId=$transactionId');
    } catch (e, st) {
      logger.error('AIChat', '刷新账单卡片失败', e, st);
    }
  }

  /// 修改账本
  Future<void> _handleChangeLedger(int messageId, int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);

      // 获取当前交易
      final transaction = await repo.getTransactionById(transactionId);

      if (transaction == null) {
        if (mounted) {
          showToast(
              context, AppLocalizations.of(context).aiChatTransactionNotFound);
        }
        return;
      }

      if (!mounted) return;

      // 显示账本选择对话框
      final selectedLedgerId = await showLedgerSelector(
        context,
        currentLedgerId: transaction.ledgerId,
      );

      if (selectedLedgerId == null ||
          selectedLedgerId == transaction.ledgerId) {
        return; // 用户取消或选择了相同的账本
      }

      // 更新交易的账本
      await repo.updateTransactionLedger(
        id: transactionId,
        ledgerId: selectedLedgerId,
      );

      // 更新消息的 metadata(多笔:仅更新匹配 txId 的那一笔)
      final message = await repo.getMessageById(messageId);

      if (message != null && message.metadata != null) {
        final parsed = _parseBillMetadata(message);
        final idx = parsed.txIds.indexOf(transactionId);
        if (idx >= 0 && idx < parsed.bills.length) {
          final newBills = List<BillInfo>.from(parsed.bills);
          newBills[idx] = parsed.bills[idx].copyWith(ledgerId: selectedLedgerId);
          await repo.updateMessage(message.copyWith(
            metadata: Value(_encodeBillMetadata(
              newBills,
              parsed.txIds,
              parsed.undoneIds,
            )),
          ));
        } else {
          logger.warning('AIChat',
              '_handleChangeLedger: 在 message $messageId 中找不到 txId=$transactionId');
        }

        // 刷新统计信息（修改账本后，需要刷新旧账本和新账本的统计）
        ref.read(statsRefreshProvider.notifier).state++;

        // 触发云同步（旧账本和新账本都需要同步）
        await PostProcessor.sync(ref, ledgerId: transaction.ledgerId);
        await PostProcessor.sync(ref, ledgerId: selectedLedgerId);

        logger.info('AIChat',
            '修改账本成功: ${transaction.ledgerId} -> $selectedLedgerId,已刷新统计信息和触发云同步');

        if (mounted) {
          setState(() {}); // 触发重建以显示新的账本名称
        }
      }

      if (mounted) {
        showToast(context, AppLocalizations.of(context).commonSuccess);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, AppLocalizations.of(context).commonFailed);
      }
    }
  }

  /// 显示文字消息的长按菜单
  void _showTextMessageMenu(Offset position, Message message, bool isUser) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.read(primaryColorProvider);

    MessagePopoverMenu.show(
      context: context,
      globalPosition: position,
      primaryColor: primaryColor,
      items: [
        PopoverMenuItem(
          icon: Icons.copy,
          label: l10n.aiChatCopy,
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.content));
            showToast(context, l10n.aiChatCopied);
          },
        ),
        PopoverMenuItem(
          icon: Icons.delete_outline,
          label: l10n.commonDelete,
          color: Colors.red,
          onTap: () => _deleteMessage(message),
        ),
      ],
    );
  }

  /// 显示记账卡片的长按菜单
  void _showBillCardMenu(Offset position, Message message) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.read(primaryColorProvider);

    MessagePopoverMenu.show(
      context: context,
      globalPosition: position,
      primaryColor: primaryColor,
      items: [
        PopoverMenuItem(
          icon: Icons.delete_outline,
          label: l10n.commonDelete,
          color: Colors.red,
          onTap: () => _deleteMessage(message),
        ),
      ],
    );
  }

  /// 删除单条消息
  Future<void> _deleteMessage(Message message) async {
    final l10n = AppLocalizations.of(context);

    // 确认删除
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.commonDelete,
      message: l10n.aiChatDeleteMessageConfirm,
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(repositoryProvider);
      await repo.deleteMessage(message.id);

      if (mounted) {
        showToast(context, l10n.aiChatMessageDeleted);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, l10n.commonFailed);
      }
    }
  }

  // ============================================================
  // 多笔账单 metadata 编解码
  //
  // 新格式: {"bills":[...], "txIds":[...], "undoneIds":[...]}
  // 老格式: {"billInfo":{...}, "isUndone":bool}  ← 自动转
  //
  // bills.length == txIds.length;undoneIds 是 txIds 的子集。
  // ============================================================

  ({List<BillInfo> bills, List<int> txIds, Set<int> undoneIds})
      _parseBillMetadata(Message m) {
    final raw = jsonDecode(m.metadata!) as Map<String, dynamic>;

    // 新格式
    if (raw['bills'] is List) {
      final bills = (raw['bills'] as List)
          .whereType<Map>()
          .map((j) => BillInfo.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      final txIds = ((raw['txIds'] as List?) ?? const [])
          .whereType<int>()
          .toList();
      final undoneIds = ((raw['undoneIds'] as List?) ?? const [])
          .whereType<int>()
          .toSet();
      return (bills: bills, txIds: txIds, undoneIds: undoneIds);
    }

    // 老格式
    final billJson = raw['billInfo'] is Map
        ? Map<String, dynamic>.from(raw['billInfo'] as Map)
        : raw;
    final bill = BillInfo.fromJson(billJson);
    final txId = m.transactionId;
    final isUndone = raw['isUndone'] == true;
    return (
      bills: [bill],
      txIds: txId != null ? <int>[txId] : <int>[],
      undoneIds: (isUndone && txId != null) ? <int>{txId} : <int>{},
    );
  }

  String _encodeBillMetadata(
    List<BillInfo> bills,
    List<int> txIds,
    Set<int> undoneIds,
  ) {
    return jsonEncode({
      'bills': bills.map((b) => b.toJson()).toList(),
      'txIds': txIds,
      'undoneIds': undoneIds.toList(),
    });
  }

  // ============================================================
  // 多笔账单气泡: 直接渲染 N 张 BillCardWidget,无额外汇总/折叠/全部撤销。
  // 每张卡保留单笔已有的 undo/edit/changeLedger。
  // ============================================================

  Widget _buildMultiBillBubble(
    Message message,
    ({List<BillInfo> bills, List<int> txIds, Set<int> undoneIds}) parsed,
  ) {
    final bills = parsed.bills;
    final txIds = parsed.txIds;
    final undoneIds = parsed.undoneIds;

    return GestureDetector(
      onLongPressStart: (details) => _showBillCardMenu(
        details.globalPosition,
        message,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < bills.length; i++)
            Builder(builder: (_) {
              final txId = i < txIds.length ? txIds[i] : null;
              final isUndone = txId != null && undoneIds.contains(txId);
              return BillCardWidget(
                billInfo: bills[i],
                transactionId: txId,
                isUndone: isUndone,
                onUndo: txId != null && !isUndone
                    ? () => _handleUndoOne(message.id, txId)
                    : null,
                onEdit: txId != null && !isUndone
                    ? () => _handleEdit(message.id, txId)
                    : null,
                onChangeLedger: txId != null && !isUndone
                    ? () => _handleChangeLedger(message.id, txId)
                    : null,
              );
            }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
