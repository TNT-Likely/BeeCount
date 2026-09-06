import 'package:beecount/agent/permission/agent_tool_permission.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/agent_permissions_page.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/styles/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryPermissionStore store;

  setUp(() {
    store = _MemoryPermissionStore();
  });

  Widget host() {
    return ProviderScope(
      overrides: [agentToolPermissionStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const AgentPermissionsPage(),
      ),
    );
  }

  testWidgets('默认将记录交易工具设为每次询问', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('AI助手权限'), findsOneWidget);
    expect(find.text('只读工具'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('数据修改工具'), 160);
    expect(find.text('数据修改工具'), findsOneWidget);
    expect(find.text('每次询问'), findsNWidgets(3));
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('permission-status-record_transaction_from_text'),
      ),
      120,
    );
    expect(
      find.byKey(
        const ValueKey('permission-status-record_transaction_from_text'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('权限说明使用中性信息卡而非主题渐变', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final intro = tester.widget<Container>(
      find.byKey(const ValueKey('agent-permissions-intro')),
    );
    final decoration = intro.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(
        decoration.color,
        BeeTokens.surfaceSecondary(tester.element(
          find.byKey(const ValueKey('agent-permissions-intro')),
        )));
  });

  testWidgets('可将单个工具改为始终允许', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('permission-status-record_transaction_from_text'),
      ),
      160,
    );
    await tester.tap(find.byKey(const ValueKey(
      'permission-status-record_transaction_from_text',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('始终允许').last);
    await tester.pumpAndSettle();

    expect(
      await store.permissionFor('record_transaction_from_text'),
      AgentToolPermission.alwaysAllow,
    );
  });

  testWidgets('恢复默认会移除已保存的始终允许设置', (tester) async {
    await store.setPermission(
      'record_transaction_from_text',
      AgentToolPermission.alwaysAllow,
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('restore-agent-permissions')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复').last);
    await tester.pumpAndSettle();

    expect(
      await store.permissionFor('record_transaction_from_text'),
      AgentToolPermission.ask,
    );
  });
}

final class _MemoryPermissionStore implements AgentToolPermissionStore {
  final Map<String, AgentToolPermission> _values = {};

  @override
  Future<AgentToolPermission?> permissionFor(String toolName) async {
    final descriptor = AgentToolPermissionCatalog.find(toolName);
    return descriptor == null
        ? null
        : _values[toolName] ?? descriptor.defaultPermission;
  }

  @override
  Future<Map<String, AgentToolPermission>> readAll() async {
    return {
      for (final descriptor in AgentToolPermissionCatalog.descriptors)
        descriptor.toolName:
            _values[descriptor.toolName] ?? descriptor.defaultPermission,
    };
  }

  @override
  Future<void> restoreDefaults() async => _values.clear();

  @override
  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  ) async {
    _values[toolName] = permission;
  }
}
