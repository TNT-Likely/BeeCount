import 'package:beecount/agent/runtime/shared_preferences_agent_execution_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses the standard depth until a valid local preference is saved',
      () async {
    final store = SharedPreferencesAgentExecutionSettingsStore(
      getPreferences: SharedPreferences.getInstance,
    );

    expect((await store.read()).maximumModelTurns, 4);

    await store.setMaximumModelTurns(6);

    expect((await store.read()).maximumModelTurns, 6);
  });

  test('normalizes an unsafe persisted execution depth to the supported range',
      () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesAgentExecutionSettingsStore.key: 99,
    });
    final store = SharedPreferencesAgentExecutionSettingsStore(
      getPreferences: SharedPreferences.getInstance,
    );

    expect((await store.read()).maximumModelTurns, 8);
  });
}
