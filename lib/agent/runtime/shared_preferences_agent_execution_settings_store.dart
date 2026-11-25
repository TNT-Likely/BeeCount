import 'package:shared_preferences/shared_preferences.dart';

import 'agent_execution_settings.dart';

final class SharedPreferencesAgentExecutionSettingsStore
    implements AgentExecutionSettingsStore {
  SharedPreferencesAgentExecutionSettingsStore({
    required Future<SharedPreferences> Function() getPreferences,
  }) : _getPreferences = getPreferences;

  static const String key = 'agent_execution_depth_v1';

  final Future<SharedPreferences> Function() _getPreferences;

  @override
  Future<AgentExecutionSettings> read() async {
    final value = (await _getPreferences()).getInt(key);
    return AgentExecutionSettings(maximumModelTurns: value);
  }

  @override
  Future<void> setMaximumModelTurns(int value) async {
    if (value == AgentExecutionSettings.automaticChoice) {
      if (!await (await _getPreferences()).remove(key)) {
        throw StateError('无法保存 AI 助手执行深度设置。');
      }
      return;
    }
    final normalized =
        AgentExecutionSettings(maximumModelTurns: value).maximumModelTurns;
    final written = await (await _getPreferences()).setInt(key, normalized);
    if (!written) {
      throw StateError('无法保存 AI 助手执行深度设置。');
    }
  }
}
