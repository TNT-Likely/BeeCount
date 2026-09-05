import '../../data/db.dart';
import '../../services/ai/ai_chat_service.dart';

/// Keeps the persisted assistant message from duplicating the live response
/// while the current Agent run is being finalized.
final class AgentMessageVisibility {
  const AgentMessageVisibility._();

  static List<Message> forLiveResponse(
    List<Message> messages, {
    required AIResponse? liveResponse,
    int? persistedMessageId,
  }) {
    if (liveResponse == null) return messages;

    if (persistedMessageId != null) {
      return messages
          .where((message) => message.id != persistedMessageId)
          .toList();
    }

    // A database stream can deliver the insert before the insert Future has
    // resumed. Until the ID is available, only hide a matching assistant row
    // that was inserted after this run's latest user message. This prevents a
    // previous turn with identical text from being removed.
    final latestUserIndex = messages.lastIndexWhere(
      (message) => message.role == 'user',
    );
    final latestAssistantIndex = messages.lastIndexWhere(
      (message) => message.role == 'assistant',
    );
    if (latestAssistantIndex <= latestUserIndex || latestUserIndex < 0) {
      return messages;
    }

    final candidate = messages[latestAssistantIndex];
    if (candidate.content != liveResponse.text ||
        candidate.messageType != liveResponse.type) {
      return messages;
    }
    return [
      for (var index = 0; index < messages.length; index++)
        if (index != latestAssistantIndex) messages[index],
    ];
  }
}
