/// 更新结果相关的类和枚举
class UpdateResult {
  final bool hasUpdate;
  final bool success;
  final String? message;
  final String? filePath;
  final String? version;
  final String? downloadUrl;
  final String? releaseNotes;
  final UpdateResultType? type;

  UpdateResult({
    this.hasUpdate = false,
    this.success = false,
    this.message,
    this.filePath,
    this.version,
    this.downloadUrl,
    this.releaseNotes,
    this.type,
  });

  UpdateResult._({
    required this.success,
    this.hasUpdate = false,
    this.message,
    this.filePath,
    this.version,
    this.downloadUrl,
    this.releaseNotes,
    required this.type,
  });

  factory UpdateResult.downloadSuccess(String filePath) => UpdateResult._(
        success: true,
        filePath: filePath,
        type: UpdateResultType.downloadSuccess,
      );

  factory UpdateResult.alreadyLatest(String version) => UpdateResult._(
        success: true,
        message: '当前已是最新版本 $version',
        type: UpdateResultType.alreadyLatest,
      );

  factory UpdateResult.userCancelled() => UpdateResult._(
        success: false,
        message: '用户取消',
        type: UpdateResultType.userCancelled,
      );

  factory UpdateResult.permissionDenied() => UpdateResult._(
        success: false,
        message: '权限被拒绝',
        type: UpdateResultType.permissionDenied,
      );

  factory UpdateResult.downloadFailed(String error) => UpdateResult._(
        success: false,
        message: '下载失败: $error',
        type: UpdateResultType.downloadFailed,
      );

  factory UpdateResult.installFailed(String error) => UpdateResult._(
        success: false,
        message: '安装失败: $error',
        type: UpdateResultType.installFailed,
      );

  factory UpdateResult.checkFailed(String error) => UpdateResult._(
        success: false,
        message: '检查更新失败: $error',
        type: UpdateResultType.checkFailed,
      );
}

enum UpdateResultType {
  downloadSuccess,
  alreadyLatest,
  userCancelled,
  permissionDenied,
  downloadFailed,
  installFailed,
  checkFailed,
}

/// 应用信息类
class AppInfo {
  final String version;
  final String buildNumber;
  final String? commit;
  final String? buildTime;

  const AppInfo(this.version, this.buildNumber, {this.commit, this.buildTime});
}