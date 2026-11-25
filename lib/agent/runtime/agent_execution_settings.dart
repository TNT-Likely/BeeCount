/// User-controlled execution depth for a foreground Agent request.
///
/// This intentionally exposes model turns only. Tool-call limits remain a
/// runtime safety boundary so a user preference cannot accidentally permit an
/// unbounded sequence of local actions.
final class AgentExecutionSettings {
  AgentExecutionSettings({int? maximumModelTurns})
      : automatic = maximumModelTurns == null,
        maximumModelTurns = _normalize(maximumModelTurns ?? standardTurns);

  static const int minimumTurns = 2;
  static const int standardTurns = 4;
  static const int maximumTurns = 8;

  final int maximumModelTurns;
  final bool automatic;
  static const automaticChoice = 0;

  /// Keeps the number of local actions bounded without exposing a second,
  /// harder-to-understand safety setting in the UI.
  int get maximumToolCalls => maximumModelTurns + 2;

  ({int turns, int calls}) budgetFor(String text, {bool review = false}) {
    if (!automatic) return (turns: maximumModelTurns, calls: maximumToolCalls);
    // This only sets the initial allowance. Every permitted read is available
    // for other phrasings, and actual query progress can extend the allowance.
    final comprehensive = review ||
        RegExp(
          r'复盘|復盤|月度小结|月度小結|月度分析|综合分析|綜合分析|monthly review|comprehensive|month.in.review',
          caseSensitive: false,
        ).hasMatch(text);
    return comprehensive ? (turns: 6, calls: 8) : (turns: 4, calls: 6);
  }

  static int _normalize(int value) => value.clamp(minimumTurns, maximumTurns);
}

abstract interface class AgentExecutionSettingsStore {
  Future<AgentExecutionSettings> read();

  Future<void> setMaximumModelTurns(int value);
}
