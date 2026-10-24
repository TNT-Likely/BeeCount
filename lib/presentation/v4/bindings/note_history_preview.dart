import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../pages/settings/appearance_settings_page.dart';
import 'appearance_dialogs.dart';

/// Read the same production preferences; writes require opening the real page.
class LiveNoteHistoryPreview extends StatelessWidget {
  const LiveNoteHistoryPreview({super.key});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('真实历史备注偏好（只读）'),
        const SizedBox(height: 8),
        const NoteHistoryPreferencesView(readOnly: true),
        const SizedBox(height: 8),
        BeeButton(
            label: '打开真实显示与外观设置',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const AppearanceSettingsPage()))),
      ]);
}
