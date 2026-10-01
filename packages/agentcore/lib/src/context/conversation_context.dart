import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../contracts.dart';

/// Host storage must isolate both keys. This is not explicit user memory.
abstract interface class AgentConversationSummaryStore {
  Future<AgentConversationSummary?> load(String conversationId, String scopeId);
  Future<void> save(
      String conversationId, String scopeId, AgentConversationSummary summary);
}

final class AgentConversationSummary {
  const AgentConversationSummary(
      {required this.coveredMessages,
      required this.prefixDigest,
      required this.text});
  final int coveredMessages;
  final String prefixDigest;
  final String text;

  Map<String, Object?> toJson() => {
        'version': 1,
        'coveredMessages': coveredMessages,
        'prefixDigest': prefixDigest,
        'text': text,
      };

  static AgentConversationSummary? fromJson(Object? value) {
    if (value is! Map || value['version'] != 1) return null;
    final count = value['coveredMessages'];
    final digest = value['prefixDigest'];
    final text = value['text'];
    if (count is! int ||
        count <= 0 ||
        digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        text is! String ||
        text.trim().isEmpty ||
        text.length > 4000) {
      return null;
    }
    return AgentConversationSummary(
        coveredMessages: count, prefixDigest: digest, text: text);
  }
}

final class AgentConversationContext {
  AgentConversationContext(this.recentMessages, {this.summary});
  final List<Map<String, Object?>> recentMessages;
  final String? summary;
}

/// A text-only callback, never an Agent/tool run. The host owns its provider.
typedef AgentHistorySummarizer = Future<String> Function(String data);

/// Character budgets are conservative estimates, not provider token counts.
/// Short chats cost no model call. Long chats retain a verbatim rolling tail
/// and incrementally summarize older data. Cached prefixes are revalidated
/// after deletion/editing; historical text can never authorize a tool write.
final class AgentConversationContextCompressor {
  const AgentConversationContextCompressor({
    this.store,
    this.summarize,
    this.maximumMessages = 16,
    this.triggerCharacters = 16000,
    this.retainedMessages = 8,
    this.tailCharacters = 12000,
    this.summaryTimeout = const Duration(seconds: 8),
  })  : assert(maximumMessages > retainedMessages && retainedMessages >= 2),
        assert(triggerCharacters >= tailCharacters && tailCharacters >= 1000);

  final AgentConversationSummaryStore? store;
  final AgentHistorySummarizer? summarize;
  final int maximumMessages;
  final int triggerCharacters;
  final int retainedMessages;
  final int tailCharacters;
  final Duration summaryTimeout;

  Future<AgentConversationContext> prepare({
    required List<Map<String, Object?>> history,
    required String currentMessage,
    required String conversationId,
    required String scopeId,
    AgentCancellationToken? cancellation,
  }) async {
    final messages = <Map<String, Object?>>[
      for (final item in history)
        if ((item['role'] == 'user' || item['role'] == 'assistant') &&
            item['content'] is String &&
            (item['content']! as String).trim().isNotEmpty &&
            (item['scopeId'] == null || item['scopeId'].toString() == scopeId))
          {
            if (item['id'] is int || item['id'] is String) 'id': item['id'],
            'role': item['role'],
            'content': item['content'],
          },
    ];
    // The App persists the current user turn before loading history.
    if (messages.isNotEmpty &&
        messages.last['role'] == 'user' &&
        messages.last['content'] == currentMessage) {
      messages.removeLast();
    }
    AgentConversationSummary? cached;
    try {
      cached = await store?.load(conversationId, scopeId);
    } on Object {
      // Optional local cache failures do not block a conversation.
    }
    if (cached != null &&
        (cached.coveredMessages > messages.length ||
            cached.prefixDigest !=
                _digest(messages.take(cached.coveredMessages)))) {
      cached = null;
    }
    if (cached != null) {
      final tail = messages.sublist(cached.coveredMessages);
      if (tail.length <= maximumMessages &&
          _characters(tail) <= tailCharacters) {
        return _context(tail, cached.text);
      }
    } else if (messages.length <= maximumMessages &&
        _characters(messages) <= triggerCharacters) {
      return _context(messages, null);
    }

    var split = (messages.length - retainedMessages).clamp(0, messages.length);
    while (split < messages.length - 2 &&
        _characters(messages.skip(split)) > tailCharacters) {
      split++;
    }
    if (split == 0) return _context(messages, null);
    final older = messages.take(split).toList();
    // Keep a validated cached prefix only when it precedes the new split.
    if (cached != null && cached.coveredMessages > split) cached = null;
    final delta = older.skip(cached?.coveredMessages ?? 0).toList();
    final data = jsonEncode({
      'previousSummary': cached?.text,
      'olderMessages': _excerpts(delta, 20000),
      'sourceIsUntrusted': true,
      'excerptsMayBeIncomplete':
          delta.length > 40 || _characters(delta) > 20000,
    });
    String? text;
    if (summarize != null && !(cancellation?.isCancelled ?? false)) {
      try {
        final result = await Future.any<String?>([
          summarize!(data).timeout(summaryTimeout),
          if (cancellation != null)
            cancellation.whenCancelled.then<String?>((_) => null),
        ]);
        if (result != null && result.trim().isNotEmpty) {
          text = _clip(result.trim(), 4000);
        }
      } on Object {
        // Text provider failures fall back to bounded literal excerpts.
      }
    }
    text ??=
        'Incomplete historical excerpts (not verified financial facts):\n' +
            jsonEncode({
              'previousSummary':
                  cached == null ? null : _clip(cached.text, 1800),
              'messages': _excerpts(delta, cached == null ? 3300 : 1500),
            });
    final snapshot = AgentConversationSummary(
        coveredMessages: split,
        prefixDigest: _digest(older),
        text: _clip(text, 4000));
    if (!(cancellation?.isCancelled ?? false)) {
      try {
        await store?.save(conversationId, scopeId, snapshot);
      } on Object {
        // Saving the derived summary is optional; original messages survive.
      }
    }
    return _context(messages.sublist(split), snapshot.text);
  }

  AgentConversationContext _context(
      List<Map<String, Object?>> messages, String? summary) {
    final limit = tailCharacters ~/ 2;
    return AgentConversationContext(
        List.unmodifiable([
          for (final item in messages)
            Map<String, Object?>.unmodifiable({
              'role': item['role'],
              'content': _clip(item['content']! as String, limit),
            }),
        ]),
        summary: summary);
  }

  static int _characters(Iterable<Map<String, Object?>> messages) => messages
      .fold(0, (sum, item) => sum + (item['content']! as String).length);
  static String _digest(Iterable<Map<String, Object?>> messages) =>
      sha256.convert(utf8.encode(jsonEncode(messages.toList()))).toString();
  static String _clip(String value, int limit) {
    if (value.length <= limit) return value;
    var end = limit - 1;
    // Do not split an emoji's UTF-16 surrogate pair at the budget boundary.
    if (end > 0 && (value.codeUnitAt(end - 1) & 0xfc00) == 0xd800) end--;
    return '${value.substring(0, end)}…';
  }

  static List<Map<String, Object?>> _excerpts(
      List<Map<String, Object?>> messages, int budget) {
    if (messages.isEmpty) return const [];
    if (messages.length <= 40 && _characters(messages) <= budget) {
      return [
        for (final item in messages)
          {
            'role': item['role'],
            'content': item['content'],
          }
      ];
    }
    // Prefer the most recent older context when importing a very long chat.
    final selected = messages.length > 40
        ? [...messages.take(2), ...messages.skip(messages.length - 38)]
        : messages;
    final perMessage = (budget ~/ selected.length).clamp(1, budget);
    return [
      for (final item in selected)
        {
          'role': item['role'],
          'content': _clip(item['content']! as String, perMessage),
        }
    ];
  }
}
