import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../services/platform/screenshot_monitor_service.dart';
import '../../../../utils/notification_android.dart';
import '../../../../utils/notification_factory.dart';

/// The production route retains its original iOS / other-platform branch.
enum AutoBillingPlatform { android, ios }

final autoBillingPlatformProvider = Provider<AutoBillingPlatform>((ref) =>
    Platform.isIOS ? AutoBillingPlatform.ios : AutoBillingPlatform.android);

/// Device operations stay in App and can be replaced as a whole for unit tests.
abstract class AutoBillingAndroidActions {
  Future<bool> isEnabled();
  Future<Map<String, dynamic>> batteryInfo();
  Future<bool> requestScreenshotPermission();
  Future<void> enable();
  Future<void> disable();
  Future<bool> requestIgnoreBatteryOptimizations();
  void dispose();
}

typedef AutoBillingAndroidActionsFactory = AutoBillingAndroidActions Function(
    ProviderContainer container);
final autoBillingAndroidActionsFactoryProvider =
    Provider<AutoBillingAndroidActionsFactory>(
        (ref) => _ProductionAndroidActions.new);

class _ProductionAndroidActions implements AutoBillingAndroidActions {
  _ProductionAndroidActions(ProviderContainer container)
      : _monitor = ScreenshotMonitorService(container);
  final ScreenshotMonitorService _monitor;
  AndroidNotificationUtil get _android =>
      NotificationFactory.getInstance() as AndroidNotificationUtil;
  @override
  Future<bool> isEnabled() => _monitor.isEnabled();
  @override
  Future<Map<String, dynamic>> batteryInfo() =>
      _android.getBatteryOptimizationInfo();
  @override
  Future<bool> requestScreenshotPermission() =>
      requestAutoBillingScreenshotPermission();
  @override
  Future<void> enable() => _monitor.enable();
  @override
  Future<void> disable() => _monitor.disable();
  @override
  Future<bool> requestIgnoreBatteryOptimizations() =>
      _android.requestIgnoreBatteryOptimizations();
  @override
  void dispose() => _monitor.dispose();
}

/// Same photos → storage fallback as the original Android page. Injected
/// callbacks exercise permission branching without opening a system prompt.
Future<bool> requestAutoBillingScreenshotPermission({
  Future<bool> Function()? photosRestricted,
  Future<bool> Function()? photosPermanentlyDenied,
  Future<PermissionStatus> Function()? requestPhotos,
  Future<PermissionStatus> Function()? requestStorage,
}) async {
  final restricted = photosRestricted ?? () => Permission.photos.isRestricted;
  final permanentlyDenied =
      photosPermanentlyDenied ?? () => Permission.photos.isPermanentlyDenied;
  final photos = requestPhotos ?? () => Permission.photos.request();
  final storage = requestStorage ?? () => Permission.storage.request();
  PermissionStatus status;
  if (await restricted() || await permanentlyDenied()) {
    status = await storage();
  } else {
    status = await photos();
    if (!status.isGranted) status = await storage();
  }
  return status.isGranted;
}
