import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/pages/ai/agent_message_visibility.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Message message({
    required int id,
    required String role,
    required String content,
    String type = 'text',
  }) =>
      Message(
        id: id,
        conversationId: 1,
        role: role,
        content: content,
        messageType: type,
        createdAt: DateTime(2026, 9, 5, 10, id),
      );

  test(
      'hides the just-persisted assistant response while live preview is shown',
      () {
    final messages = [
      message(id: 1, role: 'user', content: '早餐 8'),
      message(
        id: 2,
        role: 'assistant',
        content: '✅ 记账成功',
        type: 'bill_card',
      ),
    ];

    final visible = AgentMessageVisibility.forLiveResponse(
      messages,
      liveResponse: AIResponse.billCards(
        [
          BillInfo(
            amount: -8,
            time: DateTime(2026, 9, 5, 8),
            note: '早餐',
          ),
        ],
        const [99],
      ),
      persistedMessageId: 2,
    );

    expect(visible.map((item) => item.id), [1]);
  });

  test('does not hide a previous turn with the same response text', () {
    final messages = [
      message(id: 1, role: 'assistant', content: '好的'),
      message(id: 2, role: 'user', content: '继续'),
    ];

    final visible = AgentMessageVisibility.forLiveResponse(
      messages,
      liveResponse: AIResponse.text('好的'),
    );

    expect(visible.map((item) => item.id), [1, 2]);
  });
}
