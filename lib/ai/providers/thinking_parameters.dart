/// Shared explicit Thinking control for MiMo and DeepSeek generation requests.
Map<String, Object?> thinkingParameters(bool enabled, {double? temperature}) =>
    {
      'thinking': {'type': enabled ? 'enabled' : 'disabled'},
      if (!enabled && temperature != null) 'temperature': temperature,
    };
