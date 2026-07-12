import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

/// 头像管理服务
class AvatarService {
  static const String _avatarPathKey = 'user_avatar_path';
  // 服务端的 avatar_version —— sync 时拿来和新拉到的 version 对比，相同就跳过下载。
  static const String _avatarRemoteVersionKey = 'user_avatar_remote_version';

  /// 获取用户头像路径
  ///
  /// 注意：存储的是相对路径，读取时动态拼接 Documents 目录
  /// 这样即使 iOS 应用更新后 UUID 变化，头像也不会丢失
  static Future<String?> getAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    final relativePath = prefs.getString(_avatarPathKey);
    if (relativePath == null) return null;

    // 兼容旧版本存储的绝对路径
    if (relativePath.startsWith('/')) {
      // 尝试从绝对路径中提取相对路径并迁移
      final match =
          RegExp(r'avatars/avatar_\d+\.\w+$').firstMatch(relativePath);
      if (match != null) {
        final extracted = match.group(0)!;
        // 检查文件是否在新位置存在
        final appDir = await getApplicationDocumentsDirectory();
        final newPath = p.join(appDir.path, extracted);
        if (await File(newPath).exists()) {
          // 迁移到相对路径
          await prefs.setString(_avatarPathKey, extracted);
          return newPath;
        }
      }
      // 旧路径文件不存在，清除设置
      await prefs.remove(_avatarPathKey);
      return null;
    }

    // 拼接完整路径
    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = p.join(appDir.path, relativePath);

    // 验证文件存在
    if (!await File(fullPath).exists()) {
      await prefs.remove(_avatarPathKey);
      return null;
    }

    return fullPath;
  }

  /// 选择并保存头像
  static Future<String?> pickAndSaveAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null) return null;

    // 删除旧头像（如果存在）
    await _deleteOldAvatar();

    // 获取应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(p.join(appDir.path, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    // 生成新文件名（使用时间戳避免缓存问题）
    final ext = p.extension(image.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'avatar_$timestamp$ext';
    final relativePath = 'avatars/$fileName';
    final newPath = p.join(avatarDir.path, fileName);

    // 复制文件
    final file = File(image.path);
    await file.copy(newPath);

    // 保存相对路径到SharedPreferences（避免iOS更新后UUID变化导致路径失效）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, relativePath);

    return newPath;
  }

  /// 拍照并保存头像
  static Future<String?> takePhotoAndSaveAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null) return null;

    // 删除旧头像（如果存在）
    await _deleteOldAvatar();

    // 获取应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(p.join(appDir.path, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    // 生成新文件名（使用时间戳避免缓存问题）
    final ext = p.extension(image.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'avatar_$timestamp$ext';
    final relativePath = 'avatars/$fileName';
    final newPath = p.join(avatarDir.path, fileName);

    // 复制文件
    final file = File(image.path);
    await file.copy(newPath);

    // 保存相对路径到SharedPreferences（避免iOS更新后UUID变化导致路径失效）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, relativePath);

    return newPath;
  }

  /// 从字节流保存头像（初始同步从云端下载后用它落盘）。
  static Future<String?> saveAvatarFromBytes(
    Uint8List bytes, {
    String extension = '.jpg',
  }) async {
    if (bytes.isEmpty) return null;
    await _deleteOldAvatar();
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(p.join(appDir.path, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final fileName = 'avatar_$timestamp$ext';
    final relativePath = 'avatars/$fileName';
    final newPath = p.join(avatarDir.path, fileName);
    await File(newPath).writeAsBytes(bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, relativePath);
    return newPath;
  }

  /// 取上一次同步下来的远端头像版本（没同步过返回 null 或 0）。
  static Future<int> getStoredRemoteVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_avatarRemoteVersionKey) ?? 0;
  }

  /// 更新本地缓存的远端头像版本。
  static Future<void> setStoredRemoteVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_avatarRemoteVersionKey, version);
  }

  /// 清掉本地缓存的远端版本号（登出时用，避免换账号后复用旧版本号跳过下载）。
  static Future<void> clearStoredRemoteVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarRemoteVersionKey);
  }

  /// 删除头像
  static Future<void> deleteAvatar() async {
    await _deleteOldAvatar();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPathKey);
    await prefs.remove(_avatarRemoteVersionKey);
  }

  /// 删除旧头像文件（内部方法）
  static Future<void> _deleteOldAvatar() async {
    final avatarPath = await getAvatarPath();
    if (avatarPath != null) {
      final file = File(avatarPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
