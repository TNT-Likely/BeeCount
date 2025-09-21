import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/reminder_providers.dart';
import '../widgets/ui/wheel_time_picker.dart';
import '../services/notification_service.dart';
import '../styles/colors.dart';
import '../widgets/ui/ui.dart';

class ReminderSettingsPage extends ConsumerWidget {
  const ReminderSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderSettings = ref.watch(reminderSettingsProvider);

    return Scaffold(
      backgroundColor: BeeColors.greyBg,
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context)!.reminderTitle,
            subtitle: AppLocalizations.of(context)!.reminderSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          const SizedBox(height: 16),
          
          // 提醒开关
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text(
                AppLocalizations.of(context)!.reminderDailyTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.reminderDailySubtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                ),
              ),
              value: reminderSettings.isEnabled,
              onChanged: (value) {
                ref.read(reminderSettingsProvider.notifier).updateEnabled(value);
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // 提醒时间设置
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                AppLocalizations.of(context)!.reminderTimeTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              subtitle: Text(
                reminderSettings.timeString,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFFCCCCCC),
              ),
              onTap: () async {
                final selectedTime = await showWheelTimePicker(
                  context,
                  initial: TimeOfDay(
                    hour: reminderSettings.hour,
                    minute: reminderSettings.minute,
                  ),
                );
                
                if (selectedTime != null) {
                  ref.read(reminderSettingsProvider.notifier).updateTime(
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // 测试通知按钮
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await NotificationService.showTestNotification();
                if (context.mounted) {
                  showToast(context, AppLocalizations.of(context)!.reminderTestSent);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.reminderTestNotification,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 15秒测试按钮
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await NotificationService.scheduleQuickTest();

                if (context.mounted) {
                  showToast(context, AppLocalizations.of(context)!.reminderQuickTestMessage);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.reminderQuickTest,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // 开发环境专用调试按钮
          if (kDebugMode) ...[
            const SizedBox(height: 16),

            // Flutter通知点击测试按钮
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // 创建一个简单的测试通知来验证点击功能
                  await NotificationService.showTestNotification();
                  if (context.mounted) {
                    showToast(context, AppLocalizations.of(context)!.reminderFlutterTestSent);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.reminderFlutterTest,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // AlarmManager通知点击测试按钮
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await NotificationService.testAlarmManagerNotificationClick();
                  if (context.mounted) {
                    showToast(context, AppLocalizations.of(context)!.reminderAlarmTestMessage);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.reminderAlarmTest,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 直接测试NotificationReceiver按钮
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await NotificationService.testDirectNotificationReceiver();
                  if (context.mounted) {
                    showToast(context, AppLocalizations.of(context)!.reminderDirectTestMessage);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.reminderDirectTest,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 权限检查按钮
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final pendingNotifications = await NotificationService.getPendingNotifications();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context)!.reminderNotificationStatus),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.reminderPendingCount(pendingNotifications.length)),
                            const SizedBox(height: 8),
                            if (pendingNotifications.isNotEmpty)
                              ...pendingNotifications.map((notif) =>
                                Text('• ID: ${notif.id}, 标题: ${notif.title ?? ''}')
                              ),
                            if (pendingNotifications.isEmpty)
                              Text(AppLocalizations.of(context)!.reminderNoPending),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(AppLocalizations.of(context)!.commonConfirm),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.reminderCheckStatus,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 电池优化状态检查
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final batteryInfo = await NotificationService.getBatteryOptimizationInfo();
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context)!.reminderBatteryStatus),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.reminderManufacturer(batteryInfo['manufacturer'] ?? 'Unknown')),
                          Text(AppLocalizations.of(context)!.reminderModel(batteryInfo['model'] ?? 'Unknown')),
                          Text(AppLocalizations.of(context)!.reminderAndroidVersion(batteryInfo['androidVersion'] ?? 'Unknown')),
                          const SizedBox(height: 8),
                          Text(
                            '电池优化状态: ${(batteryInfo['isIgnoring'] == true) ? AppLocalizations.of(context)!.reminderBatteryIgnored : AppLocalizations.of(context)!.reminderBatteryNotIgnored}',
                            style: TextStyle(
                              color: (batteryInfo['isIgnoring'] == true) ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (batteryInfo['isIgnoring'] != true) ...[
                            const SizedBox(height: 8),
                            Text(
                              '建议关闭电池优化以确保通知正常工作',
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        if (batteryInfo['isIgnoring'] != true && batteryInfo['canRequest'] == true)
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await NotificationService.requestIgnoreBatteryOptimizations();
                            },
                            child: Text('去设置'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocalizations.of(context)!.commonConfirm),
                        ),
                      ],
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.reminderCheckBattery,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 通知渠道设置检查
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final channelInfo = await NotificationService.getNotificationChannelInfo();
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context)!.reminderChannelStatus),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('渠道启用: ${(channelInfo['isEnabled'] == true) ? '是 ✅' : '否 ❌'}'),
                          Text(AppLocalizations.of(context)!.reminderChannelImportance(channelInfo['importance'] ?? 'unknown')),
                          Text('声音: ${(channelInfo['sound'] == true) ? '开启 🔊' : '关闭 🔇'}'),
                          Text('震动: ${(channelInfo['vibration'] == true) ? '开启 📳' : '关闭'}'),
                          if (channelInfo['bypassDnd'] != null)
                            Text('勿扰模式: ${(channelInfo['bypassDnd'] == true) ? '可绕过' : '不可绕过'}'),
                          const SizedBox(height: 8),
                          if (channelInfo['isEnabled'] != true ||
                              channelInfo['importance'] == 'none' ||
                              channelInfo['importance'] == 'min' ||
                              channelInfo['importance'] == 'low') ...[
                            Text(
                              AppLocalizations.of(context)!.reminderChannelAdvice,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            Text(AppLocalizations.of(context)!.reminderChannelAdviceImportance),
                            Text(AppLocalizations.of(context)!.reminderChannelAdviceSound),
                            Text(AppLocalizations.of(context)!.reminderChannelAdviceBanner),
                            Text(AppLocalizations.of(context)!.reminderChannelAdviceXiaomi),
                          ] else ...[
                            Text(
                              AppLocalizations.of(context)!.reminderChannelGood,
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await NotificationService.openNotificationChannelSettings();
                          },
                          child: Text('去设置'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocalizations.of(context)!.commonConfirm),
                        ),
                      ],
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.reminderCheckChannel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 打开应用设置
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await NotificationService.openAppSettings();
                if (context.mounted) {
                  showToast(context, AppLocalizations.of(context)!.reminderAppSettingsMessage);
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.reminderOpenAppSettings,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // iOS通知调试按钮
          if (Theme.of(context).platform == TargetPlatform.iOS) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await NotificationService.showTestNotification();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context)!.reminderIOSTestTitle),
                        content: Text(
                          AppLocalizations.of(context)!.reminderIOSTestMessage,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(AppLocalizations.of(context)!.commonConfirm),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.reminderIOSTest,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 说明文字
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE5E5E5),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.reminderDescription,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Theme.of(context).platform == TargetPlatform.iOS
                      ? AppLocalizations.of(context)!.reminderIOSInstructions
                      : AppLocalizations.of(context)!.reminderAndroidInstructions,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      );
  }
}