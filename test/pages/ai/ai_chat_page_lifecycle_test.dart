import 'package:beecount/ai/core/ai_extraction_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/ai_chat_page.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/ai/ai_bookkeeper.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase database;
  late LocalRepository repository;

  setUp(() {
    database = BeeDatabase.forTesting(NativeDatabase.memory());
    repository = LocalRepository(database);
  });

  tearDown(() => database.close());

  Widget host() {
    final chatService = AIChatService(
      repo: repository,
      bookkeeper: AiBookkeeper(
        repository: repository,
        engine: const DefaultAiExtractionEngine(),
        persister: BillCreationService(repository),
      ),
    );
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(chatService),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const AIChatPage(),
      ),
    );
  }

  testWidgets('离开 AI 对话页不会在 dispose 后读取 ref', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
