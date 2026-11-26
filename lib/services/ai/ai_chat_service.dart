import 'package:agentcore/agentcore.dart' show AgentPromptSuggestion;

import '../../ai/core/bill_info.dart';
import '../../agent/permission/agent_authorization_gate.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_manager.dart';
import '../../utils/app_localizations_resolver.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../system/logger_service.dart';
import 'agent_app_facade.dart';

/// UI adapter for a single Agent conversation path. Recommended questions and
/// manual input share permissions, tool validation, streaming and cancellation.
/// Bookkeeping remains delegated by the Agent's authorized tools to AiBookkeeper.
class AIChatService {
  AIChatService({
    required BaseRepository repo,
    required AgentAppFacade agentFacade,
  })  : _repo = repo,
        _agentFacade = agentFacade;

  final BaseRepository _repo;
  final AgentAppFacade _agentFacade;

  bool resolveToolAuthorization(
    String authorizationId,
    AgentToolAuthorizationChoice choice,
  ) =>
      _agentFacade.resolveToolAuthorization(authorizationId, choice);

  void cancelPendingToolAuthorizations() =>
      _agentFacade.cancelPendingToolAuthorizations();

  bool cancelAgentRun(String runId) => _agentFacade.cancelRun(runId);

  /// Local configuration validation only; does not call the provider.
  static Future<AIConfigValidationResult> validateApiKey() async {
    final config = await AIProviderManager.getProviderForCapability(
      AICapabilityType.text,
    );
    if (config == null) {
      return AIConfigValidationResult.invalid('未配置文本对话服务商');
    }
    if (!config.isValid) {
      return AIConfigValidationResult.invalid('未配置 API Key');
    }
    if (!config.supportsText) {
      return AIConfigValidationResult.invalid('未配置文本模型');
    }
    return AIConfigValidationResult.valid();
  }

  Future<AIResponse> processMessage(
    String userInput, {
    required int ledgerId,
    int? conversationId,
    String? languageCode,
    AppLocalizations? l10n,
    bool readOnly = false,
    int? sourceMessageId,
    Map<String, Object?> view = const {},
    bool review = false,
  }) async {
    try {
      final result = await _agentFacade.processMessage(
        message: userInput,
        ledgerId: ledgerId,
        conversationId: conversationId,
        context: await _context(
            ledgerId, languageCode, sourceMessageId, view, review),
        l10n: l10n,
        readOnly: readOnly,
      );
      return result.response;
    } catch (error, stackTrace) {
      logger.error('AIChat', '处理失败', error, stackTrace);
      return AIResponse.error(l10n?.aiChatGenericFailure ??
          resolveAppLocalizations(null).aiChatGenericFailure);
    }
  }

  Stream<AgentRunEvent> processMessageEvents(
    String userInput, {
    required int ledgerId,
    String? runId,
    int? conversationId,
    String? languageCode,
    AppLocalizations? l10n,
    bool readOnly = false,
    int? sourceMessageId,
    Map<String, Object?> view = const {},
    bool review = false,
    List<Map<String, Object?>> repeatQueries = const [],
    Map<String, Object?>? continueQueryContext,
    bool Function()? isCancelled,
  }) async* {
    final context =
        await _context(ledgerId, languageCode, sourceMessageId, view, review);
    if (isCancelled?.call() == true) {
      yield AgentRunCompletedEvent(AgentChatResponse(
          runId: runId ?? '',
          response: AIResponse.stopped(
              (l10n ?? resolveAppLocalizations(null)).agentRunCancelled)));
      return;
    }
    if (readOnly && repeatQueries.isNotEmpty) {
      context['repeatQueries'] = repeatQueries;
    }
    if (readOnly && continueQueryContext != null) {
      context['continueQueryContext'] = continueQueryContext;
    }
    yield* _agentFacade.processMessageEvents(
      message: userInput,
      ledgerId: ledgerId,
      runId: runId,
      conversationId: conversationId,
      context: context,
      l10n: l10n,
      readOnly: readOnly,
    );
  }

  Future<Map<String, Object?>> _context(int ledgerId, String? languageCode,
      int? sourceMessageId, Map<String, Object?> view, bool review) async {
    final context = <String, Object?>{
      'languageCode': languageCode,
      if (sourceMessageId != null) 'sourceMessageId': sourceMessageId,
      if (view['ledgerId'] == ledgerId) 'view': view,
      if (review) 'review': true
    };
    try {
      final ledger = await _repo.getLedgerById(ledgerId);
      if (ledger != null) {
        context['ledger'] = {
          'id': ledger.id,
          'name': ledger.name,
          'currency': ledger.currency,
          'monthStartDay': ledger.monthStartDay
        };
      }
    } on Exception catch (_) {
      // Database tool calls still enforce the host ledger if its description is unavailable.
    }
    return context;
  }

  /// A saved receipt may outlive a move to another ledger. Keep ownership
  /// verification, sync tracking, and deletion in the same SQLite transaction.
  Future<bool> undoTransaction(int transactionId,
      {int? expectedLedgerId, String? expectedSyncId}) async {
    try {
      final repo = _repo;
      if (expectedLedgerId == null && expectedSyncId == null) {
        // Keep the unscoped API for existing callers. Chat supplies its ledger.
        await repo.deleteTransaction(transactionId);
        return true;
      }
      if (repo is! LocalRepository || expectedLedgerId == null) return false;
      return await repo.db.transaction(() async {
        final row = await repo.getTransactionById(transactionId);
        if (row == null ||
            row.ledgerId != expectedLedgerId ||
            (expectedSyncId != null && row.syncId != expectedSyncId)) {
          return false;
        }
        await repo.deleteTransaction(transactionId);
        return true;
      });
    } catch (error, stackTrace) {
      logger.error('AIChat', '撤销失败', error, stackTrace);
      return false;
    }
  }
}

/// AI 配置验证结果
class AIConfigValidationResult {
  final bool isValid;
  final String? errorMessage;

  AIConfigValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  factory AIConfigValidationResult.valid() {
    return AIConfigValidationResult(isValid: true);
  }

  factory AIConfigValidationResult.invalid(String message) {
    return AIConfigValidationResult(isValid: false, errorMessage: message);
  }
}

/// AI 对话响应模型
enum AIResponseAction { openProviderSettings }

class AIResponse {
  final String type; // 'text' | 'bill_card' | 'error'
  final String text;
  final bool wasStopped;

  /// 所有识别到的账单(单笔/多笔都用 list)
  final List<BillInfo> bills;

  /// 与 [bills] 一一对应的交易 ID
  final List<int> transactionIds;
  final AIResponseAction? action;
  final List<AgentPromptSuggestion> followUpSuggestions;

  /// Trusted run outcome, not inferred from the model's final prose.
  final bool allowPromptSuggestions;
  final Map<String, Object?> queryContext;
  final String? supplementalText;
  final int? receiptMessageId;

  AIResponse({
    required this.type,
    required this.text,
    this.wasStopped = false,
    this.bills = const [],
    this.transactionIds = const [],
    this.action,
    this.followUpSuggestions = const [],
    this.allowPromptSuggestions = false,
    this.queryContext = const {},
    this.supplementalText,
    this.receiptMessageId,
  });

  /// 首个 BillInfo(兼容写入 messages.transactionId 列)
  BillInfo? get billInfo => bills.isNotEmpty ? bills.first : null;

  /// 首个交易 ID
  int? get transactionId =>
      transactionIds.isNotEmpty ? transactionIds.first : null;

  factory AIResponse.text(String text,
          {List<AgentPromptSuggestion> followUpSuggestions = const []}) =>
      AIResponse(
          type: 'text',
          text: text,
          followUpSuggestions: List.unmodifiable(followUpSuggestions));

  factory AIResponse.stopped(String text) =>
      AIResponse(type: 'text', text: text, wasStopped: true);

  AIResponse withFollowUpSuggestions(List<AgentPromptSuggestion> suggestions,
          {bool allowPromptSuggestions = false,
          Map<String, Object?>? queryContext}) =>
      AIResponse(
          type: type,
          text: text,
          wasStopped: wasStopped,
          queryContext: queryContext ?? this.queryContext,
          supplementalText: supplementalText,
          receiptMessageId: receiptMessageId,
          bills: bills,
          transactionIds: transactionIds,
          action: action,
          allowPromptSuggestions: allowPromptSuggestions,
          followUpSuggestions: List.unmodifiable(suggestions));

  /// 多笔/单笔统一入口。bills 与 txIds 必须等长且非空。
  ///
  /// [note] 附加在成功文案后的一行提示(目前用于多币种「缺汇率按 1:1 暂记」)。
  factory AIResponse.billCards(List<BillInfo> bills, List<int> txIds,
      {String? note, AppLocalizations? l10n, int? receiptMessageId}) {
    assert(bills.length == txIds.length && bills.isNotEmpty,
        'bills/txIds 必须等长且非空');
    final n = bills.length;
    final l10nEff = l10n ?? resolveAppLocalizations(null);
    final base = n == 1
        ? l10nEff.aiChatRecordSuccessOne
        : l10nEff.aiChatRecordSuccessMany(n);
    return AIResponse(
      type: 'bill_card',
      supplementalText: note,
      receiptMessageId: receiptMessageId,
      text: (note == null || note.isEmpty) ? base : '$base\n$note',
      bills: List.unmodifiable(bills),
      transactionIds: List.unmodifiable(txIds),
    );
  }

  factory AIResponse.error(
    String message, {
    AIResponseAction? action,
  }) =>
      AIResponse(type: 'error', text: message, action: action);
}
