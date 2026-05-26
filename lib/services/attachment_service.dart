import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import '../providers.dart';
import 'system/logger_service.dart';

/// 附件服务
/// 负责图片的选择、压缩、存储和管理
class AttachmentService {
  static const int maxAttachments = 9;
  static const int maxWidth = 1920;
  static const int maxHeight = 1920;
  static const int quality = 80;
  static const int thumbnailSize = 200;

  final Ref ref;
  final ImagePicker _picker = ImagePicker();

  AttachmentService(this.ref);

  /// 获取附件存储目录
  Future<Directory> getAttachmentDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/attachments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 获取缩略图缓存目录
  Future<Directory> getThumbnailDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final dir = Directory('${cacheDir.path}/attachment_thumbs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 从相册选择图片
  /// 返回选择的图片文件列表
  Future<List<File>> pickFromGallery({int maxCount = 9}) async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
      return images.map((x) => File(x.path)).toList();
    } catch (e) {
      logger.error('AttachmentService', '从相册选择图片失败', e);
      return [];
    }
  }

  /// 拍照
  Future<File?> takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      logger.error('AttachmentService', '拍照失败', e);
      return null;
    }
  }

  /// 保存附件
  ///
  /// 将图片压缩后保存到附件目录，并在数据库中创建记录。
  ///
  /// [urgent] 紧急模式:跳过 `FlutterImageCompress`,直接 sync 文件复制。
  /// 用于 iOS 后台 launch 场景 —— `FlutterImageCompress` 是 platform channel,
  /// 一旦 iOS 把 app 推到 background,channel 调用会被冻结,attachment 永远
  /// 保存不完。`File.copySync()` 是纯 Dart sync 调用,几十 ms 内必返回,不会
  /// 卡在 platform channel 上。代价是单张图占空间多(原图通常 2-3MB,压缩后
  /// 200-500KB),自动记账场景一般可接受。
  Future<TransactionAttachment?> saveAttachment({
    required int transactionId,
    required File sourceFile,
    required int index,
    bool urgent = false,
  }) async {
    try {
      final dir = await getAttachmentDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ext = path.extension(sourceFile.path).toLowerCase();
      final finalExt = ext.isEmpty ? '.jpg' : ext;
      final fileName = 'tx_${transactionId}_${timestamp}_$index$finalExt';
      final destPath = '${dir.path}/$fileName';

      final File savedFile;
      int? width;
      int? height;
      final int fileSize;
      if (urgent) {
        // 跳过压缩,sync copy。iOS background launch 状态下唯一可靠的写法。
        // 同时跳过 _getImageInfo:它走 ui.instantiateImageCodec 也是 platform
        // channel,后台冻结时也卡。width/height 留 null 不影响主功能。
        sourceFile.copySync(destPath);
        savedFile = File(destPath);
        fileSize = savedFile.lengthSync();
      } else {
        final compressedFile = await _compressImage(sourceFile, destPath);
        if (compressedFile == null) {
          logger.error('AttachmentService', '图片压缩失败');
          return null;
        }
        savedFile = compressedFile;
        final imageInfo = await _getImageInfo(savedFile.path);
        width = imageInfo?.width;
        height = imageInfo?.height;
        fileSize = await savedFile.length();
      }

      // 保存到数据库(Drift FFI,纯 Dart,不走 platform channel,不受冻结影响)
      final repo = ref.read(repositoryProvider);
      final id = await repo.createAttachment(
        transactionId: transactionId,
        fileName: fileName,
        originalName: path.basename(sourceFile.path),
        fileSize: fileSize,
        width: width,
        height: height,
        sortOrder: index,
      );

      logger.info('AttachmentService',
          '附件保存成功${urgent ? "(urgent/sync copy)" : ""}: $fileName');
      return repo.getAttachmentById(id);
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '保存附件失败', e, stackTrace);
      return null;
    }
  }

  /// 批量保存附件
  Future<List<TransactionAttachment>> saveAttachments({
    required int transactionId,
    required List<File> sourceFiles,
    int startIndex = 0,
  }) async {
    final results = <TransactionAttachment>[];
    for (int i = 0; i < sourceFiles.length; i++) {
      final attachment = await saveAttachment(
        transactionId: transactionId,
        sourceFile: sourceFiles[i],
        index: startIndex + i,
      );
      if (attachment != null) {
        results.add(attachment);
      }
    }
    return results;
  }

  /// 删除附件
  Future<void> deleteAttachment(int attachmentId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final attachment = await repo.getAttachmentById(attachmentId);

      if (attachment != null) {
        // 删除原图文件
        final dir = await getAttachmentDirectory();
        final file = File('${dir.path}/${attachment.fileName}');
        if (await file.exists()) {
          await file.delete();
          logger.debug('AttachmentService', '已删除原图: ${attachment.fileName}');
        }

        // 删除缩略图
        await _deleteThumbnail(attachment.fileName);

        // 删除数据库记录
        await repo.deleteAttachment(attachmentId);
        logger.info('AttachmentService', '附件删除成功: ${attachment.fileName}');
      }
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '删除附件失败', e, stackTrace);
    }
  }

  /// 删除交易的所有附件
  Future<void> deleteAttachmentsByTransaction(int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final attachments = await repo.getAttachmentsByTransaction(transactionId);

      for (final attachment in attachments) {
        // 删除原图文件
        final dir = await getAttachmentDirectory();
        final file = File('${dir.path}/${attachment.fileName}');
        if (await file.exists()) {
          await file.delete();
        }

        // 删除缩略图
        await _deleteThumbnail(attachment.fileName);
      }

      // 删除所有数据库记录
      await repo.deleteAttachmentsByTransaction(transactionId);
      logger.info('AttachmentService', '已删除交易 $transactionId 的所有附件');
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '删除交易附件失败', e, stackTrace);
    }
  }

  /// 获取附件文件路径
  Future<String> getAttachmentPath(String fileName) async {
    final dir = await getAttachmentDirectory();
    return '${dir.path}/$fileName';
  }

  /// 获取缩略图路径
  /// 如果缩略图不存在，会自动生成
  Future<String?> getThumbnailPath(String fileName) async {
    try {
      final thumbDir = await getThumbnailDirectory();
      final thumbName = '${path.basenameWithoutExtension(fileName)}_thumb.jpg';
      final thumbPath = '${thumbDir.path}/$thumbName';

      // 如果缩略图已存在，直接返回
      if (await File(thumbPath).exists()) {
        return thumbPath;
      }

      // 生成缩略图
      final attachmentDir = await getAttachmentDirectory();
      final sourcePath = '${attachmentDir.path}/$fileName';

      if (!await File(sourcePath).exists()) {
        logger.warning('AttachmentService', '原图不存在: $fileName');
        return null;
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        thumbPath,
        minWidth: thumbnailSize,
        minHeight: thumbnailSize,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        logger.debug('AttachmentService', '生成缩略图: $thumbName');
        return thumbPath;
      }

      return null;
    } catch (e) {
      logger.error('AttachmentService', '获取缩略图失败', e);
      return null;
    }
  }

  /// 清理孤立图片（数据库中没有记录的图片文件）
  Future<int> cleanOrphanedAttachments() async {
    try {
      final dir = await getAttachmentDirectory();
      final repo = ref.read(repositoryProvider);

      int deletedCount = 0;
      final files = dir.listSync().whereType<File>();

      for (final file in files) {
        final fileName = path.basename(file.path);
        final exists = await repo.attachmentExistsByFileName(fileName);

        if (!exists) {
          await file.delete();
          await _deleteThumbnail(fileName);
          deletedCount++;
          logger.debug('AttachmentService', '清理孤立图片: $fileName');
        }
      }

      if (deletedCount > 0) {
        logger.info('AttachmentService', '清理了 $deletedCount 个孤立图片');
      }

      return deletedCount;
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '清理孤立图片失败', e, stackTrace);
      return 0;
    }
  }

  /// 获取附件目录总大小（字节）
  Future<int> getAttachmentDirectorySize() async {
    try {
      final dir = await getAttachmentDirectory();
      int totalSize = 0;

      final files = dir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        totalSize += await file.length();
      }

      return totalSize;
    } catch (e) {
      logger.error('AttachmentService', '获取附件目录大小失败', e);
      return 0;
    }
  }

  // ============================================
  // 私有方法
  // ============================================

  /// 压缩图片
  Future<File?> _compressImage(File source, String targetPath) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        targetPath,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }

      // 如果压缩失败，直接复制原文件
      await source.copy(targetPath);
      return File(targetPath);
    } catch (e) {
      logger.error('AttachmentService', '压缩图片失败', e);
      // 尝试直接复制
      try {
        await source.copy(targetPath);
        return File(targetPath);
      } catch (copyError) {
        logger.error('AttachmentService', '复制图片也失败', copyError);
        return null;
      }
    }
  }

  /// 获取图片尺寸信息
  Future<({int width, int height})?> _getImageInfo(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      return (width: image.width, height: image.height);
    } catch (e) {
      logger.error('AttachmentService', '获取图片尺寸失败', e);
      return null;
    }
  }

  /// 删除缩略图
  Future<void> _deleteThumbnail(String fileName) async {
    try {
      final thumbDir = await getThumbnailDirectory();
      final thumbName = '${path.basenameWithoutExtension(fileName)}_thumb.jpg';
      final thumbFile = File('${thumbDir.path}/$thumbName');

      if (await thumbFile.exists()) {
        await thumbFile.delete();
        logger.debug('AttachmentService', '已删除缩略图: $thumbName');
      }
    } catch (e) {
      logger.error('AttachmentService', '删除缩略图失败', e);
    }
  }
}

/// AttachmentService Provider
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref);
});

/// 交易附件列表 Provider
final transactionAttachmentsProvider = StreamProvider.family<List<TransactionAttachment>, int>(
  (ref, transactionId) {
    final repo = ref.watch(repositoryProvider);
    return repo.watchAttachmentsByTransaction(transactionId);
  },
);

/// 附件列表刷新触发器
final attachmentListRefreshProvider = StateProvider<int>((ref) => 0);

/// 交易附件数量 Provider
final attachmentCountProvider = FutureProvider.family<int, int>(
  (ref, transactionId) async {
    ref.watch(attachmentListRefreshProvider);
    final repo = ref.read(repositoryProvider);
    return repo.getAttachmentCountByTransaction(transactionId);
  },
);

/// 批量获取交易附件数量 Provider
final attachmentCountsProvider = FutureProvider.family<Map<int, int>, List<int>>(
  (ref, transactionIds) async {
    if (transactionIds.isEmpty) return {};
    final repo = ref.read(repositoryProvider);
    return repo.getAttachmentCountsForTransactions(transactionIds);
  },
);
