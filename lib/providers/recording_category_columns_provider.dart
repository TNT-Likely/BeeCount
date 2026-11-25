import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final recordingCategoryColumnsProvider =
    AsyncNotifierProvider<RecordingCategoryColumns, int>(
  RecordingCategoryColumns.new,
);

class RecordingCategoryColumns extends AsyncNotifier<int> {
  static const preferenceKey = 'recording_category_columns';

  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<int> build() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.get(preferenceKey);
    return saved is int && saved == 5 ? 5 : 4;
  }

  Future<void> setColumns(int columns) {
    if (columns != 4 && columns != 5) {
      throw ArgumentError.value(columns, 'columns', 'Expected 4 or 5');
    }
    final write = _pendingWrite.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      try {
        if (!await preferences.setInt(preferenceKey, columns)) {
          throw StateError('Could not save recording category columns');
        }
      } catch (_) {
        // SharedPreferences updates its in-memory cache before the disk write.
        await preferences.reload();
        rethrow;
      }
      state = AsyncData(columns);
    });
    // Keep later selections usable after a write fails.
    _pendingWrite =
        write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
