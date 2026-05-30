import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
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
      final ext = path.extension(sourceFile.path).toLowerCase();
      final finalExt = ext.isEmpty ? '.jpg' : ext;

      // 按内容 sha256 命名:多笔/多次记账用到同一张图时复用同一物理文件,
      // 不再每笔复制一份(配合删除处的引用计数,避免误删共享文件)。
      final String fileName;
      final File savedFile;
      int? width;
      int? height;
      final int fileSize;
      if (urgent) {
        // 跳过压缩,sync copy。iOS background launch 状态下唯一可靠的写法。
        // 同时跳过 _getImageInfo:它走 ui.instantiateImageCodec 也是 platform
        // channel,后台冻结时也卡。width/height 留 null 不影响主功能。
        final bytes = sourceFile.readAsBytesSync();
        fileName = 'sha_${sha256.convert(bytes)}$finalExt';
        final destPath = '${dir.path}/$fileName';
        savedFile = File(destPath);
        if (!savedFile.existsSync()) {
          sourceFile.copySync(destPath);
        }
        fileSize = savedFile.lengthSync();
      } else {
        // 先压缩到临时文件,再按压缩后内容 sha256 命名(同图去重)
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final tempPath = '${dir.path}/_tmp_${timestamp}_$index$finalExt';
        final compressedFile = await _compressImage(sourceFile, tempPath);
        if (compressedFile == null) {
          logger.error('AttachmentService', '图片压缩失败');
          return null;
        }
        final bytes = await compressedFile.readAsBytes();
        fileName = 'sha_${sha256.convert(bytes)}$finalExt';
        final destPath = '${dir.path}/$fileName';
        if (await File(destPath).exists()) {
          await compressedFile.delete();
        } else {
          await compressedFile.rename(destPath);
        }
        savedFile = File(destPath);
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
        // 先删数据库记录,再按引用计数删物理文件(多笔/多次共享同一文件时,
        // 仅当没有其他行引用该 fileName 才删物理文件)
        await repo.deleteAttachment(attachmentId);
        await _deletePhysicalFileIfUnreferenced(attachment.fileName);
        logger.info('AttachmentService', '附件删除成功: ${attachment.fileName}');
      }
    } catch (e, stackTrace) {
      logger.error('AttachmentService', '删除附件失败', e, stackTrace);
    }
  }

  /// 引用计数删物理文件:仅当没有其他 transaction_attachments 行引用该 fileName
  /// 时才删物理文件 + 缩略图。多笔/多次共享同一张图时避免误删。
  Future<void> _deletePhysicalFileIfUnreferenced(String fileName) async {
    final repo = ref.read(repositoryProvider);
    final refCount = await repo.countAttachmentsByFileName(fileName);
    if (refCount > 0) return; // 仍有其他行引用,保留物理文件
    final dir = await getAttachmentDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
      logger.debug('AttachmentService', '已删除原图: $fileName');
    }
    await _deleteThumbnail(fileName);
  }

  /// 对一组 fileName 逐个按引用计数删物理文件(清空/删账本后,精准清理该账本
  /// 关联的附件文件;其他账本/交易仍引用同一 fileName 的不会被删)。
  Future<void> deletePhysicalFilesIfUnreferenced(Iterable<String> fileNames) async {
    for (final fileName in fileNames) {
      await _deletePhysicalFileIfUnreferenced(fileName);
    }
  }

  /// 删除交易的所有附件
  Future<void> deleteAttachmentsByTransaction(int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final attachments = await repo.getAttachmentsByTransaction(transactionId);
      final fileNames = attachments.map((a) => a.fileName).toSet();

      // 先删数据库记录,再逐个按引用计数删物理文件
      await repo.deleteAttachmentsByTransaction(transactionId);
      for (final fileName in fileNames) {
        await _deletePhysicalFileIfUnreferenced(fileName);
      }
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
