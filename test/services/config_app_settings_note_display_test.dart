import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/services/export/config_export_service.dart';

void main() {
  group('AppSettingsConfig note_display_mode 往返', () {
    test('toMap 写出 note_display_mode', () {
      final map = const AppSettingsConfig(noteDisplayMode: 'note').toMap();
      expect(map['note_display_mode'], 'note');
    });

    test('fromMap 读回 note_display_mode', () {
      final cfg = AppSettingsConfig.fromMap({'note_display_mode': 'note'});
      expect(cfg.noteDisplayMode, 'note');
    });

    test('未设置时 toMap 不含该键(保持兼容)', () {
      final map = const AppSettingsConfig().toMap();
      expect(map.containsKey('note_display_mode'), isFalse);
    });
  });
}
