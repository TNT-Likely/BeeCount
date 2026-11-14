import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart';
import '../../../providers.dart';
import '../../../pages/ai/ai_chat_page.dart';

/// Read-only repository binding: visiting the catalog never creates a chat.
class LiveAIConversationPreview extends ConsumerWidget {
  const LiveAIConversationPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实会话与消息（只读）'),
      const SizedBox(height: 8),
      FutureBuilder<Conversation?>(
          future: repo.getActiveConversation(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('${snapshot.error}');
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            if (snapshot.data == null) {
              return const BeeSurface(child: Text('没有会话，不创建示例对象'));
            }
            final conversation = snapshot.data!;
            return StreamBuilder<List<Message>>(
                stream: repo.watchMessages(conversation.id),
                builder: (context, messages) {
                  if (messages.hasError) return Text('${messages.error}');
                  if (!messages.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return BeeSurface(
                      child: Text(
                          '会话 ${conversation.id} · ${messages.data!.length} 条消息'));
                });
          }),
      BeeButton(
          label: '打开真实AI对话',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const AIChatPage())))
    ]);
  }
}
