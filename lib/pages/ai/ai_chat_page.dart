import 'dart:convert';
import 'dart:io';

import 'package:agentcore/agentcore.dart'
    show AgentNativeModelPhase, AgentPromptSuggestion;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/ai/typewriter_text.dart';
import '../../widgets/ai/agent_reasoning_panel.dart';
import '../../models/assistant_reasoning_metadata.dart';
import '../../widgets/ai/agent_markdown_text.dart';
import '../../widgets/ai/bill_card_widget.dart';
import '../../widgets/ai/agent_follow_up_questions.dart';
import '../../models/assistant_follow_up_metadata.dart';
import '../../models/assistant_execution_metadata.dart';
import '../../models/assistant_prompt_suggestions.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../services/billing/post_processor.dart';
import '../../providers.dart';
import '../../providers/ai_chat_providers.dart';
import '../../ai/core/bill_info.dart';
import '../../pages/transaction/transaction_editor_page.dart';
import '../../pages/ai/ai_settings_page.dart';
import '../../pages/ai/ai_provider_manage_page.dart';
import '../../pages/ai/agent_assistant_settings_page.dart';
import '../../pages/ai/agent_message_visibility.dart';
import '../../widgets/biz/ledger_selector_dialog.dart';
import '../../widgets/ai/agent_tool_authorization_dialog.dart';
import '../../widgets/ai/agent_chat_shell.dart';
import '../../widgets/ai/agent_execution_timeline.dart';
import '../../widgets/ai/agent_empty_conversation.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ui/avatar_service.dart';
import '../../services/system/logger_service.dart';
import '../../services/ai/ai_chat_service.dart';
import '../../services/ai/agent_app_facade.dart';
import '../../services/ai/bill_card_info_builder.dart';
import '../../agent/permission/agent_authorization_gate.dart';

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
  late final AIChatService _chatService;
  late final AgentConversationScrollCoordinator _chatScrollCoordinator =
      AgentConversationScrollCoordinator(_scrollController);
  int? _conversationId;
  bool _isLoading = false;
  int? _animatingMessageId; // 正在播放动画的消息ID
  String? _userAvatarPath; // 用户头像路径
  AIConfigValidationResult? _apiValidation; // API配置验证结果
  bool _showScrollToBottom = false; // 是否显示"回到底部"按钮
  bool _followLatest = true;
  bool _isUserScrolling = false;
  bool _isFirstLoad = true; // 是否首次加载
  bool _hasLiveAgentMessage = false;
  String _streamingAgentText = '';
  String _streamingReasoning = '';
  bool _reasoningRoundStarted = false;
  AgentNativeModelPhase? _agentModelPhase;
  List<AgentExecutionStep> _agentExecutionSteps = const [];
  AIResponse? _liveAgentResponse;
  int? _liveAssistantMessageId;
  int? _pendingResponseMessageId;
  String? _activeAgentRunId;
  bool _isAuthorizationDialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Cache this while [ref] is valid. Calling ref.read during dispose is
    // invalid because Riverpod may already have detached this element.
    _chatService = ref.read(aiChatServiceProvider);
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
    if (!mounted) return;

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
      if (!mounted) return;
      setState(() => _conversationId = id);
    }

    if (!mounted) return;
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

    final l10n = AppLocalizations.of(context);

    return AgentChatShell(
      title: l10n.aiChatTitle,
      backTooltip: l10n.commonBack,
      permissionsTooltip: l10n.agentAssistantSettingsTitle,
      clearTooltip: l10n.aiChatClearHistory,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenPermissions: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AgentAssistantSettingsPage(
            ledgerId: ref.read(currentLedgerIdProvider),
          ),
        ),
      ),
      onClearHistory: _showClearHistoryDialog,
      child: Column(
        children: [
          // API配置警告横幅
          if (_apiValidation != null && !_apiValidation!.isValid)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              padding: EdgeInsets.all(12.0.scaled(context, ref)),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
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
                    final displayMessages =
                        AgentMessageVisibility.forLiveResponse(
                      messages,
                      liveResponse: _liveAgentResponse,
                      persistedMessageId: _liveAssistantMessageId,
                    );
                    final pendingResponseId = _pendingResponseMessageId;
                    if (pendingResponseId != null &&
                        displayMessages.any(
                          (message) => message.id == pendingResponseId,
                        )) {
                      _pendingResponseMessageId = null;
                      _chatScrollCoordinator.onContentLaidOut(
                        targetReady: true,
                      );
                    }
                    // 首次加载完成且有消息时，自动滚动到底部
                    if (_isFirstLoad && displayMessages.isNotEmpty) {
                      _isFirstLoad = false;
                      _chatScrollCoordinator.requestInitialPositioning();
                    }

                    if (displayMessages.isEmpty && !_hasLiveAgentMessage) {
                      return const AgentEmptyConversation();
                    }

                    return NotificationListener<ScrollMetricsNotification>(
                      onNotification: (_) {
                        _chatScrollCoordinator.onScrollMetricsChanged();
                        return false;
                      },
                      child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.depth != 0) return false;
                            if (notification is ScrollStartNotification &&
                                notification.dragDetails != null) {
                              _isUserScrolling = true;
                              _followLatest = false;
                              _chatScrollCoordinator.onUserScroll();
                            }
                            if (notification is ScrollEndNotification &&
                                _isUserScrolling) {
                              _isUserScrolling = false;
                              _followLatest = _scrollController.hasClients &&
                                  _scrollController.position.extentAfter <= 50;
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: 18.0.scaled(context, ref),
                              vertical: 8.0.scaled(context, ref),
                            ),
                            itemCount: displayMessages.length +
                                (_hasLiveAgentMessage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == displayMessages.length) {
                                return _buildLiveAgentBubble();
                              }
                              final message = displayMessages[index];
                              final suggestions = !_isLoading &&
                                      !_hasLiveAgentMessage &&
                                      index == displayMessages.length - 1 &&
                                      message.role == 'assistant' &&
                                      AssistantFollowUpMetadata
                                          .allowsAnalysisTemplates(
                                              message.metadata) &&
                                      (message.messageType == 'text' ||
                                          message.messageType == 'bill_card')
                                  ? AssistantPromptSuggestions.sections(
                                      l10n,
                                      contextual:
                                          AssistantFollowUpMetadata.decode(
                                              message.metadata,
                                              ledgerId: ref.watch(
                                                  currentLedgerIdProvider)),
                                      recentPrompts: displayMessages
                                          .where((row) => row.role == 'user')
                                          .map((row) => row.content)
                                          .toList()
                                          .reversed
                                          .take(12),
                                    )
                                  : (
                                      questions: const <AgentPromptSuggestion>[],
                                      templates: const <AgentPromptSuggestion>[]
                                    );
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildMessageBubble(message),
                                  if (suggestions.questions.isNotEmpty ||
                                      suggestions.templates.isNotEmpty)
                                    Padding(
                                        padding: EdgeInsets.only(bottom: 12),
                                        child: AgentFollowUpQuestions(
                                          key: ValueKey(
                                              'follow-ups-${message.id}'),
                                          suggestions: suggestions.questions,
                                          templates: suggestions.templates,
                                          onSuggestionTap:
                                              _handlePromptSuggestion,
                                        )),
                                ],
                              );
                            },
                          )),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(
                    child: Text(l10n.aiChatMessagesLoadFailed(e.toString())),
                  ),
                ),

                // 回到底部按钮
                if (_showScrollToBottom)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16.0.scaled(context, ref),
                    child: Center(
                        child: AgentScrollToLatestButton(
                      key: const ValueKey('agent-scroll-to-latest'),
                      label: l10n.agentScrollToLatest,
                      onPressed: _scrollToBottomWithAnimation,
                    )),
                  ),
              ],
            ),
          ),

          // 输入区域
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    if (message.messageType == 'bill_card' && message.metadata != null) {
      final parsed = _parseBillMetadata(message);
      Widget cards;
      if (parsed.bills.length == 1) {
        final bill = parsed.bills.first;
        final txId = parsed.txIds.isNotEmpty ? parsed.txIds.first : null;
        final isUndone = txId != null && parsed.undoneIds.contains(txId);
        cards = GestureDetector(
          onLongPressStart: (details) =>
              _showBillCardMenu(details.globalPosition, message),
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
      } else {
        cards = _buildMultiBillBubble(message, parsed);
      }
      return AgentAnswerView(
          activity: _storedActivity(message),
          content:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AgentReasoningPanel(
                key: ValueKey('reasoning-${message.id}'),
                reasoning: AssistantReasoningMetadata.decode(message.metadata)),
            cards,
          ]));
    }

    if (message.role != 'user') {
      final responseAction = _responseActionFor(message);
      return AgentAnswerView(
        key: ValueKey('agent-answer-${message.id}'),
        activity: _storedActivity(message),
        content: GestureDetector(
          onLongPressStart: (details) =>
              _showTextMessageMenu(details.globalPosition, message, false),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AgentReasoningPanel(
                key: ValueKey('reasoning-${message.id}'),
                reasoning: AssistantReasoningMetadata.decode(message.metadata)),
            _answerText(message.content),
            if (responseAction != null) _buildResponseAction(responseAction),
          ]),
        ),
        actions: _answerActions(message.content, message: message),
      );
    }

    // User requests retain their right-aligned bubble; assistant answers do not.
    return Padding(
      padding: EdgeInsets.only(
          top: 8.0.scaled(context, ref), bottom: 16.0.scaled(context, ref)),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
                child: GestureDetector(
              onLongPressStart: (details) =>
                  _showTextMessageMenu(details.globalPosition, message, true),
              child: Container(
                margin: EdgeInsets.only(left: 60.0.scaled(context, ref)),
                padding: EdgeInsets.symmetric(
                    horizontal: 12.0.scaled(context, ref),
                    vertical: 10.0.scaled(context, ref)),
                decoration: BoxDecoration(
                  color: ref.watch(primaryColorProvider).withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(12.0.scaled(context, ref)),
                  border: Border.all(
                      color: ref
                          .watch(primaryColorProvider)
                          .withValues(alpha: 0.3)),
                ),
                child: TypewriterText(
                    text: message.content,
                    animate: message.id == _animatingMessageId,
                    style: TextStyle(
                        color: BeeTokens.textPrimary(context),
                        fontSize: 14.0.scaled(context, ref),
                        height: 1.5)),
              ),
            )),
            if (_userAvatarPath != null) ...[
              SizedBox(width: 8.0.scaled(context, ref)),
              _buildUserAvatar(),
            ],
          ]),
    );
  }

  Widget _answerText(String text) => AgentMarkdownText(
        data: text,
        style: TextStyle(
            color: BeeTokens.textPrimary(context),
            fontSize: 14.0.scaled(context, ref),
            height: 1.6),
      );

  Widget? _storedActivity(Message message) {
    final steps = AssistantExecutionMetadata.decode(message.metadata);
    if (steps.isEmpty) return null;
    return AgentExecutionTimeline(
      key: ValueKey('execution-${message.id}'),
      steps: const [],
      displaySteps: steps,
      isStreaming: false,
    );
  }

  Widget _answerActions(String text, {Message? message}) {
    final l10n = AppLocalizations.of(context);
    final color = BeeTokens.textTertiary(context);
    return Row(children: [
      IconButton(
        key: message == null
            ? null
            : ValueKey('agent-answer-copy-${message.id}'),
        tooltip: l10n.aiChatCopy,
        icon: Icon(Icons.copy_rounded, size: 16, color: color),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: text));
          showToast(context, l10n.aiChatCopied);
        },
      ),
      if (message != null)
        Builder(
            builder: (buttonContext) => IconButton(
                  key: ValueKey('agent-answer-more-${message.id}'),
                  tooltip: l10n.commonMore,
                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: color),
                  onPressed: () {
                    final box = buttonContext.findRenderObject() as RenderBox;
                    _showTextMessageMenu(
                        box.localToGlobal(Offset(box.size.width, 0)),
                        message,
                        false);
                  },
                )),
    ]);
  }

  Widget _buildLiveAgentBubble() {
    final response = _liveAgentResponse;
    if (response != null) return _buildLiveAgentResponse(response);
    return AgentAnswerView(
      key: const ValueKey('agent-live-answer'),
      content:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AgentReasoningPanel(
            key: ValueKey('reasoning-live-$_activeAgentRunId'),
            reasoning: _streamingReasoning),
        AgentExecutionTimeline(
          key: ValueKey('execution-live-$_activeAgentRunId'),
          steps: _agentExecutionSteps,
          isStreaming: _isLoading,
          streamingText: _streamingAgentText,
          modelPhase: _agentModelPhase,
        ),
      ]),
    );
  }

  /// The completed answer retains the same full-width list slot while the
  /// database row and bill post-processing finish; no replayed typewriter.
  Widget _buildLiveAgentResponse(AIResponse response) {
    final activity = _agentExecutionSteps.isEmpty
        ? null
        : AgentExecutionTimeline(
            steps: _agentExecutionSteps,
            isStreaming: false,
          );
    if (response.type == 'bill_card' && response.bills.isNotEmpty) {
      return AgentAnswerView(
          activity: activity,
          content:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AgentReasoningPanel(
                key: ValueKey('reasoning-complete-$_activeAgentRunId'),
                reasoning: _streamingReasoning),
            for (var index = 0; index < response.bills.length; index++)
              BillCardWidget(
                billInfo: response.bills[index],
                transactionId: index < response.transactionIds.length
                    ? response.transactionIds[index]
                    : null,
              ),
          ]));
    }
    return AgentAnswerView(
      activity: activity,
      content:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AgentReasoningPanel(
            key: ValueKey('reasoning-complete-$_activeAgentRunId'),
            reasoning: _streamingReasoning),
        _answerText(response.text),
        if (response.action != null) _buildResponseAction(response.action!),
      ]),
      actions: _answerActions(response.text),
    );
  }

  AIResponseAction? _responseActionFor(Message message) {
    final metadata = message.metadata;
    if (metadata == null || metadata.isEmpty) return null;
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map) return null;
      final action = decoded['action'];
      for (final candidate in AIResponseAction.values) {
        if (candidate.name == action) return candidate;
      }
      return null;
    } on Object {
      return null;
    }
  }

  Widget _buildResponseAction(AIResponseAction action) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton.icon(
        onPressed: switch (action) {
          AIResponseAction.openProviderSettings => _openProviderSettings,
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.settings_outlined, size: 16),
        label: Text(AppLocalizations.of(context).aiProviderManageTitle),
      ),
    );
  }

  void _openProviderSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AIProviderManagePage()),
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
                _isLoading ? Icons.stop_circle_outlined : Icons.send,
                color: _isLoading
                    ? Theme.of(context).colorScheme.error
                    : ref.watch(primaryColorProvider),
              ),
              tooltip:
                  _isLoading ? AppLocalizations.of(context).agentRunStop : null,
              onPressed: _isLoading ? _stopCurrentAgentRun : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  void _stopCurrentAgentRun() {
    final runId = _activeAgentRunId;
    if (!_isLoading || runId == null) return;
    _chatService.cancelAgentRun(runId);
    if (_isAuthorizationDialogOpen && mounted) {
      Navigator.of(context).pop(AgentToolAuthorizationChoice.deny);
    }
  }

  /// Recommended questions use exactly the same visible/persisted text and
  /// Agent execution path as a manually typed question.
  Future<void> _handlePromptSuggestion(AgentPromptSuggestion suggestion) =>
      _sendMessageText(suggestion.prompt, readOnly: true);

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (!mounted || text.isEmpty || _isLoading) return;

    _inputController.clear();
    await _sendMessageText(text);
  }

  /// 发送消息文本
  ///
  /// [text] is both the visible user message and the Agent's current request.
  Future<void> _sendMessageText(String text, {bool readOnly = false}) async {
    if (!mounted || text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _followLatest = true;
      _isUserScrolling = false;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      // Persist the actual request, including period and scope, for follow-ups.
      await repo.createMessage(
        MessagesCompanion.insert(
          conversationId: _conversationId!,
          role: 'user',
          content: text,
          messageType: 'text',
          metadata: Value(jsonEncode({'contextLedgerId': ledgerId})),
          createdAt: Value(DateTime.now()),
        ),
      );
      if (!mounted) return;

      _scrollToBottom();

      // chat_service 内部走 BillExtractionService.forLedger,会自动查
      // 当前账本可用分类 + 同币种账户,page 层不再预查。
      final chatService = _chatService;
      final currentLocale = Localizations.localeOf(context);
      final l10n = AppLocalizations.of(context);
      final agentRunId = const Uuid().v4();

      logger.info('AIChat', '当前账本ID: $ledgerId');

      setState(() {
        _hasLiveAgentMessage = true;
        _streamingAgentText = '';
        _streamingReasoning = '';
        _reasoningRoundStarted = false;
        _agentModelPhase = null;
        _agentExecutionSteps = const [];
        _liveAgentResponse = null;
        _liveAssistantMessageId = null;
        _activeAgentRunId = agentRunId;
      });
      _scrollToBottom();

      AIResponse? response;
      await for (final event in chatService.processMessageEvents(
        text,
        ledgerId: ledgerId,
        runId: agentRunId,
        conversationId: _conversationId,
        languageCode: currentLocale.languageCode,
        l10n: l10n,
        readOnly: readOnly,
      )) {
        if (!mounted) break;
        switch (event) {
          case AgentModelActivityEvent(:final phase):
            setState(() {
              _agentModelPhase = phase;
              if (phase == AgentNativeModelPhase.awaitingResponse) {
                _reasoningRoundStarted = false;
              }
            });
          case AgentReasoningDeltaEvent(:final text):
            setState(() {
              if (!_reasoningRoundStarted && _streamingReasoning.isNotEmpty) {
                _streamingReasoning += '\n\n';
              }
              _reasoningRoundStarted = true;
              _streamingReasoning += text;
            });
          case AgentTextDeltaEvent(:final text):
            setState(() {
              _streamingAgentText += text;
              _agentModelPhase = AgentNativeModelPhase.generating;
            });
          case AgentToolAuthorizationRequestedEvent(:final request):
            setState(() {
              _agentModelPhase = null;
              _agentExecutionSteps = [
                ..._agentExecutionSteps,
                AgentExecutionStep(
                  toolName: request.toolName,
                  arguments: request.arguments,
                  status: AgentExecutionStepStatus.waiting,
                ),
              ];
            });
            _isAuthorizationDialogOpen = true;
            final choice = mounted
                ? await AgentToolAuthorizationDialog.show(
                    context: context,
                    request: request,
                  )
                : AgentToolAuthorizationChoice.deny;
            _isAuthorizationDialogOpen = false;
            chatService.resolveToolAuthorization(
              request.authorizationId,
              choice,
            );
          case AgentToolStartedEvent(
              :final toolName,
              :final callId,
              :final arguments
            ):
            setState(() {
              _agentModelPhase = null;
              _agentExecutionSteps = _updateExecutionStep(
                toolName: toolName,
                callId: callId,
                arguments: arguments,
                status: AgentExecutionStepStatus.running,
              );
            });
          case AgentToolCompletedEvent(
              :final toolName,
              :final callId,
              :final arguments,
              :final result,
              :final error,
              :final succeeded
            ):
            setState(() {
              _agentExecutionSteps = _updateExecutionStep(
                toolName: toolName,
                callId: callId,
                arguments: arguments,
                status: succeeded
                    ? AgentExecutionStepStatus.completed
                    : AgentExecutionStepStatus.failed,
                result: result,
                error: error,
              );
            });
          case AgentRunCompletedEvent(:final result):
            response = result.response;
        }
        _scrollToBottomSmooth();
      }
      // The authorization dialog and native SSE stream can outlive this
      // route. Do not persist or update UI after the page has been disposed.
      if (!mounted) return;
      response ??= AIResponse.error(l10n.agentRunFailed);
      setState(() {
        _liveAgentResponse = response;
      });

      // 保存 AI 回复。多笔 metadata 用新格式 {bills, txIds, undoneIds};
      // transactionId 列仍存第一笔 id(getMessageByTransactionId 兼容)。
      final assistantMessageId = await repo.createMessage(
        MessagesCompanion.insert(
          conversationId: _conversationId!,
          role: 'assistant',
          content: response.text,
          messageType: response.type,
          metadata: _responseMetadata(response, ledgerId),
          transactionId: response.transactionId != null
              ? Value(response.transactionId)
              : const Value.absent(),
          createdAt: Value(DateTime.now()),
        ),
      );
      if (!mounted) return;
      setState(() {
        _liveAssistantMessageId = assistantMessageId;
        _pendingResponseMessageId = _followLatest ? assistantMessageId : null;
        if (_followLatest) _chatScrollCoordinator.request();
      });

      // 如果是记账成功，刷新统计信息
      if (response.type == 'bill_card' && response.transactionId != null) {
        // 刷新全局统计信息
        ref.read(statsRefreshProvider.notifier).state++;

        // 触发云同步
        final billLedgerId = response.billInfo?.ledgerId ?? ledgerId;
        await PostProcessor.sync(ref, ledgerId: billLedgerId);

        if (!mounted) return;

        logger.info('AIChat', '记账成功，已刷新统计信息和触发云同步');
      }

      if (!mounted) return;
      setState(() {
        // Content was already rendered from the provider's real SSE chunks.
        // Do not replay it with the old typewriter simulation after persistence.
        _animatingMessageId = null;
        _hasLiveAgentMessage = false;
        _streamingAgentText = '';
        _streamingReasoning = '';
        _reasoningRoundStarted = false;
        _agentModelPhase = null;
        _agentExecutionSteps = const [];
        _liveAgentResponse = null;
        _liveAssistantMessageId = null;
      });
    } catch (e) {
      if (mounted) {
        showToast(
            context, '${AppLocalizations.of(context).aiChatSendFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLiveAgentMessage = false;
          _streamingAgentText = '';
          _streamingReasoning = '';
          _reasoningRoundStarted = false;
          _agentModelPhase = null;
          _agentExecutionSteps = const [];
          _liveAgentResponse = null;
          _liveAssistantMessageId = null;
          _activeAgentRunId = null;
          _isAuthorizationDialogOpen = false;
        });
      }
    }
  }

  Value<String?> _responseMetadata(AIResponse response, int ledgerId) {
    final metadata = <String, Object?>{
      'contextLedgerId': ledgerId,
      'analysisTemplatesAllowed': response.allowPromptSuggestions,
    };
    metadata.addAll(AssistantReasoningMetadata.encode(_streamingReasoning));
    metadata.addAll(AssistantExecutionMetadata.encode(
      AgentExecutionTimeline.projectSteps(
          AppLocalizations.of(context), _agentExecutionSteps,
          finished: true),
    ));
    if (response.bills.isNotEmpty) {
      metadata.addAll(Map<String, Object?>.from(jsonDecode(_encodeBillMetadata(
          response.bills, response.transactionIds, const <int>{})) as Map));
    }
    if (response.action != null) metadata['action'] = response.action!.name;
    if (response.followUpSuggestions.isNotEmpty) {
      metadata.addAll(AssistantFollowUpMetadata.encode(
          response.followUpSuggestions,
          ledgerId: ledgerId));
    }
    return metadata.isEmpty
        ? const Value.absent()
        : Value(jsonEncode(metadata));
  }

  List<AgentExecutionStep> _updateExecutionStep({
    required String toolName,
    required String callId,
    required Map<String, Object?> arguments,
    required AgentExecutionStepStatus status,
    Map<String, Object?>? result,
    String? error,
  }) {
    final steps = [..._agentExecutionSteps];
    var index = -1;
    if (callId.isNotEmpty) {
      for (var i = steps.length - 1; i >= 0; i--) {
        if (steps[i].callId == callId) {
          index = i;
          break;
        }
      }
    }
    if (index < 0) {
      for (var i = steps.length - 1; i >= 0; i--) {
        final candidate = steps[i];
        if (candidate.toolName == toolName &&
            (candidate.status == AgentExecutionStepStatus.waiting ||
                candidate.status == AgentExecutionStepStatus.running)) {
          index = i;
          break;
        }
      }
    }

    final current = index >= 0 ? steps[index] : null;
    final next = AgentExecutionStep(
      toolName: toolName,
      arguments:
          arguments.isEmpty ? (current?.arguments ?? arguments) : arguments,
      callId: callId.isEmpty ? current?.callId : callId,
      status: status,
      result: result,
      error: error,
    );
    if (index >= 0) {
      steps[index] = next;
    } else {
      steps.add(next);
    }
    return steps;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && mounted && _followLatest) {
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
    _followLatest = true;
    _isUserScrolling = false;
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
    if (!_followLatest) return;
    // 使用 postFrameCallback 确保在布局完成后滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted && _followLatest) {
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
      if (mounted) {
        showToast(context, AppLocalizations.of(context).aiChatUndone);
      }
      return;
    }

    final parsed = _parseBillMetadata(message);
    final newUndone = {...parsed.undoneIds, transactionId};
    await repo.updateMessage(message.copyWith(
      metadata: Value(_encodeBillMetadata(
        parsed.bills,
        parsed.txIds,
        newUndone,
        existingMetadata: message.metadata,
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

      final category = transaction.categoryId == null
          ? null
          : await repo.getCategoryById(transaction.categoryId!);
      final account = transaction.accountId == null
          ? null
          : await repo.getAccount(transaction.accountId!);
      final toAccount = transaction.toAccountId == null
          ? null
          : await repo.getAccount(transaction.toAccountId!);
      final tagsByTransaction = await repo.getTagsForTransactions([
        transactionId,
      ]);
      final updatedBillInfo = buildBillCardInfoFromTransaction(
        amount: transaction.amount,
        time: transaction.happenedAt,
        note: transaction.note,
        category: category?.name,
        transactionType: transaction.type,
        account: account?.name,
        fromAccount: account?.name,
        toAccount: toAccount?.name,
        tags: tagsByTransaction[transactionId]?.map((tag) => tag.name).toList(),
        currency: transaction.currencyCode ?? account?.currency,
        ledgerId: transaction.ledgerId,
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
          existingMetadata: message.metadata,
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
          newBills[idx] =
              parsed.bills[idx].copyWith(ledgerId: selectedLedgerId);
          await repo.updateMessage(message.copyWith(
            metadata: Value(_encodeBillMetadata(
              newBills,
              parsed.txIds,
              parsed.undoneIds,
              existingMetadata: message.metadata,
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
      final txIds =
          ((raw['txIds'] as List?) ?? const []).whereType<int>().toList();
      final undoneIds =
          ((raw['undoneIds'] as List?) ?? const []).whereType<int>().toSet();
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
    Set<int> undoneIds, {
    String? existingMetadata,
  }) {
    return jsonEncode({
      if (existingMetadata != null)
        ...jsonDecode(existingMetadata) as Map<String, dynamic>,
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
    final runId = _activeAgentRunId;
    if (runId != null) _chatService.cancelAgentRun(runId);
    _inputController.dispose();
    _chatScrollCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
