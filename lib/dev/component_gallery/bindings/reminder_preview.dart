import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/reminder_providers.dart';
import '../../../pages/settings/reminder_settings_page.dart';

/// Real preferences are read here; OS writes require the explicit settings entry.
class LiveReminderPreview extends ConsumerWidget {
  const LiveReminderPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        settings = ref.watch(reminderSettingsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实偏好预览（只读）'),
      const SizedBox(height: 8),
      BeeReminderPreferences(
          enabled: settings.isEnabled,
          enabledLabel: l.reminderDailyTitle,
          enabledDescription: l.reminderDailySubtitle,
          timeLabel: l.reminderTimeTitle,
          time: settings.timeString,
          onEnabled: null,
          onTime: null),
      const SizedBox(height: 8),
      BeeButton(
          label: '打开真实记账提醒设置',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const ReminderSettingsPage()))),
    ]);
  }
}
