import '../../../agent/permission/agent_authorization_gate.dart';
import '../../../widgets/ai/agent_tool_authorization_dialog.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

class AIConversationSample extends StatefulWidget {
  const AIConversationSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AIConversationSample> createState() => _AIConversationSampleState();
}

class _AIConversationSampleState extends State<AIConversationSample> {
  final input = TextEditingController(text: 'QA 合成提问');
  String event = '局部示例，不发送模型请求或创建账单';
  bool undone = false, busy = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeConversationStart(
          title: l.aiChatEmptyStartTitle,
          description: l.aiChatEmptyStartDescription,
          example: l.aiChatEmptyQuestionExample,
          brand: const BeeLineIcon('Sparkles', size: 32),
          summary: BeeConversationLedgerBrief(
              amount: const Text('¥3,506.76'),
              count: '53 笔',
              amountLabel: l.aiChatEmptyMonthExpense,
              countLabel: l.aiChatEmptyRecordedTransactions)),
      const SizedBox(height: 16),
      const BeeConversationUserMessage(child: Text('看看本月支出')),
      BeeSurface(child: Text(event)),
      const SizedBox(height: 8),
      BeeConversationInput(
          controller: input,
          hint: l.aiChatInputHint,
          sendLabel: l.v4AIChatSend,
          stopLabel: l.agentRunStop,
          busy: busy,
          onSend: () => setState(() {
                event = '示例发送：${input.text}';
                busy = true;
              }),
          onStop: () => setState(() {
                event = '示例已停止';
                busy = false;
              })),
      BeeAssistantBillCard(
          title: undone ? l.billCardUndone : l.billCardSuccess,
          ledger: 'QA 示例账本',
          undone: undone,
          undoLabel: l.billCardUndo,
          editLabel: l.billCardEdit,
          tagsLabel: l.billCardTags,
          tags: const ['工作日', '出差'],
          fields: [
            BeeAssistantBillField(l.billCardAmount, 'US\$12.00'),
            BeeAssistantBillField(l.billCardCategory, '餐饮 / 午餐'),
            BeeAssistantBillField(l.billCardTime, '10月25日 12:30'),
            BeeAssistantBillField(l.billCardTransferAccounts, '美元账户 → 储蓄卡'),
            BeeAssistantBillField(l.billCardNote, 'QA 合成备注')
          ],
          onUndo: () => setState(() {
                undone = true;
                event = '示例撤销，不改真实交易';
              }),
          onEdit: () => setState(() => event = '示例编辑入口'),
          onChangeLedger: () => setState(() => event = '示例切换账本入口')),
      const SizedBox(height: 8),
      BeeButton(
          label: '查看工具授权示例',
          kind: BeeButtonKind.secondary,
          onPressed: () async {
            final choice = await showAgentToolAuthorizationDialog(
                context: context,
                request: AgentToolAuthorizationRequest(
                    authorizationId: 'qa-gallery',
                    runId: 'qa-gallery',
                    ledgerId: 1,
                    toolName: 'record_transaction_from_text',
                    arguments: const {'sourceText': 'QA 合成：午餐花了32元'}));
            if (mounted) setState(() => event = '示例授权 ${choice.name}，不改真实权限');
          }),
      const SizedBox(height: 16),
      widget.liveData ?? const Text('App读取原会话与消息；真实模型、工具权限和账单写入留在正式页面。')
    ]);
  }
}
