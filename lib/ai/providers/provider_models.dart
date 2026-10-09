/// Modality lists after provider-specific model discovery and classification.
class ProviderModels {
  ProviderModels(
      {required List<String> text,
      required List<String> vision,
      List<String> speech = const []})
      : text = List.unmodifiable(text.toSet()),
        vision = List.unmodifiable(vision.toSet()),
        speech = List.unmodifiable(speech.toSet());

  final List<String> text;
  final List<String> vision;
  final List<String> speech;

  static String select(List<String> available, String saved, String preferred) {
    if (available.contains(saved)) return saved;
    if (available.contains(preferred)) return preferred;
    return available.isEmpty ? '' : available.first;
  }
}
