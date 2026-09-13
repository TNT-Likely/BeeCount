import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/core/ai_extraction_engine.dart';
import '../services/ai/ai_bookkeeper.dart';
import '../services/ai/ai_chat_service.dart';
import '../services/ai/agent_app_facade.dart';
import '../services/billing/bill_creation_service.dart';
import '../providers.dart';
import '../data/db.dart';
import '../agent/memory/agent_memory_repository.dart';
import '../agent/memory/local_agent_memory_repository.dart';
import '../agent/runtime/agent_execution_settings.dart';
import '../agent/runtime/shared_preferences_agent_execution_settings_store.dart';
import '../agent/tools/local_agent_tools.dart';
import '../agent/permission/agent_tool_permission.dart';
import '../agent/permission/shared_preferences_agent_tool_permission_store.dart';
import '../utils/month_range.dart';

/// AI 多模态记账底座 (Layer 1)。无状态,可全局复用。
final aiExtractionEngineProvider = Provider<AiExtractionEngine>(
  (ref) => const DefaultAiExtractionEngine(),
);

/// AI 记账应用层 (Layer 2)。5 个调用渠道(对话/图片/语音/自动截图/自动文本)
/// 的统一入口。
final aiBookkeeperProvider = Provider<AiBookkeeper>((ref) {
  final repo = ref.watch(repositoryProvider);
  return AiBookkeeper(
    repository: repo,
    engine: ref.watch(aiExtractionEngineProvider),
    persister: BillCreationService(
      repo,
      // 多币种(.docs/multi-currency-ai A6):AI 识别出外币时,落库前把该币种
      // 的汇率拉到本地,否则 repo 只能按 1:1 折算。注入而非在渠道层预拉,是
      // 为了让**后台自动记账**(截图/通知,无 WidgetRef)也走同一条路径。
      ensureRate: (code) =>
          refreshExchangeRates(ref, force: true, extraQuotes: {code}),
    ),
  );
});

/// Agent 的记忆、审计与检索全部停留在本机 Drift 数据库。
final agentMemoryRepositoryProvider = Provider<AgentMemoryRepository>((ref) {
  return LocalAgentMemoryRepository(ref.watch(databaseProvider));
});

final localAgentToolGatewayProvider = Provider<LocalAgentToolGateway>((ref) {
  return BeeCountLocalAgentToolGateway(
    repository: ref.watch(repositoryProvider),
    database: ref.watch(databaseProvider),
    bookkeeper: ref.watch(aiBookkeeperProvider),
    memoryRepository: ref.watch(agentMemoryRepositoryProvider),
  );
});

final agentToolPermissionStoreProvider = Provider<AgentToolPermissionStore>(
  (_) => SharedPreferencesAgentToolPermissionStore(
    getPreferences: SharedPreferences.getInstance,
  ),
);

final agentExecutionSettingsStoreProvider =
    Provider<AgentExecutionSettingsStore>(
  (_) => SharedPreferencesAgentExecutionSettingsStore(
    getPreferences: SharedPreferences.getInstance,
  ),
);

final agentAppFacadeProvider = Provider<AgentAppFacade>((ref) {
  final repo = ref.watch(repositoryProvider);
  return AgentAppFacade(
    memoryRepository: ref.watch(agentMemoryRepositoryProvider),
    toolGateway: ref.watch(localAgentToolGatewayProvider),
    permissionStore: ref.watch(agentToolPermissionStoreProvider),
    executionSettingsStore: ref.watch(agentExecutionSettingsStoreProvider),
    conversationHistoryLoader: (conversationId) async {
      final messages = await repo.watchMessages(conversationId).first;
      return [
        for (final message in messages)
          {
            'role': message.role,
            'content': message.content,
          },
      ];
    },
  );
});

/// AI 对话服务 Provider
final aiChatServiceProvider = Provider<AIChatService>((ref) {
  final repo = ref.watch(repositoryProvider);
  return AIChatService(
    repo: repo,
    bookkeeper: ref.watch(aiBookkeeperProvider),
    agentFacade: ref.watch(agentAppFacadeProvider),
  );
});

/// 当前对话 ID Provider
final currentConversationIdProvider = StateProvider<int?>((ref) => null);

/// 消息列表 Provider
final messagesProvider = StreamProvider.family<List<Message>, int>(
  (ref, conversationId) {
    final repo = ref.watch(repositoryProvider);
    return repo.watchMessages(conversationId);
  },
);

/// Empty conversations show a small, local snapshot of the active period.
///
/// The transaction count intentionally includes every recorded transaction,
/// while [expense] keeps the existing statistics convention and excludes
/// transactions marked as `excludeFromStats`.
final class AiChatEmptyLedgerSummary {
  const AiChatEmptyLedgerSummary({
    required this.period,
    required this.transactionCount,
    required this.expense,
  });

  final DateTime period;
  final int transactionCount;
  final double expense;

  bool get hasTransactionData => transactionCount > 0;
}

/// A live summary for the empty AI conversation state.
///
/// It deliberately reads through [BaseRepository], so it remains local-first
/// and does not couple the chat UI to Drift or any optional cloud backend.
final aiChatEmptyLedgerSummaryProvider =
    StreamProvider.autoDispose<AiChatEmptyLedgerSummary>((ref) {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final startDay = ref.watch(currentMonthStartDayProvider);
  final period = labelForDate(DateTime.now(), startDay);
  final repository = ref.watch(repositoryProvider);

  return repository
      .watchTransactionsInMonth(ledgerId: ledgerId, month: period)
      .asyncMap((transactions) async {
    final (_, expense) = await repository.monthlyTotals(
      ledgerId: ledgerId,
      month: period,
    );
    return AiChatEmptyLedgerSummary(
      period: period,
      transactionCount: transactions.length,
      expense: expense,
    );
  });
});
