import 'package:shared_preferences/shared_preferences.dart';

import '../services/system/logger_service.dart';
import '../utils/notification_factory.dart';

/// 信用卡还款提醒服务
///
/// 使用 SharedPreferences 存储设置，通知 ID 为 2000 + accountId
class CreditCardReminderService {
  /// 计算下一次提醒时间
  static DateTime _nextReminderDate({
    required int paymentDueDay,
    required int daysBefore,
    int hour = 10,
    int minute = 0,
  }) {
    final now = DateTime.now();
    final reminderDay = paymentDueDay - daysBefore;

    // 本月提醒日
    var reminderDate = DateTime(now.year, now.month, reminderDay, hour, minute);

    // 如果 reminderDay <= 0，回到上月
    if (reminderDay <= 0) {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final daysInPrevMonth =
          DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
      reminderDate = DateTime(
        prevMonth.year,
        prevMonth.month,
        daysInPrevMonth + reminderDay,
        hour,
        minute,
      );
    }

    // 如果已经过了本月提醒日，安排下月
    if (reminderDate.isBefore(now)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextReminderDay = paymentDueDay - daysBefore;
      if (nextReminderDay > 0) {
        reminderDate = DateTime(
            nextMonth.year, nextMonth.month, nextReminderDay, hour, minute);
      } else {
        // 跨月情况
        final daysInNextMonth =
            DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        reminderDate = DateTime(
          nextMonth.year,
          nextMonth.month,
          (daysInNextMonth + nextReminderDay).clamp(1, daysInNextMonth),
          hour,
          minute,
        );
      }
    }

    return reminderDate;
  }

  /// 调度还款提醒
  static Future<void> scheduleReminder({
    required int accountId,
    required String accountName,
    required int paymentDueDay,
    required int daysBefore,
    int hour = 10,
    int minute = 0,
  }) async {
    try {
      final notificationUtil = NotificationFactory.getInstance();
      final notificationId = 2000 + accountId;
      final scheduledDate = _nextReminderDate(
        paymentDueDay: paymentDueDay,
        daysBefore: daysBefore,
        hour: hour,
        minute: minute,
      );

      await notificationUtil.scheduleOnceReminder(
        id: notificationId,
        title: '$accountName还款日即将到来',
        body: '还款日为每月$paymentDueDay日，请及时还款',
        scheduledDate: scheduledDate,
      );

      logger.info('CreditCardReminder',
          '已调度提醒: accountId=$accountId, 时间=$scheduledDate');
    } catch (e, stack) {
      logger.error('CreditCardReminder', '调度提醒失败', e, stack);
    }
  }

  /// 取消还款提醒
  static Future<void> cancelReminder(int accountId) async {
    try {
      final notificationUtil = NotificationFactory.getInstance();
      final notificationId = 2000 + accountId;
      await notificationUtil.cancelNotification(notificationId);
      logger.info('CreditCardReminder', '已取消提醒: accountId=$accountId');
    } catch (e, stack) {
      logger.error('CreditCardReminder', '取消提醒失败', e, stack);
    }
  }

  /// 恢复所有信用卡提醒（应用启动时调用）
  static Future<void> restoreAllReminders({
    required Future<List<dynamic>> Function() getCreditCardAccounts,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await getCreditCardAccounts();

      for (final account in accounts) {
        final accountId = account.id as int;
        final enabled =
            prefs.getBool('cc_reminder_enabled_$accountId') ?? false;
        if (!enabled) continue;

        final paymentDueDay = account.paymentDueDay as int?;
        if (paymentDueDay == null) continue;

        final daysBefore = prefs.getInt('cc_reminder_days_$accountId') ?? 3;
        final accountName = account.name as String;

        await scheduleReminder(
          accountId: accountId,
          accountName: accountName,
          paymentDueDay: paymentDueDay,
          daysBefore: daysBefore,
        );
      }

      logger.info('CreditCardReminder', '已恢复所有信用卡提醒');
    } catch (e, stack) {
      logger.error('CreditCardReminder', '恢复提醒失败', e, stack);
    }
  }
}
