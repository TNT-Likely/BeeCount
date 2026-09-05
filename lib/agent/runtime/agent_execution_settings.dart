/// User-controlled execution depth for a foreground Agent request.
///
/// This intentionally exposes model turns only. Tool-call limits remain a
/// runtime safety boundary so a user preference cannot accidentally permit an
/// unbounded sequence of local actions.
final class AgentExecutionSettings {
  AgentExecutionSettings({int maximumModelTurns = standardTurns})
      : maximumModelTurns = _normalize(maximumModelTurns);

  static const int minimumTurns = 2;
  static const int standardTurns = 4;
  static const int maximumTurns = 8;

  final int maximumModelTurns;

  /// Keeps the number of local actions bounded without exposing a second,
  /// harder-to-understand safety setting in the UI.
  int get maximumToolCalls => maximumModelTurns + 2;

  static int _normalize(int value) => value.clamp(minimumTurns, maximumTurns);
}

abstract interface class AgentExecutionSettingsStore {
  Future<AgentExecutionSettings> read();

  Future<void> setMaximumModelTurns(int value);
}
