import 'package:agentcore/agentcore.dart' show AgentPromptSuggestion;

import '../../ai/core/bill_info.dart';
import '../../agent/permission/agent_authorization_gate.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_manager.dart';
import '../../data/repositories/base_repository.dart';
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
  }) async {
    try {
      final result = await _agentFacade.processMessage(
        message: userInput,
        ledgerId: ledgerId,
        conversationId: conversationId,
        context: {'languageCode': languageCode},
        l10n: l10n,
        readOnly: readOnly,
      );
      return result.response;
    } catch (error, stackTrace) {
      logger.error('AIChat', '处理失败', error, stackTrace);
      return AIResponse.error('抱歉,处理失败,请重试');
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
  }) =>
      _agentFacade.processMessageEvents(
        message: userInput,
        ledgerId: ledgerId,
        runId: runId,
        conversationId: conversationId,
        context: {'languageCode': languageCode},
        l10n: l10n,
        readOnly: readOnly,
      );

  /// Explicit UI undo, never a model-initiated mutation.
  Future<bool> undoTransaction(int transactionId) async {
    try {
      await _repo.deleteTransaction(transactionId);
      logger.info('AIChat', '撤销记账: id=$transactionId');
      return true;
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

  /// 所有识别到的账单(单笔/多笔都用 list)
  final List<BillInfo> bills;

  /// 与 [bills] 一一对应的交易 ID
  final List<int> transactionIds;
  final AIResponseAction? action;
  final List<AgentPromptSuggestion> followUpSuggestions;

  AIResponse({
    required this.type,
    required this.text,
    this.bills = const [],
    this.transactionIds = const [],
    this.action,
    this.followUpSuggestions = const [],
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

  AIResponse withFollowUpSuggestions(List<AgentPromptSuggestion> suggestions) =>
      AIResponse(
          type: type,
          text: text,
          bills: bills,
          transactionIds: transactionIds,
          action: action,
          followUpSuggestions: List.unmodifiable(suggestions));

  /// 多笔/单笔统一入口。bills 与 txIds 必须等长且非空。
  ///
  /// [note] 附加在成功文案后的一行提示(目前用于多币种「缺汇率按 1:1 暂记」)。
  factory AIResponse.billCards(List<BillInfo> bills, List<int> txIds,
      {String? note}) {
    assert(bills.length == txIds.length && bills.isNotEmpty,
        'bills/txIds 必须等长且非空');
    final n = bills.length;
    final base = n == 1 ? '✅ 记账成功' : '✅ 已记账 $n 笔';
    return AIResponse(
      type: 'bill_card',
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
