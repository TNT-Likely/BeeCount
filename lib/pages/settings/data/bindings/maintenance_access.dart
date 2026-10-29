import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../services/system/logger_service.dart';

final maintenancePlatformProvider =
    Provider<TargetPlatform>((ref) => Platform.isIOS
        ? TargetPlatform.iOS
        : Platform.isAndroid
            ? TargetPlatform.android
            : defaultTargetPlatform);
final maintenanceLoggerProvider = Provider<LoggerService>((ref) => logger);

/// App-owned IO boundary. Production retains the original path-provider roots.
class MaintenanceStorageAccess {
  MaintenanceStorageAccess(
      {Future<Directory> Function()? documents,
      Future<Directory?> Function()? external,
      Future<void> Function(File)? deleteFile})
      : documents = documents ?? getApplicationDocumentsDirectory,
        external = external ?? getExternalStorageDirectory,
        deleteFile = deleteFile ?? _delete;
  final Future<Directory> Function() documents;
  final Future<Directory?> Function() external;
  final Future<void> Function(File) deleteFile;
  static Future<void> _delete(File file) async {
    await file.delete();
  }
}

final maintenanceStorageAccessProvider =
    Provider<MaintenanceStorageAccess>((ref) => MaintenanceStorageAccess());
