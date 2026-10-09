import 'dart:convert';

/// Optional display-only message metadata, excluded from answer/history text.
abstract final class AssistantReasoningMetadata {
  static Map<String, Object?> encode(String reasoning) =>
      {if (reasoning.isNotEmpty) 'reasoning': reasoning};

  static String decode(String? metadata) {
    if (metadata == null || metadata.isEmpty) return '';
    try {
      final value = jsonDecode(metadata);
      return value is Map && value['reasoning'] is String
          ? value['reasoning'] as String
          : '';
    } on FormatException {
      return '';
    }
  }
}
