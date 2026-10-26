// Verify the exact seeded Random sequences used by the original parts in the
// local Dart VM and dart2js backends. This is not part of the rendered App.
import 'dart:convert';
import 'dart:math';

void main() {
  final out = <String, List<double>>{};
  for (final seed in [23, 14, 5, 21, 7]) {
    final random = Random(seed);
    out['$seed'] = List.generate(1024, (_) => random.nextDouble());
  }
  print('BC_ORIGINAL_RANDOM_PROBE:${jsonEncode(out)}');
}
