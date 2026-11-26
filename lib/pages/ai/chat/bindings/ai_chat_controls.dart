import '../widgets/ledger_evidence_sheet.dart';
import '../widgets/ledger_evidence_label.dart';
import '../widgets/agent_financial_answer.dart';
import '../widgets/agent_answer_header.dart';
import '../widgets/agent_write_confirmation.dart';
import '../../../../agent/model/ledger_query_replay.dart';
import '../../../../agent/policy/p0_agent_policy.dart';
import '../../../../services/ai/chat_session_store.dart';
import '../../../../utils/format_utils.dart';
import 'package:beecount/services/ai/chat_receipt_store.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';
import 'dart:convert';

import 'package:agentcore/agentcore.dart'
    show AgentNativeModelPhase, AgentPromptSuggestion;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import 'package:beecount/pages/ai/chat/widgets/agent_markdown_text.dart';
import 'package:beecount/pages/ai/chat/widgets/bill_card_widget.dart';
import 'package:beecount/pages/ai/chat/bindings/agent_follow_up_questions.dart';
import 'package:beecount/models/assistant_follow_up_metadata.dart';
import 'package:beecount/models/assistant_execution_metadata.dart';
import 'package:beecount/models/assistant_prompt_suggestions.dart';
import 'package:beecount/styles/tokens.dart';
import 'package:beecount/services/billing/post_processor.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/utils/transaction_edit_utils.dart';
import 'package:beecount/pages/ai/ai_settings_page.dart';
import 'package:beecount/pages/ai/ai_provider_manage_page.dart';
import 'package:beecount/pages/ai/agent_assistant_settings_page.dart';
import 'package:beecount/pages/ai/agent_message_visibility.dart';
import 'package:beecount/pages/transaction/transaction_move.dart';
import 'package:beecount/pages/ai/bindings/agent_tool_authorization_dialog.dart';
import 'package:beecount/pages/ai/chat/widgets/agent_chat_shell.dart';
import 'package:beecount/pages/ai/chat/bindings/agent_execution_timeline.dart';
import 'package:beecount/pages/ai/chat/widgets/agent_empty_conversation.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/ai/bill_card_info_builder.dart';
import 'package:beecount/agent/permission/agent_authorization_gate.dart';

/// AI 对话页面
class AIChatControls extends ConsumerStatefulWidget {
  const AIChatControls({super.key, this.view = const {}});
  final Map<String, Object?> view;

  @override
  ConsumerState<AIChatControls> createState() => _AIChatControlsState();
}

class _AIChatControlsState extends ConsumerState<AIChatControls>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AIChatService _chatService;
  late final AgentConversationScrollCoordinator _chatScrollCoordinator =
      AgentConversationScrollCoordinator(_scrollController);
  int? _conversationId;
  bool _isLoading = false;
  final FocusNode _inputFocus = FocusNode();
  final _drafts = <int, TextEditingValue>{};
  // A streaming delta rebuilds visible turns. Parse large frozen evidence only
  // once per message revision, with a bounded cache for long conversations.
  final _presentations = <int, _SavedTurn>{};
  _SavedTurn _saved(Message message) {
    final existing = _presentations[message.id];
    if (existing != null && existing.metadata == message.metadata) {
      return existing;
    }
    if (_presentations.length >= 32) {
      _presentations.remove(_presentations.keys.first);
    }
    return _presentations[message.id] =
        _SavedTurn(message.metadata, ref.read(currentLedgerIdProvider));
  }

  bool _switching = false;
  late final ChatSessionStore _sessions;
  AgentToolAuthorizationRequest? _pendingWrite;
  bool _stopRequested = false;
  bool _declinedWrite = false;
  String _sourceText = '';
  bool _showScrollToBottom = false; // 是否显示"回到底部"按钮
  bool _followLatest = true;
  bool _isUserScrolling = false;
  bool _isFirstLoad = true; // 是否首次加载
  bool _hasLiveAgentMessage = false;
  String _streamingAgentText = '';
  AgentNativeModelPhase? _agentModelPhase;
  List<AgentExecutionStep> _agentExecutionSteps = const [];
  AgentFinancialPresentation? _livePresentation;
  Map<String, Object?> _liveQueryContext = const {};
  int? _liveSourceId;
  int? _continuingMessageId;
  int? _queryAnchorSource;
  bool _liveCardPositioned = false;
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
    _sessions = ChatSessionStore(ref.read(databaseProvider));
    _initConversation();
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
      ref.invalidate(aiChatTextModelConfiguredProvider);
    }
  }

  Future<void> _initConversation() async {
    final id = await _sessions.open(ref.read(currentLedgerIdProvider));
    if (mounted) _displaySession(id);
  }

  void _displaySession(int id) {
    if (_conversationId == id) return;
    if (_conversationId case final int old) {
      _drafts[old] = _inputController.value;
    }
    _inputController.value = _drafts[id] ?? TextEditingValue.empty;
    _chatScrollCoordinator.onUserScroll();
    _presentations.clear();
    setState(() {
      _conversationId = id;
      _queryAnchorSource = null;
      _isFirstLoad = true;
      _followLatest = true;
      _showScrollToBottom = false;
      _pendingResponseMessageId = null;
    });
    ref.read(currentConversationIdProvider.notifier).state = id;
  }

  Future<void> _configureModel() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AISettingsPage()));
    if (!mounted) return;
    ref.invalidate(aiChatTextModelConfiguredProvider);
  }

  void _draftEntry() {
    if (_isLoading) return;
    if (_inputController.text.trim().isEmpty) {
      final text = AppLocalizations.of(context).aiChatStartRecordDraft;
      _inputController.value = TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: text.length));
    }
    _inputFocus.requestFocus();
  }

  Future<void> _conversationMenu() async {
    final l = AppLocalizations.of(context);
    final ledger = ref.read(currentLedgerIdProvider);
    final busy = _isLoading || _switching;
    final selected = await showBeeSheet<String>(context,
        title: l.aiChatNavigation,
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!busy)
            _menuRow('new', l.aiChatNew, 'MessageSquare', 'agent-chat-new'),
          if (!busy)
            _menuRow(
                'history', l.aiChatHistory, 'History', 'agent-chat-history'),
          _menuRow('permissions', l.aiChatPermissionsDepth, 'SlidersHorizontal',
              'agent-chat-permissions'),
          if (!busy)
            _menuRow(
                'clear', l.aiChatClearCurrent, 'Trash2', 'agent-chat-clear',
                danger: true),
        ])));
    if (!mounted ||
        selected == null ||
        ledger != ref.read(currentLedgerIdProvider)) {
      return;
    }
    if (selected == 'permissions') {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AgentAssistantSettingsPage(ledgerId: ledger)));
      return;
    }
    if (_isLoading || _switching) return;
    if (selected == 'clear') {
      await _showClearHistoryDialog();
      return;
    }
    setState(() => _switching = true);
    try {
      if (selected == 'new') {
        final id = await _sessions.start(ledger, _conversationId!);
        if (mounted) _displaySession(id);
      } else if (selected == 'history') {
        final rows = await _sessions.history(ledger);
        if (!mounted) return;
        final hidden = ref.read(hideAmountsProvider);
        final id = await showBeeSheet<int>(context,
            title: l.aiChatHistory,
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.aiChatNoHistory))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return BeeMenuRow(
                          leading: const BeeLineIcon('MessageSquare', size: 19),
                          title: hidden ? l.aiChatHiddenMessage : row.title,
                          subtitle: MaterialLocalizations.of(context)
                              .formatMediumDate(row.updated),
                          selected: _conversationId == row.id,
                          onTap: () => Navigator.pop(context, row.id));
                    }));
        if (!mounted || id == null) return;
        final selected = await _sessions.select(ledger, id);
        if (selected && mounted) _displaySession(id);
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Widget _menuRow(String value, String label, String icon, String key,
          {bool danger = false}) =>
      Builder(
          builder: (ctx) => BeeMenuRow(
              key: ValueKey(key),
              title: label,
              danger: danger,
              leading: BeeLineIcon(icon, size: 19),
              onTap: () => Navigator.pop(ctx, value)));

  @override
  Widget build(BuildContext context) {
    if (_conversationId == null) {
      return V4PageScaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(_conversationId!));
    final configured = ref.watch(aiChatTextModelConfiguredProvider).valueOrNull;

    final l10n = AppLocalizations.of(context);

    final name = ref.watch(currentLedgerProvider).valueOrNull?.name;
    return AgentChatShell(
      title: l10n.aiChatAssistantName,
      backTooltip: l10n.commonBack,
      ledgerName: name == null ? null : translateLedgerName(context, name),
      moreLabel: l10n.aiChatNavigation,
      onBack: () => Navigator.of(context).maybePop(),
      onMore: _conversationMenu,
      child: Column(
        children: [
          // API配置警告横幅
          if (configured == false &&
              messagesAsync.valueOrNull?.isNotEmpty == true)
            BeeConversationNotice(
                label: l10n.aiChatConfigWarning,
                actionLabel: l10n.aiChatGoToSettings,
                onAction: _configureModel),

          // 消息列表
          Expanded(
            child: Stack(
              children: [
                messagesAsync.when(
                  data: (messages) {
                    final displayMessages =
                        AgentMessageVisibility.forLiveResponse(
                      messages,
                      liveResponse: _continuingMessageId == null
                          ? _liveAgentResponse
                          : null,
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
                      if (_queryAnchorSource == null) {
                        _chatScrollCoordinator.requestInitialPositioning();
                      }
                    }

                    if (displayMessages.isEmpty && !_hasLiveAgentMessage) {
                      return AgentEmptyConversation(
                          view: widget.view,
                          onPrompt: _sendMessageText,
                          onConfigureModel: _configureModel,
                          onRecord: _draftEntry);
                    }

                    return NotificationListener<ScrollMetricsNotification>(
                      onNotification: (notification) {
                        _chatScrollCoordinator.onScrollMetricsChanged();
                        if (notification.depth == 0 && !_followLatest) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _handleScroll();
                          });
                        }
                        return false;
                      },
                      child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.depth != 0) return false;
                            if (notification is ScrollStartNotification &&
                                notification.dragDetails != null) {
                              _isUserScrolling = true;
                              _queryAnchorSource = null;
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
                            key: ValueKey('conversation-$_conversationId'),
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 8,
                            ),
                            itemCount: displayMessages.length +
                                (_hasLiveAgentMessage &&
                                        _continuingMessageId == null
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              if (index == displayMessages.length) {
                                return _buildLiveAgentBubble();
                              }
                              final message = displayMessages[index];
                              if (_hasLiveAgentMessage &&
                                  message.id == _continuingMessageId) {
                                return _buildLiveAgentBubble();
                              }
                              final queries = message.role == 'assistant'
                                  ? _saved(message).queries
                                  : const <Map<String, Object?>>[];
                              final suggestions = !_isLoading &&
                                      !_hasLiveAgentMessage &&
                                      index == displayMessages.length - 1 &&
                                      message.role == 'assistant' &&
                                      _saved(message).allowsSuggestions &&
                                      (message.messageType == 'text' ||
                                          message.messageType == 'bill_card')
                                  ? AssistantPromptSuggestions.sections(
                                      l10n,
                                      contextual: _saved(message).suggestions,
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
                                  _buildMessageBubble(message,
                                      queries: queries,
                                      source: _originalRequest(
                                          displayMessages, index)),
                                  if (suggestions.questions.isNotEmpty ||
                                      suggestions.templates.isNotEmpty)
                                    Padding(
                                        padding: EdgeInsets.only(bottom: 12),
                                        child: AgentFollowUpQuestions(
                                          key: ValueKey(
                                              'follow-ups-${message.id}'),
                                          compact: true,
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
                    bottom: 16,
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

          _buildInputArea(),
        ],
      ),
    );
  }

  Message? _originalRequest(List<Message> messages, int index) {
    final reply = messages[index];
    if (reply.role != 'assistant') return null;
    final metadata = _saved(reply).data;
    final id = metadata['sourceMessageId'] ?? metadata['receiptSourceId'];
    for (var i = index - 1; i >= 0; i--) {
      if (messages[i].role == 'user' && (id == null || id == messages[i].id)) {
        return messages[i];
      }
    }
    return null;
  }

  static Map _readMetadata(String? metadata) {
    try {
      final data = jsonDecode(metadata ?? '{}');
      return data is Map ? data : const {};
    } on FormatException {
      return const {};
    }
  }

  Widget _buildMessageBubble(
    Message message, {
    required List<Map<String, Object?>> queries,
    required Message? source,
  }) {
    final l = AppLocalizations.of(context);
    final ledger = ref.watch(currentLedgerIdProvider);
    final hidden = ref.watch(hideAmountsProvider);
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
            compact: true,
            expectedLedgerId: ref.read(currentLedgerIdProvider),
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
                ? () => _handleChangeLedger(txId)
                : null,
          ),
        );
      } else {
        cards = _buildMultiBillBubble(message, parsed);
      }
      final note = (jsonDecode(message.metadata!) as Map)['supplementalText'];
      return _answerView(
          activity: _answerHeader(message, source, queries),
          content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cards,
                if (note is String && note.isNotEmpty) _answerText(note)
              ]));
    }

    if (message.role != 'user') {
      final responseAction = AIResponseAction.values
          .where((v) => v.name == _saved(message).data['action'])
          .firstOrNull;
      final data = _saved(message).data;
      final status = data['replyStatus'];
      final interrupted = message.messageType == 'error' || status == 'stopped';
      final presentation = _saved(message).presentation;
      final retained = interrupted && presentation?.hasDeclaredMetric == true;
      final failedRead = data['queryReadFailed'] == true;
      return _answerView(
        key: ValueKey('agent-answer-${message.id}'),
        activity: _answerHeader(message, source, queries),
        content:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (retained) _financialCard(presentation!, sourceId: source?.id),
          if (interrupted &&
              !retained &&
              !failedRead &&
              data['partialText'] is String)
            _answerText(data['partialText'] as String),
          if (interrupted)
            BeeSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      retained
                          ? l.agentQueryRetained
                          : status == 'stopped'
                              ? l.aiChatStopped
                              : failedRead
                                  ? l.agentQueryReadFailed
                                  : l.aiChatInterrupted,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  if (!retained &&
                      !(failedRead &&
                          message.content == l.agentQueryReadFailed))
                    _answerText(message.content),
                  if (source != null &&
                      !_isLoading &&
                      data['writeRequested'] != true)
                    TextButton.icon(
                        icon: const BeeLineIcon('RotateCcw', size: 16),
                        label: Text(retained
                            ? l.agentQueryResume
                            : failedRead
                                ? l.agentQueryRetry
                                : l.aiChatRetryAnswer),
                        onPressed: () => retained
                            ? _sendMessageText(source.content,
                                readOnly: true,
                                continuation: (reply: message, source: source))
                            : _repeat(message, source, queries)),
                ]))
          else if (presentation == null)
            GestureDetector(
                onLongPressStart: (details) => _showTextMessageMenu(
                    details.globalPosition, message, false),
                child: _answerText(message.content))
          else
            _financialContent(presentation, message.content,
                sourceId: source?.id,
                key: PageStorageKey('detail-${message.id}'),
                keepLead: data['writeRequested'] == true ||
                    data['continuedExplanation'] == true ||
                    _saved(message).queryContext['limit'] != null),
          if (presentation == null && !interrupted && queries.isNotEmpty)
            BeeMenuRow(
                title: l.agentEvidenceBills,
                leading: const BeeLineIcon('ReceiptText', size: 18),
                onTap: () => LedgerEvidenceSheet.show(context,
                    ledgerId: ledger, queries: queries)),
          if (responseAction != null) _buildResponseAction(responseAction),
        ]),
      );
    }

    return BeeConversationUserMessage(
        child: GestureDetector(
            onLongPressStart: (details) =>
                _showTextMessageMenu(details.globalPosition, message, true),
            child: Text(hidden ? l.aiChatHiddenMessage : message.content,
                style: TextStyle(
                    color: BeeTokens.textPrimary(context),
                    fontSize: 14,
                    height: 1.5))));
  }

  Widget _answerView({Key? key, required Widget content, Widget? activity}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AgentAnswerView(
              key: key,
              content: content,
              activity: activity ?? const AgentAnswerHeader()));

  Widget _answerText(String text) => AgentMarkdownText(
      data: ref.watch(hideAmountsProvider)
          ? AppLocalizations.of(context).aiChatHiddenMessage
          : text,
      style: TextStyle(
          color: BeeTokens.textPrimary(context), fontSize: 14, height: 1.6));

  Widget _financialCard(AgentFinancialPresentation presentation,
          {required int? sourceId, bool live = false}) =>
      Builder(builder: (anchor) {
        if (sourceId != null &&
            _queryAnchorSource == sourceId &&
            (!live || !_liveCardPositioned)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                !anchor.mounted ||
                !_scrollController.hasClients ||
                _queryAnchorSource != sourceId) {
              return;
            }
            final card = anchor.findRenderObject();
            if (card == null || !card.attached) return;
            final viewport = RenderAbstractViewport.maybeOf(card);
            if (viewport == null) return;
            final position = _scrollController.position;
            final top = viewport.getOffsetToReveal(card, 0).offset;
            final bottom = viewport.getOffsetToReveal(card, 1).offset;
            if (position.pixels > top || position.pixels < bottom) {
              position.jumpTo((top - 8)
                  .clamp(position.minScrollExtent, position.maxScrollExtent));
            }
            if (live) {
              _liveCardPositioned = true;
            } else {
              _queryAnchorSource = null;
            }
          });
        }
        return AgentFinancialAnswer(
            presentation: presentation,
            onEvidence: (scope) => LedgerEvidenceSheet.show(context,
                ledgerId: ref.read(currentLedgerIdProvider), queries: scope));
      });

  Widget _financialContent(AgentFinancialPresentation p, String text,
      {required Key key,
      required int? sourceId,
      bool live = false,
      bool keepLead = false}) {
    final paragraphs = text.trim().split(RegExp(r'\n\s*\n'));
    final showLead = paragraphs.first.isNotEmpty && (!p.isCompact || keepLead);
    final lead = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _answerText(paragraphs.first));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showLead && !p.hasDeclaredMetric) lead,
      _financialCard(p, sourceId: sourceId, live: live),
      if (showLead && p.hasDeclaredMetric) lead,
      if (paragraphs.length > 1 && !ref.watch(hideAmountsProvider))
        ExpansionTile(
            key: key,
            title: Text(AppLocalizations.of(context).aiChatReplyDetails),
            dense: true,
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _answerText(paragraphs.skip(1).join('\n\n')))
            ]),
    ]);
  }

  AgentActivityStep? _basis(AgentFinancialPresentation? p, Map queryContext) {
    if (p == null || !p.hasDeclaredMetric) return null;
    final l = AppLocalizations.of(context);
    if (ref.watch(hideAmountsProvider)) {
      return AgentActivityStep(
          title: l.agentQueryBasis, status: AgentActivityStatus.completed);
    }
    final book = queryContext['ledgerName'] ??
        ref.watch(currentLedgerProvider).valueOrNull?.name;
    return AgentActivityStep(
        title: p.countLabel(l),
        status: AgentActivityStatus.completed,
        details: [
          if (book is String)
            '${l.transactionReceiptLedger} · ${translateLedgerName(context, book)}',
          '${l.importFieldDate} · ${p.rangeLabel(context)}',
          [
            p.flowLabel(l),
            ...ledgerEvidenceFilterLabels(context, p.filters,
                accountsEnabled:
                    ref.watch(accountFeatureEnabledProvider).valueOrNull ??
                        true)
          ].join(' · '),
          p.filters['includeExcludedFromStats'] == true
              ? l.agentQueryStatsIncluded
              : l.agentQueryStatsExcluded,
        ]);
  }

  bool _basisExpanded(int? sourceId) =>
      sourceId != null &&
      PageStorage.maybeOf(context)
              ?.readState(context, identifier: 'query-basis-$sourceId') ==
          true;

  void _saveExpansion(int? sourceId, bool value) {
    if (sourceId != null) {
      PageStorage.maybeOf(context)
          ?.writeState(context, value, identifier: 'query-basis-$sourceId');
    }
  }

  Widget _answerHeader(
          Message m, Message? source, List<Map<String, Object?>> queries) =>
      AgentAnswerHeader(
          steps: _saved(m).steps,
          basis: _basis(_saved(m).presentation, _saved(m).queryContext),
          initiallyExpanded: _basisExpanded(source?.id),
          onExpansionChanged: (value) => _saveExpansion(source?.id, value),
          readQuery: queries.isNotEmpty,
          messageId: m.id,
          hideDetails: ref.watch(hideAmountsProvider),
          onMore: () => _answerMenu(m, source, queries));

  List<Map<String, Object?>> _replayFor(
      Message message, List<Map<String, Object?>> queries) {
    final context = _saved(message).data['queryContext'];
    if (context is! Map ||
        context['completeReplay'] != true ||
        context['displayRefs'] is! List ||
        (context['displayRefs'] as List).length != queries.length) {
      return const [];
    }
    return LedgerQueryReplay.definitions(
        queries, ref.read(currentLedgerIdProvider));
  }

  Future<void> _answerMenu(
      Message m, Message? source, List<Map<String, Object?>> queries) async {
    final l = AppLocalizations.of(context);
    final replay = _replayFor(m, queries);
    final canRepeat = !_isLoading &&
        !_switching &&
        source != null &&
        m.messageType != 'bill_card' &&
        _saved(m).data['writeRequested'] != true;
    final action = await showBeeSheet<String>(context,
        title: l.aiChatAnswerActions,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _menuRow(
              'copy', l.aiChatCopyAnswer, 'Copy', 'agent-answer-copy-${m.id}'),
          if (_saved(m).presentation?.isCompact == true &&
              m.messageType == 'text' &&
              !_saved(m).data.containsKey('replyStatus') &&
              !ref.read(hideAmountsProvider))
            _menuRow('text', l.aiChatReplyDetails, 'MessageSquare',
                'agent-answer-full-text'),
          if (canRepeat)
            _menuRow(
                'repeat',
                replay.isEmpty ? l.aiChatAskAgain : l.aiChatRepeatQuery,
                'RefreshCw',
                'agent-answer-repeat'),
        ]));
    if (!mounted) return;
    if (action == 'copy') {
      await _copyMessage(m);
    } else if (action == 'text') {
      await showBeeSheet<void>(context,
          title: l.aiChatReplyDetails,
          child: SingleChildScrollView(
              child: Consumer(
                  builder: (context, ref, _) => AgentMarkdownText(
                      data: ref.watch(hideAmountsProvider)
                          ? l.aiChatHiddenMessage
                          : m.content,
                      style: TextStyle(
                          color: BeeTokens.textPrimary(context),
                          fontSize: 14,
                          height: 1.6)))));
    } else if (action == 'repeat' && canRepeat) {
      await _repeat(m, source, queries);
    }
  }

  Future<void> _repeat(
      Message m, Message source, List<Map<String, Object?>> queries) async {
    if (_isLoading ||
        _switching ||
        m.conversationId != _conversationId ||
        source.conversationId != _conversationId) {
      return;
    }
    final data = _readMetadata(source.metadata);
    final ledger = ref.read(currentLedgerIdProvider);
    if (data['contextLedgerId'] != null && data['contextLedgerId'] != ledger) {
      return;
    }
    await _sendMessageText(source.content,
        readOnly: true,
        review: data['review'] == true,
        viewOverride: data['view'] is Map
            ? Map<String, Object?>.from(data['view'] as Map)
            : const {},
        repeatQueries: _replayFor(m, queries));
  }

  Future<void> _copyMessage(Message m) async {
    final l = AppLocalizations.of(context);
    String text = l.aiChatHiddenMessage;
    if (!ref.read(hideAmountsProvider)) {
      final card = m.role == 'assistant'
          ? AgentFinancialAnswer.copyText(context, _saved(m).queries,
              accountsEnabled:
                  ref.read(accountFeatureEnabledProvider).valueOrNull ?? true)
          : null;
      text = [m.content, if (card != null) card]
          .where((v) => v.isNotEmpty)
          .join('\n\n');
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showBeeToast(context, l.aiChatCopied, tone: BeeTone.success);
  }

  Widget _buildLiveAgentBubble() {
    if (_pendingWrite != null) {
      return _answerView(
          key: const ValueKey('agent-live-answer'),
          content: AgentWriteConfirmation(
              quote: ref.watch(hideAmountsProvider)
                  ? AppLocalizations.of(context).aiChatHiddenMessage
                  : _sourceText,
              onCancel: () => _resolveWrite(false),
              onConfirm: () => _resolveWrite(true)));
    }
    final response = _liveAgentResponse;
    if (response != null) return _buildLiveAgentResponse(response);
    final p = _livePresentation;
    final hasMetric = p?.hasDeclaredMetric == true;
    return _answerView(
      key: const ValueKey('agent-live-answer'),
      content:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AgentExecutionTimeline(
          key: ValueKey('execution-live-$_activeAgentRunId'),
          steps: _agentExecutionSteps,
          isStreaming: _isLoading,
          streamingText: hasMetric
              ? null
              : ref.watch(hideAmountsProvider) && _streamingAgentText.isNotEmpty
                  ? AppLocalizations.of(context).aiChatHiddenMessage
                  : _streamingAgentText,
          basis: _basis(p, _liveQueryContext),
          initiallyExpanded: _basisExpanded(_liveSourceId),
          onExpansionChanged: (value) => _saveExpansion(_liveSourceId, value),
          hideDetails: ref.watch(hideAmountsProvider),
          modelPhase: _agentModelPhase,
        ),
        if (hasMetric) _financialCard(p!, sourceId: _liveSourceId, live: true),
        if (hasMetric &&
            (!p!.isCompact || _continuingMessageId != null) &&
            _streamingAgentText.isNotEmpty)
          _answerText(_streamingAgentText),
      ]),
    );
  }

  /// The completed answer retains the same full-width list slot while the
  /// database row and bill post-processing finish; no replayed typewriter.
  Widget _buildLiveAgentResponse(AIResponse response) {
    final p = _livePresentation;
    final interrupted = response.wasStopped || response.type == 'error';
    final activity = AgentAnswerHeader(
        steps: AgentExecutionTimeline.projectSteps(
            AppLocalizations.of(context), _agentExecutionSteps,
            finished: true),
        basis: _basis(p, _liveQueryContext),
        initiallyExpanded: _basisExpanded(_liveSourceId),
        onExpansionChanged: (value) => _saveExpansion(_liveSourceId, value),
        hideDetails: ref.watch(hideAmountsProvider));
    if (response.type == 'bill_card' && response.bills.isNotEmpty) {
      return _answerView(
          activity: activity,
          content:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var index = 0; index < response.bills.length; index++)
              BillCardWidget(
                compact: true,
                expectedLedgerId: ref.read(currentLedgerIdProvider),
                billInfo: response.bills[index],
                transactionId: index < response.transactionIds.length
                    ? response.transactionIds[index]
                    : null,
              ),
            if (response.supplementalText case final String note)
              _answerText(note),
          ]));
    }
    return _answerView(
      activity: activity,
      content:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (p?.hasDeclaredMetric == true && interrupted) ...[
          _financialCard(p!, sourceId: _liveSourceId, live: true),
          Text(AppLocalizations.of(context).agentQueryRetained),
        ] else if (p != null && !interrupted)
          _financialContent(p, response.text,
              sourceId: _liveSourceId,
              live: true,
              key: ValueKey('live-detail-$_activeAgentRunId'),
              keepLead: _declinedWrite ||
                  _continuingMessageId != null ||
                  response.queryContext['limit'] != null)
        else
          _answerText(response.text),
        if (response.action != null) _buildResponseAction(response.action!),
      ]),
    );
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

  Widget _buildInputArea() {
    final l = AppLocalizations.of(context);
    final configured =
        ref.watch(aiChatTextModelConfiguredProvider).valueOrNull != false;
    return BeeConversationInput(
        controller: _inputController,
        focusNode: _inputFocus,
        hint: configured ? l.aiChatComposerHint : l.aiChatComposerUnconfigured,
        sendLabel: l.v4AIChatSend,
        stopLabel: l.agentRunStop,
        quickActionsLabel: l.aiChatStartQuickActions,
        onQuickActions: () => showAgentQuickActions(context,
            view: widget.view,
            onPrompt: _sendMessageText,
            onRecord: _draftEntry),
        busy: _isLoading,
        enabled: !_switching && configured,
        onSend: _sendMessage,
        onStop: _stopCurrentAgentRun);
  }

  void _resolveWrite(bool approved) {
    final pending = _pendingWrite;
    if (pending == null || !mounted) return;
    setState(() {
      _pendingWrite = null;
      _declinedWrite = !approved;
    });
    _chatService.resolveToolAuthorization(
        pending.authorizationId,
        approved &&
                !_stopRequested &&
                pending.runId == _activeAgentRunId &&
                pending.ledgerId == ref.read(currentLedgerIdProvider)
            ? AgentToolAuthorizationChoice.allowOnce
            : AgentToolAuthorizationChoice.deny);
  }

  void _stopCurrentAgentRun() {
    final runId = _activeAgentRunId;
    if (!_isLoading || runId == null) return;
    _stopRequested = true;
    if (_pendingWrite != null) _resolveWrite(false);
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

    if (_switching || !_inputController.value.composing.isCollapsed) return;
    _inputController.clear();
    await _sendMessageText(text);
  }

  /// 发送消息文本
  ///
  /// [text] is both the visible user message and the Agent's current request.
  Future<void> _sendMessageText(String text,
      {bool readOnly = false,
      bool review = false,
      Map<String, Object?>? viewOverride,
      ({Message reply, Message source})? continuation,
      List<Map<String, Object?>> repeatQueries = const []}) async {
    if (!mounted ||
        text.trim().isEmpty ||
        _isLoading ||
        _switching ||
        _conversationId == null) {
      return;
    }
    if (ref.read(aiChatTextModelConfiguredProvider).valueOrNull == false) {
      await _configureModel();
      return;
    }
    final conversationId = _conversationId!;
    final agentRunId = const Uuid().v4();
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (continuation != null &&
        (continuation.reply.conversationId != conversationId ||
            continuation.source.conversationId != conversationId ||
            _saved(continuation.reply).data['contextLedgerId'] != ledgerId)) {
      return;
    }
    final retained = continuation == null ? null : _saved(continuation.reply);
    final chosen = viewOverride ?? widget.view;
    final view =
        chosen['ledgerId'] == ledgerId ? chosen : const <String, Object?>{};
    _activeAgentRunId = agentRunId;
    _sourceText = text;
    _stopRequested = false;
    _declinedWrite = false;

    setState(() {
      _isLoading = true;
      _queryAnchorSource = null;
      _liveCardPositioned = false;
      _followLatest = continuation == null;
      _isUserScrolling = false;
    });

    try {
      final repo = ref.read(repositoryProvider);

      // Persist the actual request, including period and scope, for follow-ups.
      final sourceId = continuation?.source.id ??
          await repo.createMessage(
            MessagesCompanion.insert(
              conversationId: conversationId,
              role: 'user',
              content: text,
              messageType: 'text',
              metadata: Value(jsonEncode({
                'contextLedgerId': ledgerId,
                if (review) 'review': true,
                if (view.isNotEmpty) 'view': view
              })),
              createdAt: Value(DateTime.now()),
            ),
          );
      if (!mounted) return;

      if (continuation == null) _scrollToBottom();

      // chat_service 内部走 BillExtractionService.forLedger,会自动查
      // 当前账本可用分类 + 同币种账户,page 层不再预查。
      final chatService = _chatService;
      final currentLocale = Localizations.localeOf(context);
      final l10n = AppLocalizations.of(context);

      logger.info('AIChat', '当前账本ID: $ledgerId');

      setState(() {
        _hasLiveAgentMessage = true;
        _continuingMessageId = continuation?.reply.id;
        _liveSourceId = sourceId;
        _liveQueryContext = retained?.queryContext ?? const {};
        _livePresentation = retained?.presentation;
        _streamingAgentText = '';
        _agentModelPhase = null;
        _agentExecutionSteps = const [];
        _liveAgentResponse = null;
        _liveAssistantMessageId = null;
        _activeAgentRunId = agentRunId;
      });
      if (continuation == null) _scrollToBottom();

      AIResponse? response;
      await for (final event in chatService.processMessageEvents(
        text,
        ledgerId: ledgerId,
        runId: agentRunId,
        conversationId: conversationId,
        sourceMessageId: sourceId,
        view: view,
        review: review,
        repeatQueries: repeatQueries,
        continueQueryContext: retained?.queryContext,
        isCancelled: () => !mounted || _stopRequested,
        languageCode: currentLocale.languageCode,
        l10n: l10n,
        readOnly: readOnly,
      )) {
        if (!mounted) break;
        switch (event) {
          case AgentModelActivityEvent(:final phase):
            setState(() => _agentModelPhase = phase);
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
            if (_stopRequested ||
                request.ledgerId != ledgerId && request.ledgerId != null) {
              chatService.resolveToolAuthorization(
                  request.authorizationId, AgentToolAuthorizationChoice.deny);
              break;
            }
            if (request.toolName == 'record_transaction_from_text') {
              setState(() => _pendingWrite = request);
              break;
            }
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
              :final queryContext,
              :final error,
              :final succeeded
            ):
            setState(() {
              if (queryContext != null) {
                _setLiveEvidence(queryContext, ledgerId);
              }
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
      if (_declinedWrite && !_stopRequested && response.type != 'bill_card') {
        final read = _agentExecutionSteps.any((step) =>
            step.status == AgentExecutionStepStatus.completed &&
            step.toolName != 'record_transaction_from_text' &&
            step.result?['error'] == null);
        response = read
            ? AIResponse(
                type: response.type,
                text: '${l10n.aiChatWriteCancelled}\n\n${response.text}',
                queryContext: response.queryContext,
                action: response.action)
            : AIResponse.text(l10n.aiChatWriteCancelled);
      }
      setState(() {
        _liveAgentResponse = response;
        _setLiveEvidence(response!.queryContext, ledgerId);
        _liveAssistantMessageId = response.receiptMessageId;
      });

      // 保存 AI 回复。多笔 metadata 用新格式 {bills, txIds, undoneIds};
      // transactionId 列仍存第一笔 id(getMessageByTransactionId 兼容)。
      final reply = MessagesCompanion.insert(
        conversationId: conversationId,
        role: 'assistant',
        content: response.text,
        messageType: response.type,
        metadata:
            _responseMetadata(response, ledgerId, sourceId, retained: retained),
        transactionId: response.transactionId != null
            ? Value(response.transactionId)
            : const Value.absent(),
        createdAt: Value(DateTime.now()),
      );
      final int assistantMessageId;
      if (continuation != null) {
        final saved = await repo.getMessageById(continuation.reply.id);
        if (saved == null ||
            saved.metadata != continuation.reply.metadata ||
            saved.content != continuation.reply.content) {
          return;
        }
        await repo.updateMessage(saved.copyWith(
            content: response.text,
            messageType: response.type,
            metadata: reply.metadata));
        assistantMessageId = saved.id;
      } else if (response.receiptMessageId case final int id) {
        await ChatReceiptStore(ref.read(databaseProvider))
            .finish(id, sourceId, reply);
        assistantMessageId = id;
      } else {
        assistantMessageId = await repo.createMessage(reply);
      }
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
        _hasLiveAgentMessage = false;
        _streamingAgentText = '';
        _agentModelPhase = null;
        _agentExecutionSteps = const [];
        _liveAgentResponse = null;
        _liveAssistantMessageId = null;
      });
    } catch (e) {
      if (mounted) {
        showBeeToast(
            context, '${AppLocalizations.of(context).aiChatSendFailed}: $e',
            tone: BeeTone.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLiveAgentMessage = false;
          _streamingAgentText = '';
          _agentModelPhase = null;
          _agentExecutionSteps = const [];
          _liveQueryContext = const {};
          _livePresentation = null;
          _liveSourceId = null;
          _continuingMessageId = null;
          _liveAgentResponse = null;
          _liveAssistantMessageId = null;
          _activeAgentRunId = null;
          _isAuthorizationDialogOpen = false;
          _pendingWrite = null;
        });
      }
    }
  }

  void _setLiveEvidence(Map<String, Object?> queryContext, int ledgerId) {
    final hadMetric = _livePresentation?.hasDeclaredMetric == true;
    _liveQueryContext = queryContext;
    _livePresentation = AgentFinancialPresentation.select(
        LedgerEvidenceSheet.fromQueryContext(queryContext, ledgerId));
    final sourceId = _liveSourceId;
    if (hadMetric ||
        _livePresentation?.hasDeclaredMetric != true ||
        sourceId == null ||
        !_followLatest ||
        _continuingMessageId != null) {
      return;
    }
    // Keep the first verified figure in view while model text grows underneath.
    // An explicit drag or jump immediately gives control back to the reader.
    _followLatest = false;
    _queryAnchorSource = sourceId;
    _chatScrollCoordinator.onUserScroll();
    if (_scrollController.hasClients &&
        _scrollController.position.isScrollingNotifier.value) {
      _scrollController.jumpTo(_scrollController.position.pixels);
    }
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted &&
          _queryAnchorSource == sourceId &&
          !_liveCardPositioned &&
          _scrollController.hasClients) {
        // A long user message may still keep the lazy reply row out of the tree.
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Value<String?> _responseMetadata(
      AIResponse response, int ledgerId, int sourceId,
      {_SavedTurn? retained}) {
    final metadata = <String, Object?>{
      'contextLedgerId': ledgerId,
      'analysisTemplatesAllowed': response.allowPromptSuggestions,
      'sourceMessageId': sourceId,
      if (retained != null) 'continuedExplanation': true,
      if (_agentExecutionSteps
          .any((s) => s.toolName == 'record_transaction_from_text'))
        'writeRequested': true,
      if (response.wasStopped) 'replyStatus': 'stopped',
      if (_agentExecutionSteps.any((s) =>
          s.status == AgentExecutionStepStatus.failed &&
          P0AgentPolicy.readTools.contains(s.toolName)))
        'queryReadFailed': true,
      if ((response.wasStopped || response.type == 'error') &&
          _streamingAgentText.trim().isNotEmpty)
        'partialText': _streamingAgentText,
      if (response.queryContext.isNotEmpty)
        'queryContext': response.queryContext,
      if (response.supplementalText != null)
        'supplementalText': response.supplementalText,
    };
    metadata.addAll(AssistantExecutionMetadata.encode(
      retained?.steps ??
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
  Future<void> _scrollToBottomWithAnimation() async {
    _queryAnchorSource = null;
    _followLatest = true;
    _isUserScrolling = false;
    final id = _conversationId;
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut);
    if (mounted && _followLatest && _conversationId == id) {
      // Rows with variable Markdown height may finish layout during the animation.
      _chatScrollCoordinator.requestInitialPositioning();
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

  Future<void> _showClearHistoryDialog() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showBeeConfirm(context,
        title: l.aiChatClearHistoryDialogTitle,
        message: l.aiChatClearHistoryDialogContent,
        cancelLabel: l.commonCancel,
        confirmLabel: l.commonConfirm,
        danger: true);
    if (confirmed && mounted) await _clearHistory();
  }

  Future<void> _clearHistory() async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteMessagesByConversation(_conversationId!);

    if (mounted) {
      showBeeToast(context, AppLocalizations.of(context).aiChatHistoryCleared,
          tone: BeeTone.success);
    }
  }

  /// 撤销单笔(多笔卡片里的某一笔,或单笔卡片)
  Future<void> _handleUndoOne(int messageId, int transactionId) async {
    final db = ref.read(databaseProvider);
    final repo = ref.read(repositoryProvider);
    final ledger = ref.read(currentLedgerIdProvider);
    final conversation = _conversationId;
    final l = AppLocalizations.of(context);
    bool undone;
    try {
      undone = await db.transaction(() async {
        final message = await repo.getMessageById(messageId);
        if (message == null ||
            message.conversationId != conversation ||
            message.metadata == null) {
          return false;
        }
        final parsed = _parseBillMetadata(message);
        if (!parsed.txIds.contains(transactionId) ||
            parsed.undoneIds.contains(transactionId)) {
          return false;
        }
        if (!await _chatService.undoTransaction(transactionId,
            expectedLedgerId: ledger)) {
          return false;
        }
        await repo.updateMessage(message.copyWith(
            metadata: Value(_encodeBillMetadata(parsed.bills, parsed.txIds,
                {...parsed.undoneIds, transactionId},
                existingMetadata: message.metadata))));
        return true;
      });
    } catch (error, stack) {
      logger.error('AIChat', '撤销回执失败', error, stack);
      undone = false;
    }
    if (!mounted) return;
    if (!undone) {
      showBeeToast(context, l.aiChatUndoFailed, tone: BeeTone.error);
      return;
    }
    ref.read(statsRefreshProvider.notifier).state++;
    await PostProcessor.sync(ref, ledgerId: ledger);
    if (mounted) showBeeToast(context, l.aiChatUndone, tone: BeeTone.success);
  }

  Future<void> _handleEdit(int messageId, int transactionId) async {
    try {
      final ledger = ref.read(currentLedgerIdProvider);
      final repo = ref.read(repositoryProvider);

      final transaction = await repo.getTransactionById(transactionId);

      if (transaction == null || transaction.ledgerId != ledger) {
        if (mounted) {
          showBeeToast(
              context, AppLocalizations.of(context).aiChatTransactionNotFound,
              tone: BeeTone.warning);
        }
        return;
      }

      if (mounted) {
        await TransactionEditUtils.editTransaction(
            context, ref, transaction, null);

        // 从编辑页面返回后，无论是否保存，都刷新账单卡片
        if (mounted) {
          logger.info('AIChat',
              '编辑页面返回,刷新账单卡片: messageId=$messageId, txId=$transactionId');
          await _refreshBillCard(messageId, transactionId);
        }
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(
            context, AppLocalizations.of(context).aiChatOpenEditorFailed,
            tone: BeeTone.error);
      }
    }
  }

  /// 刷新账单卡片信息(根据 messageId 定位消息,根据 txId 在多笔里定位行)
  Future<void> _refreshBillCard(int messageId, int transactionId) async {
    try {
      final ledger = ref.read(currentLedgerIdProvider);
      final repo = ref.read(repositoryProvider);
      final message = await repo.getMessageById(messageId);
      if (message == null || message.metadata == null) return;

      final transaction = await repo.getTransactionById(transactionId);
      if (transaction == null || transaction.ledgerId != ledger) return;

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

  Future<void> _handleChangeLedger(int transactionId) async {
    final transaction =
        await ref.read(repositoryProvider).getTransactionById(transactionId);
    if (!mounted) return;
    if (transaction == null ||
        transaction.ledgerId != ref.read(currentLedgerIdProvider)) {
      showBeeToast(
          context, AppLocalizations.of(context).aiChatTransactionNotFound,
          tone: BeeTone.warning);
      return;
    }
    await showTransactionMove(context, ref,
        sourceLedgerId: transaction.ledgerId, transactionIds: {transactionId});
  }

  /// The page owns clipboard and deletion; the shared package owns the menu.
  Future<void> _showTextMessageMenu(
      Offset position, Message message, bool isUser) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    final selected =
        await showBeeContextMenu<String>(context, anchor: position, items: [
      BeeMenuAction(
          value: 'copy',
          label: l10n.aiChatCopy,
          icon: const Icon(Icons.copy, size: 20)),
      if (!_isLoading)
        BeeMenuAction(
            value: 'delete',
            label: l10n.commonDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
            danger: true),
    ]);
    if (!mounted) return;
    if (selected == 'copy') {
      await _copyMessage(message);
    } else if (selected == 'delete') {
      await _deleteMessage(message);
    }
  }

  Future<void> _showBillCardMenu(Offset position, Message message) async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    final selected =
        await showBeeContextMenu<String>(context, anchor: position, items: [
      if (!_isLoading)
        BeeMenuAction(
            value: 'delete',
            label: l10n.commonDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
            danger: true),
    ]);
    if (selected == 'delete' && mounted) await _deleteMessage(message);
  }

  /// 删除单条消息
  Future<void> _deleteMessage(Message message) async {
    final l10n = AppLocalizations.of(context);

    // 确认删除
    final confirmed = await showBeeConfirm(context,
        title: l10n.commonDelete,
        message: l10n.aiChatDeleteMessageConfirm,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.commonDelete,
        danger: true);

    if (confirmed != true) return;

    try {
      final repo = ref.read(repositoryProvider);
      await repo.deleteMessage(message.id);

      if (mounted) {
        showBeeToast(context, l10n.aiChatMessageDeleted, tone: BeeTone.success);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, l10n.commonFailed, tone: BeeTone.error);
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
                compact: true,
                expectedLedgerId: ref.read(currentLedgerIdProvider),
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
                    ? () => _handleChangeLedger(txId)
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
    _inputFocus.dispose();
    _inputController.dispose();
    _chatScrollCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

final class _SavedTurn {
  _SavedTurn(this.metadata, this.ledgerId);
  final String? metadata;
  final int ledgerId;
  late final Map data = _AIChatControlsState._readMetadata(metadata);
  late final Map<String, Object?> queryContext =
      data['contextLedgerId'] == ledgerId && data['queryContext'] is Map
          ? Map<String, Object?>.from(data['queryContext'] as Map)
          : const {};
  late final queries =
      LedgerEvidenceSheet.fromQueryContext(queryContext, ledgerId);
  late final presentation = AgentFinancialPresentation.select(queries);
  late final steps = AssistantExecutionMetadata.decode(metadata);
  late final suggestions =
      AssistantFollowUpMetadata.decode(metadata, ledgerId: ledgerId);
  late final allowsSuggestions =
      AssistantFollowUpMetadata.allowsAnalysisTemplates(metadata);
}
