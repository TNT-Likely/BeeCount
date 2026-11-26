import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/services/ai/chat_session_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late ChatSessionStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    store = ChatSessionStore(db);
  });
  tearDown(() => db.close());

  Future<int> add(int id, String text,
          {String role = 'user', String? metadata}) =>
      db.into(db.messages).insert(MessagesCompanion.insert(
          conversationId: id,
          role: role,
          content: text,
          messageType: 'text',
          metadata: Value(metadata)));

  test(
      'new, history and relaunch preserve the original thread and ledger boundary',
      () async {
    final first = await store.open(1);
    expect(await store.start(1, first), first);
    await add(first, 'First question');
    final second = await store.start(1, first);
    expect(second, isNot(first));
    await add(second, 'Second question');
    expect(await store.open(1), second);
    expect((await store.history(1)).map((c) => c.title),
        containsAll(['First question', 'Second question']));
    expect(await store.select(1, first), isTrue);
    expect(await ChatSessionStore(db).open(1), first);
    expect(await store.select(2, first), isFalse);
    expect(await store.history(2), isEmpty);
  });

  test(
      'mixed legacy sessions retain receipt and message identities and omit frozen rows from model history',
      () async {
    final id =
        await db.into(db.conversations).insert(ConversationsCompanion.insert());
    await add(id, 'old untagged preface');
    final first = await add(id, 'Ledger A', metadata: '{"contextLedgerId":1}');
    final second = await add(id, 'Ledger B', metadata: '{"contextLedgerId":2}');
    final reply = await add(id, 'B answer',
        role: 'assistant',
        metadata: jsonEncode({
          'contextLedgerId': 2,
          'queryContext': {
            'queries': [
              {'ref': 'b/1'}
            ],
            'snapshots': {
              'b/1': {
                'pages': ['private-frozen-data']
              }
            }
          },
        }));
    await add(id, 'legacy note', metadata: 'invalid-json');
    await add(id, 'malformed query',
        role: 'assistant', metadata: '{"queryContext":"not an object"}');
    expect(await store.open(1), id);
    final b = await store.open(2);
    expect(b, isNot(id));
    final histA = await store.modelHistory(id);
    expect(
        histA.map((m) => m['content']), ['old untagged preface', 'Ledger A']);
    expect(histA.last['id'], first);
    final histB = await store.modelHistory(b);
    expect(histB.map((m) => m['id']), containsAll([second, reply]));
    expect(jsonEncode(histB), isNot(contains('private-frozen-data')));
    expect(jsonEncode(histB), contains('b/1'));
    expect(
        (await (db.select(db.messages)..where((m) => m.id.equals(reply)))
                .getSingle())
            .metadata,
        contains('private-frozen-data'));
    expect(await store.open(2), b);
  });
}
