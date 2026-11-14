import 'dart:io' show Platform;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/reminder_providers.dart';
import '../../../../utils/notification_android.dart';

enum ReminderHostPlatform { android, ios, other }

final reminderHostPlatformProvider =
    Provider<ReminderHostPlatform>((ref) => Platform.isAndroid
        ? ReminderHostPlatform.android
        : Platform.isIOS
            ? ReminderHostPlatform.ios
            : ReminderHostPlatform.other);

/// Only the OS boundary is replaceable in widget tests; production keeps the
/// original Android utility, channel IDs, queries and settings intents.
abstract class ReminderDiagnostics {
  Future<Map<String, dynamic>> batteryInfo();
  Future<Map<String, dynamic>> channelInfo();
  Future<void> requestBatteryExemption();
  Future<void> openChannelSettings();
  Future<void> openAppSettings();
}

class _AndroidReminderDiagnostics implements ReminderDiagnostics {
  const _AndroidReminderDiagnostics(this.util);
  final AndroidNotificationUtil util;
  @override
  Future<Map<String, dynamic>> batteryInfo() =>
      util.getBatteryOptimizationInfo();
  @override
  Future<Map<String, dynamic>> channelInfo() =>
      util.getNotificationChannelInfo();
  @override
  Future<void> requestBatteryExemption() =>
      util.requestIgnoreBatteryOptimizations();
  @override
  Future<void> openChannelSettings() => util.openNotificationChannelSettings();
  @override
  Future<void> openAppSettings() => util.openAppSettings();
}

final reminderDiagnosticsProvider = Provider<ReminderDiagnostics>((ref) =>
    _AndroidReminderDiagnostics(
        ref.read(reminderNotificationsProvider) as AndroidNotificationUtil));

Future<void> showReminderBatteryInfo(
    BuildContext context, ReminderDiagnostics diagnostics) async {
  final l = AppLocalizations.of(context);
  final info = await diagnostics.batteryInfo();
  if (!context.mounted) return;
  final ignored = info['isIgnoring'] == true;
  final request = await showDialog<bool>(
      context: context,
      builder: (dialog) => BeeDialog(
            title: Text(l.reminderBatteryStatus),
            content: _DiagnosticBody(children: [
              Text(l.reminderManufacturer(
                  info['manufacturer']?.toString() ?? 'Unknown')),
              Text(l.reminderModel(info['model']?.toString() ?? 'Unknown')),
              Text(l.reminderAndroidVersion(
                  info['androidVersion']?.toString() ?? 'Unknown')),
              const SizedBox(height: 12),
              BeeStatus(
                  label: ignored
                      ? l.reminderBatteryIgnored
                      : l.reminderBatteryNotIgnored,
                  tone: ignored ? BeeTone.success : BeeTone.warning),
              if (!ignored)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.reminderBatteryAdvice)),
            ]),
            actions: [
              if (!ignored && info['canRequest'] == true)
                TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(l.commonSettings)),
              BeeButton(
                  label: l.commonConfirm,
                  compact: true,
                  onPressed: () => Navigator.pop(dialog, false)),
            ],
          ));
  if (request == true && context.mounted) {
    await diagnostics.requestBatteryExemption();
  }
}

Future<void> showReminderChannelInfo(
    BuildContext context, ReminderDiagnostics diagnostics) async {
  final l = AppLocalizations.of(context);
  final info = await diagnostics.channelInfo();
  if (!context.mounted) return;
  final warning = info['isEnabled'] != true ||
      ['none', 'min', 'low'].contains(info['importance']);
  final settings = await showDialog<bool>(
      context: context,
      builder: (dialog) => BeeDialog(
            title: Text(l.reminderChannelStatus),
            content: _DiagnosticBody(children: [
              Text(info['isEnabled'] == true
                  ? l.reminderChannelEnabled
                  : l.reminderChannelDisabled),
              Text(l.reminderChannelImportance(
                  info['importance']?.toString() ?? 'unknown')),
              Text(info['sound'] == true
                  ? l.reminderChannelSoundOn
                  : l.reminderChannelSoundOff),
              Text(info['vibration'] == true
                  ? l.reminderChannelVibrationOn
                  : l.reminderChannelVibrationOff),
              if (info['bypassDnd'] != null)
                Text(info['bypassDnd'] == true
                    ? l.reminderChannelDndBypass
                    : l.reminderChannelDndNoBypass),
              const SizedBox(height: 12),
              BeeStatus(
                  label:
                      warning ? l.reminderChannelAdvice : l.reminderChannelGood,
                  tone: warning ? BeeTone.warning : BeeTone.success),
              if (warning) ...[
                Text(l.reminderChannelAdviceImportance),
                Text(l.reminderChannelAdviceSound),
                Text(l.reminderChannelAdviceBanner),
                Text(l.reminderChannelAdviceXiaomi),
              ],
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(l.commonSettings)),
              BeeButton(
                  label: l.commonConfirm,
                  compact: true,
                  onPressed: () => Navigator.pop(dialog, false)),
            ],
          ));
  if (settings == true && context.mounted) {
    await diagnostics.openChannelSettings();
  }
}

class _DiagnosticBody extends StatelessWidget {
  const _DiagnosticBody({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .55),
      child: SingleChildScrollView(
          child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 13, height: 1.5),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children))));
}
