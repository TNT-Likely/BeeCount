import 'package:beecount/utils/notification_android.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('daily reminder and backups auto-cancel on tap without disabling badges',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tz.initializeTimeZones();
    final scheduled = <Map<dynamic, dynamic>>[];
    const pluginChannel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    const nativeChannel = MethodChannel('notification_channel');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      if (call.method == 'zonedSchedule') {
        scheduled.add(call.arguments as Map<dynamic, dynamic>);
        return null;
      }
      return true;
    });
    messenger.setMockMethodCallHandler(nativeChannel, (_) async => true);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pluginChannel, null);
      messenger.setMockMethodCallHandler(nativeChannel, null);
    });

    await AndroidNotificationUtil(FlutterLocalNotificationsPlugin())
        .scheduleDailyReminder(
      id: 1001,
      title: 'QA reminder',
      body: 'Synthetic notification',
      hour: 21,
      minute: 0,
    );

    expect(scheduled, hasLength(8));
    expect(scheduled.first['id'], 1001);
    for (final request in scheduled) {
      final details = request['platformSpecifics'] as Map<dynamic, dynamic>;
      expect(details['autoCancel'], isTrue);
      expect(details['channelShowBadge'], isTrue);
      expect(request['scheduledDateTime'], isNotEmpty);
    }
  });
}
