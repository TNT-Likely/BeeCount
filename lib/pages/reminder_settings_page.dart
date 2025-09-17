import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            title: '记账提醒',
            subtitle: '设置每日记账提醒时间',
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
              title: const Text(
                '每日记账提醒',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              subtitle: const Text(
                '开启后将在指定时间提醒您记账',
                style: TextStyle(
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
              title: const Text(
                '提醒时间',
                style: TextStyle(
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
                  showToast(context, '测试通知已发送');
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
              child: const Text(
                '发送测试通知',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 30秒测试按钮
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await NotificationService.scheduleQuickTest();

                if (context.mounted) {
                  showToast(context, '已设置30秒后的快速测试，请保持应用在后台');
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
              child: const Text(
                '快速测试 (30秒后)',
                style: TextStyle(
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
                    showToast(context, '已发送Flutter测试通知，点击查看是否能打开应用');
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
                child: const Text(
                  '🔧 测试Flutter通知点击（开发）',
                  style: TextStyle(
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
                    showToast(context, '已设置AlarmManager测试通知（1秒后），点击查看是否能打开应用');
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
                child: const Text(
                  '🔧 测试AlarmManager通知点击（开发）',
                  style: TextStyle(
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
                    showToast(context, '已直接调用NotificationReceiver创建通知，查看点击是否有效');
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
                child: const Text(
                  '🔧 直接测试NotificationReceiver（开发）',
                  style: TextStyle(
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
                        title: const Text('通知状态'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('待处理通知数量: ${pendingNotifications.length}'),
                            const SizedBox(height: 8),
                            if (pendingNotifications.isNotEmpty)
                              ...pendingNotifications.map((notif) =>
                                Text('• ID: ${notif.id}, 标题: ${notif.title}')
                              ),
                            if (pendingNotifications.isEmpty)
                              const Text('当前没有待处理的通知'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('确定'),
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
                child: const Text(
                  '🔧 检查通知状态（开发）',
                  style: TextStyle(
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
                      title: const Text('电池优化状态'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('设备制造商: ${batteryInfo['manufacturer'] ?? 'Unknown'}'),
                          Text('设备型号: ${batteryInfo['model'] ?? 'Unknown'}'),
                          Text('Android版本: ${batteryInfo['androidVersion'] ?? 'Unknown'}'),
                          const SizedBox(height: 8),
                          Text(
                            '电池优化状态: ${(batteryInfo['isIgnoring'] == true) ? '已忽略 ✅' : '未忽略 ⚠️'}',
                            style: TextStyle(
                              color: (batteryInfo['isIgnoring'] == true) ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (batteryInfo['isIgnoring'] != true) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '建议关闭电池优化以确保通知正常工作',
                              style: TextStyle(fontSize: 12, color: Colors.red),
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
                            child: const Text('去设置'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('确定'),
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
              child: const Text(
                '检查电池优化状态',
                style: TextStyle(
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
                      title: const Text('通知渠道状态'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('渠道启用: ${(channelInfo['isEnabled'] == true) ? '是 ✅' : '否 ❌'}'),
                          Text('重要性: ${channelInfo['importance'] ?? 'unknown'}'),
                          Text('声音: ${(channelInfo['sound'] == true) ? '开启 🔊' : '关闭 🔇'}'),
                          Text('震动: ${(channelInfo['vibration'] == true) ? '开启 📳' : '关闭'}'),
                          if (channelInfo['bypassDnd'] != null)
                            Text('勿扰模式: ${(channelInfo['bypassDnd'] == true) ? '可绕过' : '不可绕过'}'),
                          const SizedBox(height: 8),
                          if (channelInfo['isEnabled'] != true ||
                              channelInfo['importance'] == 'none' ||
                              channelInfo['importance'] == 'min' ||
                              channelInfo['importance'] == 'low') ...[
                            const Text(
                              '⚠️ 建议设置：',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            const Text('• 重要性：紧急或高'),
                            const Text('• 开启声音和震动'),
                            const Text('• 允许横幅通知'),
                            const Text('• 小米手机需单独设置每个渠道'),
                          ] else ...[
                            const Text(
                              '✅ 通知渠道配置良好',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
                          child: const Text('去设置'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('确定'),
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
              child: const Text(
                '检查通知渠道设置',
                style: TextStyle(
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
                  showToast(context, '请在设置中允许通知、关闭电池优化');
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '打开应用设置',
                style: TextStyle(
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
                        title: const Text('iOS通知测试'),
                        content: const Text(
                          '已发送测试通知。\n\n🍎 iOS模拟器限制：\n• 通知可能不会在通知中心显示\n• 横幅提醒可能不工作\n• 但Xcode控制台会显示日志\n\n💡 调试方法：\n• 查看Xcode控制台输出\n• 检查Flutter日志信息\n• 使用真机测试获得完整体验',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('确定'),
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
                child: const Text(
                  '🍎 iOS通知调试测试',
                  style: TextStyle(
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
                const Text(
                  '提示：开启记账提醒后，系统会在每天指定时间发送通知提醒您记录收支。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Theme.of(context).platform == TargetPlatform.iOS
                      ? '🍎 iOS通知设置：\n• 设置 > 通知 > 蜜蜂记账\n• 开启"允许通知"\n• 设置通知样式：横幅或提醒\n• 开启声音和震动\n\n⚠️ iOS模拟器限制：\n• 模拟器通知功能有限\n• 建议使用真机测试\n• 查看Xcode控制台了解通知状态\n\n如果在模拟器中测试，请观察：\n• Xcode控制台日志输出\n• Flutter Debug Console信息\n• 应用内弹窗确认通知发送'
                      : '如果通知无法正常工作，请检查：\n• 已允许应用发送通知\n• 关闭应用的电池优化/省电模式\n• 允许应用在后台运行和自启动\n• Android 12+需要精确闹钟权限\n\n📱 小米手机特殊设置：\n• 设置 > 应用管理 > 蜜蜂记账 > 通知管理\n• 点击"记账提醒"渠道\n• 设置重要性为"紧急"或"高"\n• 开启"横幅通知"、"声音"、"震动"\n• 安全中心 > 应用管理 > 权限 > 自启动\n\n🔒 锁定后台方法：\n• 最近任务中找到蜜蜂记账\n• 向下拉动应用卡片显示锁定图标\n• 点击锁定图标防止被清理',
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