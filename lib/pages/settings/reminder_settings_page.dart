import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/reminder_providers.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../presentation/v4/bindings/reminder_diagnostics.dart';

class ReminderSettingsPage extends ConsumerStatefulWidget {
  const ReminderSettingsPage({super.key});
  @override
  ConsumerState<ReminderSettingsPage> createState() =>
      _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends ConsumerState<ReminderSettingsPage> {
  bool _busy = false;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonError,
            tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _time() async {
    final l = AppLocalizations.of(context),
        settings = ref.read(reminderSettingsProvider);
    var draft = TimeOfDay(hour: settings.hour, minute: settings.minute);
    final value = await showBeeSheet<TimeOfDay>(context,
        title: l.commonSelectTime,
        child: StatefulBuilder(
            builder: (context, setDraft) => BeeTimeWheels(
                value: draft, onChanged: (v) => setDraft(() => draft = v))),
        footer: Row(children: [
          Expanded(
              child: BeeButton(
                  label: l.commonCancel,
                  kind: BeeButtonKind.secondary,
                  onPressed: () => Navigator.pop(context))),
          const SizedBox(width: 12),
          Expanded(
              child: BeeButton(
                  label: l.commonOk,
                  onPressed: () => Navigator.pop(context, draft))),
        ]));
    if (mounted && value != null) {
      await ref
          .read(reminderSettingsProvider.notifier)
          .updateTime(value.hour, value.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        settings = ref.watch(reminderSettingsProvider);
    final platform = ref.watch(reminderHostPlatformProvider),
        android = platform == ReminderHostPlatform.android;
    Widget action(String label, Future<void> Function() onPressed,
            {bool primary = false}) =>
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: BeeButton(
                label: label,
                kind: primary ? BeeButtonKind.primary : BeeButtonKind.secondary,
                onPressed: _busy ? null : () => _run(onPressed)));
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.reminderTitle, leading: const BackButton()),
      Expanded(
          child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(17),
              children: [
            Text(l.reminderSubtitle,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            BeeReminderPreferences(
                enabled: settings.isEnabled,
                enabledLabel: l.reminderDailyTitle,
                enabledDescription: l.reminderDailySubtitle,
                timeLabel: l.reminderTimeTitle,
                time: settings.timeString,
                onEnabled: _busy
                    ? null
                    : (v) => _run(() => ref
                        .read(reminderSettingsProvider.notifier)
                        .updateEnabled(v)),
                onTime: _busy ? null : () => _run(_time)),
            action(l.reminderTestNotification, () async {
              final notifications = ref.read(reminderNotificationsProvider);
              await notifications.showNotification(
                  id: 9999,
                  title: l.reminderTestTitle,
                  body: l.reminderTestBody);
              if (context.mounted) {
                showBeeToast(context, l.reminderTestSent,
                    tone: BeeTone.success);
              }
            }, primary: true),
            if (android) ...[
              action(
                  l.reminderCheckBattery,
                  () => showReminderBatteryInfo(
                      context, ref.read(reminderDiagnosticsProvider))),
              action(
                  l.reminderCheckChannel,
                  () => showReminderChannelInfo(
                      context, ref.read(reminderDiagnosticsProvider))),
              action(l.reminderOpenAppSettings, () async {
                final diagnostics = ref.read(reminderDiagnosticsProvider);
                await diagnostics.openAppSettings();
                if (context.mounted) {
                  showBeeToast(context, l.reminderAppSettingsMessage);
                }
              }),
            ],
            const SizedBox(height: 16),
            BeeSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(l.reminderDescription,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                      platform == ReminderHostPlatform.ios
                          ? l.reminderIOSInstructions
                          : l.reminderAndroidInstructions,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Theme.of(context).hintColor)),
                ])),
          ])),
    ]));
  }
}
