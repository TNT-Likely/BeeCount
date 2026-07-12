import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../providers.dart';
import 'attachment_service.dart';
import 'custom_icon_service.dart';
import 'system/logger_service.dart';
import 'ui/avatar_service.dart';

/// 附件导出导入服务
/// 负责附件的打包导出和解压导入
class AttachmentExportImportService {
  final Ref ref;

  AttachmentExportImportService(this.ref);

  // ============================================
  // 导出功能
  // ============================================

  /// 导出所有附件为 tar.gz 文件
  /// 返回导出文件的路径
  Future<String?> exportAttachments({
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      final repo = ref.read(repositoryProvider);
      final attachmentService = ref.read(attachmentServiceProvider);
      final attachmentDir = await attachmentService.getAttachmentDirectory();

      // 获取所有附件记录
      final allAttachments = await repo.getAllAttachments();

      // 检查头像
      final avatarPath = await AvatarService.getAvatarPath();
      String? avatarFileName;
      File? avatarFile;
      if (avatarPath != null) {
        avatarFile = File(avatarPath);
        if (await avatarFile.exists()) {
          avatarFileName = path.basename(avatarPath);
        } else {
          avatarFile = null;
        }
      }

      // 检查自定义图标
      final customIconService = CustomIconService();
      final customIconDir = await customIconService.getIconDirectory();
      final customIconFiles = <File>[];
      if (await customIconDir.exists()) {
        final entities = customIconDir.listSync();
        for (final entity in entities) {
          if (entity is File &&
              (entity.path.endsWith('.png') ||
                  entity.path.endsWith('.jpg') ||
                  entity.path.endsWith('.jpeg'))) {
            customIconFiles.add(entity);
          }
        }
      }

      // 先扫描实际存在的附件文件
      final existingAttachmentFiles = <File>[];
      for (final attachment in allAttachments) {
        final filePath = '${attachmentDir.path}/${attachment.fileName}';
        final file = File(filePath);
        if (await file.exists()) {
          existingAttachmentFiles.add(file);
        }
      }

      // 如果没有实际文件、头像和自定义图标，则无需导出
      if (existingAttachmentFiles.isEmpty &&
          avatarFile == null &&
          customIconFiles.isEmpty) {
        logger.info('AttachmentExportImport',
            '没有实际文件需要导出（数据库记录: ${allAttachments.length}，实际文件: 0）');
        return null;
      }

      // 创建归档
      final archive = Archive();

      // 添加头像文件（如果存在）
      if (avatarFile != null && avatarFileName != null) {
        final bytes = await avatarFile.readAsBytes();
        archive.addFile(ArchiveFile(
          'avatar/$avatarFileName',
          bytes.length,
          bytes,
        ));
        logger.debug('AttachmentExportImport', '添加头像文件: $avatarFileName');
      }

      // 构建实际存在的附件列表（复用前面扫描的结果）
      final existingAttachments = <TransactionAttachment>[];
      for (final attachment in allAttachments) {
        final filePath = '${attachmentDir.path}/${attachment.fileName}';
        if (existingAttachmentFiles.any((f) => f.path == filePath)) {
          existingAttachments.add(attachment);
        }
      }

      logger.info('AttachmentExportImport',
          '数据库中有 ${allAttachments.length} 条附件记录，实际存在 ${existingAttachments.length} 个文件，自定义图标 ${customIconFiles.length} 个');

      // 添加元数据文件（先构建，但稍后再填充自定义图标列表）
      final customIconFileNames = <String>[];

      // 计算总文件数（附件 + 自定义图标）
      int processed = 0;
      final total = existingAttachments.length + customIconFiles.length;

      // 先添加自定义图标文件
      for (final iconFile in customIconFiles) {
        final fileName = path.basename(iconFile.path);
        final bytes = await iconFile.readAsBytes();
        archive.addFile(ArchiveFile(
          'custom_icons/$fileName',
          bytes.length,
          bytes,
        ));
        customIconFileNames.add(fileName);
        logger.debug('AttachmentExportImport', '添加自定义图标: $fileName');

        processed++;
        onProgress?.call(processed, total);
      }

      // 添加元数据文件
      final metadata = _buildMetadata(
        existingAttachments,
        avatarFileName: avatarFileName,
        customIconFileNames:
            customIconFileNames.isEmpty ? null : customIconFileNames,
      );
      final metadataBytes = utf8.encode(jsonEncode(metadata));
      archive.addFile(ArchiveFile(
        'metadata.json',
        metadataBytes.length,
        metadataBytes,
      ));

      // 添加实际存在的附件图片文件
      for (final attachment in existingAttachments) {
        final filePath = '${attachmentDir.path}/${attachment.fileName}';
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(
          'images/${attachment.fileName}',
          bytes.length,
          bytes,
        ));

        processed++;
        onProgress?.call(processed, total);
      }

      // 压缩为 tar.gz
      final tarData = TarEncoder().encode(archive);
      final gzData = GZipEncoder().encode(tarData);

      if (gzData == null) {
        logger.error('AttachmentExportImport', 'GZip 压缩失败');
        return null;
      }

      // 保存到临时目录
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportDir = await _getExportDirectory();
      final exportPath =
          '${exportDir.path}/beecount_attachments_$timestamp.tar.gz';

      final exportFile = File(exportPath);
      await exportFile.writeAsBytes(gzData);

      logger.info('AttachmentExportImport', '附件导出完成: $exportPath');
      return exportPath;
    } catch (e, stackTrace) {
      logger.error('AttachmentExportImport', '导出附件失败', e, stackTrace);
      return null;
    }
  }

  /// 构建元数据
  Map<String, dynamic> _buildMetadata(
    List<TransactionAttachment> attachments, {
    String? avatarFileName,
    List<String>? customIconFileNames,
  }) {
    final metadata = <String, dynamic>{
      'version': 3, // 升级版本号以支持自定义图标
      'exportedAt': DateTime.now().toIso8601String(),
      'count': attachments.length,
      'attachments': attachments
          .map((a) => {
                'id': a.id,
                'transactionId': a.transactionId,
                'fileName': a.fileName,
                'originalName': a.originalName,
                'fileSize': a.fileSize,
                'width': a.width,
                'height': a.height,
                'sortOrder': a.sortOrder,
                'createdAt': a.createdAt.toIso8601String(),
              })
          .toList(),
    };

    // 添加头像信息（如果存在）
    if (avatarFileName != null) {
      metadata['avatar'] = avatarFileName;
    }

    // 添加自定义图标列表（如果存在）
    if (customIconFileNames != null && customIconFileNames.isNotEmpty) {
      metadata['customIcons'] = customIconFileNames;
    }

    return metadata;
  }

  // ============================================
  // 导入功能
  // ============================================

  /// 冲突处理策略
  static const String conflictSkip = 'skip';
  static const String conflictOverwrite = 'overwrite';

  /// 导入附件
  /// [archivePath] tar.gz 文件路径
  /// [conflictStrategy] 冲突策略: 'skip' 或 'overwrite'
  /// 返回导入结果
  Future<AttachmentImportResult> importAttachments({
    required String archivePath,
    required String conflictStrategy,
    void Function(int current, int total)? onProgress,
  }) async {
    int imported = 0;
    int skipped = 0;
    int failed = 0;
    int overwritten = 0;

    try {
      final repo = ref.read(repositoryProvider);
      final attachmentService = ref.read(attachmentServiceProvider);
      final attachmentDir = await attachmentService.getAttachmentDirectory();

      // 读取归档文件
      final archiveFile = File(archivePath);
      if (!await archiveFile.exists()) {
        logger.error('AttachmentExportImport', '归档文件不存在: $archivePath');
        return AttachmentImportResult(
          success: false,
          imported: 0,
          skipped: 0,
          failed: 0,
          overwritten: 0,
          message: '归档文件不存在',
        );
      }

      final bytes = await archiveFile.readAsBytes();

      // 解压 gzip
      final tarData = GZipDecoder().decodeBytes(bytes);

      // 解析 tar
      final archive = TarDecoder().decodeBytes(tarData);

      // 查找元数据文件
      ArchiveFile? metadataFile;
      for (final file in archive) {
        if (file.name == 'metadata.json') {
          metadataFile = file;
          break;
        }
      }

      if (metadataFile == null) {
        logger.error('AttachmentExportImport', '归档中没有找到 metadata.json');
        return AttachmentImportResult(
          success: false,
          imported: 0,
          skipped: 0,
          failed: 0,
          overwritten: 0,
          message: '归档格式错误：缺少 metadata.json',
        );
      }

      // 解析元数据
      final metadataJson = utf8.decode(metadataFile.content as List<int>);
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      final attachmentList = metadata['attachments'] as List<dynamic>;

      final total = attachmentList.length;
      int processed = 0;

      // 构建文件名到归档文件的映射
      final imageFiles = <String, ArchiveFile>{};
      for (final file in archive) {
        if (file.name.startsWith('images/')) {
          final fileName = path.basename(file.name);
          imageFiles[fileName] = file;
        }
      }

      // 处理每个附件
      for (final attachmentData in attachmentList) {
        final fileName = attachmentData['fileName'] as String;
        final transactionId = attachmentData['transactionId'] as int;

        try {
          // 注意：不检查交易是否存在，因为：
          // 1. 可能先导入附件，后导入交易数据
          // 2. 可能从远端恢复数据后再导入附件
          // 附件的 transactionId 仅作为元数据保存，后续可通过文件名匹配

          // 检查文件是否存在于归档中
          final imageFile = imageFiles[fileName];
          if (imageFile == null) {
            logger.warning('AttachmentExportImport', '归档中没有找到图片: $fileName');
            failed++;
            processed++;
            onProgress?.call(processed, total);
            continue;
          }

          // 检查本地是否已存在同名文件
          final localFilePath = '${attachmentDir.path}/$fileName';
          final localFile = File(localFilePath);
          final existsLocally = await localFile.exists();

          // 检查数据库中是否存在记录
          final existsInDb = await repo.attachmentExistsByFileName(fileName);

          if (existsLocally || existsInDb) {
            if (conflictStrategy == conflictSkip) {
              logger.debug('AttachmentExportImport', '跳过已存在的附件: $fileName');
              skipped++;
              processed++;
              onProgress?.call(processed, total);
              continue;
            } else {
              // 覆盖模式：删除旧文件和记录
              if (existsLocally) {
                await localFile.delete();
              }
              if (existsInDb) {
                await repo.deleteAttachmentByFileName(fileName);
              }
              overwritten++;
            }
          }

          // 保存图片文件
          await localFile.writeAsBytes(imageFile.content as List<int>);

          // 创建数据库记录
          await repo.createAttachment(
            transactionId: transactionId,
            fileName: fileName,
            originalName: attachmentData['originalName'] as String? ?? fileName,
            fileSize: attachmentData['fileSize'] as int? ?? imageFile.size,
            width: attachmentData['width'] as int?,
            height: attachmentData['height'] as int?,
            sortOrder: attachmentData['sortOrder'] as int? ?? 0,
          );

          imported++;
        } catch (e) {
          logger.error('AttachmentExportImport', '导入附件失败: $fileName', e);
          failed++;
        }

        processed++;
        onProgress?.call(processed, total);
      }

      // 处理头像导入（如果存在）
      bool avatarImported = false;
      final avatarFileName = metadata['avatar'] as String?;
      if (avatarFileName != null) {
        // 查找头像文件
        ArchiveFile? avatarFile;
        for (final file in archive) {
          if (file.name == 'avatar/$avatarFileName') {
            avatarFile = file;
            break;
          }
        }

        if (avatarFile != null) {
          try {
            // 获取应用文档目录
            final appDir = await getApplicationDocumentsDirectory();
            final avatarDir = Directory(path.join(appDir.path, 'avatars'));
            if (!await avatarDir.exists()) {
              await avatarDir.create(recursive: true);
            }

            // 检查是否需要覆盖
            final localAvatarPath = path.join(avatarDir.path, avatarFileName);
            final localAvatarFile = File(localAvatarPath);

            if (await localAvatarFile.exists()) {
              if (conflictStrategy == conflictOverwrite) {
                await localAvatarFile.delete();
              } else {
                logger.debug(
                    'AttachmentExportImport', '跳过已存在的头像: $avatarFileName');
              }
            }

            // 保存头像文件
            if (!await localAvatarFile.exists()) {
              await localAvatarFile
                  .writeAsBytes(avatarFile.content as List<int>);

              // 更新 SharedPreferences 中的头像路径
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'user_avatar_path', 'avatars/$avatarFileName');

              avatarImported = true;
              logger.info('AttachmentExportImport', '头像已导入: $avatarFileName');
            }
          } catch (e) {
            logger.error(
                'AttachmentExportImport', '导入头像失败: $avatarFileName', e);
          }
        }
      }

      // 处理自定义图标导入（如果存在）
      int customIconsImported = 0;
      int customIconsSkipped = 0;
      final customIconFileNames = metadata['customIcons'] as List<dynamic>?;
      if (customIconFileNames != null && customIconFileNames.isNotEmpty) {
        // 获取自定义图标目录
        final customIconService = CustomIconService();
        final customIconDir = await customIconService.getIconDirectory();
        if (!await customIconDir.exists()) {
          await customIconDir.create(recursive: true);
        }

        // 构建文件名到归档文件的映射
        final customIconArchiveFiles = <String, ArchiveFile>{};
        for (final file in archive) {
          if (file.name.startsWith('custom_icons/')) {
            final fileName = path.basename(file.name);
            customIconArchiveFiles[fileName] = file;
          }
        }

        // 导入每个自定义图标
        for (final iconFileName in customIconFileNames) {
          try {
            final fileName = iconFileName as String;
            final archiveFile = customIconArchiveFiles[fileName];

            if (archiveFile == null) {
              logger.warning(
                  'AttachmentExportImport', '归档中没有找到自定义图标: $fileName');
              continue;
            }

            // 检查本地是否已存在同名文件
            final localIconPath = path.join(customIconDir.path, fileName);
            final localIconFile = File(localIconPath);

            if (await localIconFile.exists()) {
              if (conflictStrategy == conflictOverwrite) {
                await localIconFile.delete();
                await localIconFile
                    .writeAsBytes(archiveFile.content as List<int>);
                customIconsImported++;
                logger.debug('AttachmentExportImport', '覆盖自定义图标: $fileName');
              } else {
                customIconsSkipped++;
                logger.debug(
                    'AttachmentExportImport', '跳过已存在的自定义图标: $fileName');
              }
            } else {
              await localIconFile
                  .writeAsBytes(archiveFile.content as List<int>);
              customIconsImported++;
              logger.debug('AttachmentExportImport', '导入自定义图标: $fileName');
            }
          } catch (e) {
            logger.error(
                'AttachmentExportImport', '导入自定义图标失败: $iconFileName', e);
          }
        }
      }

      logger.info('AttachmentExportImport',
          '附件导入完成: 导入 $imported, 跳过 $skipped, 覆盖 $overwritten, 失败 $failed${avatarImported ? ', 头像已导入' : ''}${customIconsImported > 0 ? ', 自定义图标已导入 $customIconsImported' : ''}${customIconsSkipped > 0 ? ', 自定义图标已跳过 $customIconsSkipped' : ''}');

      return AttachmentImportResult(
        success: true,
        imported: imported,
        skipped: skipped,
        failed: failed,
        overwritten: overwritten,
        avatarImported: avatarImported,
        customIconsImported: customIconsImported,
        customIconsSkipped: customIconsSkipped,
        message: null,
      );
    } catch (e, stackTrace) {
      logger.error('AttachmentExportImport', '导入附件失败', e, stackTrace);
      return AttachmentImportResult(
        success: false,
        imported: imported,
        skipped: skipped,
        failed: failed,
        overwritten: overwritten,
        message: e.toString(),
      );
    }
  }

  /// 获取即将导出的附件和自定义图标预览列表
  /// 返回本地文件列表（包括附件和自定义图标）
  Future<ExportPreviewData> getExportPreviewImages() async {
    try {
      final attachmentService = ref.read(attachmentServiceProvider);
      final attachmentDir = await attachmentService.getAttachmentDirectory();
      final repo = ref.read(repositoryProvider);
      final allAttachments = await repo.getAllAttachments();

      logger.debug('AttachmentExportImport',
          '获取预览：附件目录=${attachmentDir.path}, 数据库附件数=${allAttachments.length}');

      // 1. 获取附件文件
      final attachmentFiles = <File>[];
      if (await attachmentDir.exists()) {
        final actualFiles = attachmentDir.listSync();
        logger.debug(
            'AttachmentExportImport', '附件目录中实际有 ${actualFiles.length} 个文件/文件夹');
        for (final entity in actualFiles) {
          if (entity is File && _isImageFile(entity.path)) {
            attachmentFiles.add(entity);
            logger.debug('AttachmentExportImport',
                '附件文件: ${path.basename(entity.path)}');
          }
        }
      } else {
        logger.warning('AttachmentExportImport', '附件目录不存在！');
      }

      // 2. 获取自定义图标文件
      final customIconService = CustomIconService();
      final customIconDir = await customIconService.getIconDirectory();
      final customIconFiles = <File>[];

      if (await customIconDir.exists()) {
        final iconEntities = customIconDir.listSync();
        logger.debug('AttachmentExportImport',
            '自定义图标目录中有 ${iconEntities.length} 个文件/文件夹');
        for (final entity in iconEntities) {
          if (entity is File && _isImageFile(entity.path)) {
            customIconFiles.add(entity);
            logger.debug('AttachmentExportImport',
                '自定义图标: ${path.basename(entity.path)}');
          }
        }
      }

      logger.info('AttachmentExportImport',
          '导出预览找到 ${attachmentFiles.length} 个附件，${customIconFiles.length} 个自定义图标');

      // 打印所有将要导出的文件
      logger.info('AttachmentExportImport', '===== 导出文件列表 =====');
      logger.info(
          'AttachmentExportImport', '附件文件 (${attachmentFiles.length} 个):');
      for (final file in attachmentFiles) {
        logger.info(
            'AttachmentExportImport', '  - ${path.basename(file.path)}');
      }
      logger.info(
          'AttachmentExportImport', '自定义图标 (${customIconFiles.length} 个):');
      for (final file in customIconFiles) {
        logger.info(
            'AttachmentExportImport', '  - ${path.basename(file.path)}');
      }
      logger.info('AttachmentExportImport', '========================');

      return ExportPreviewData(
        attachments: attachmentFiles,
        customIcons: customIconFiles,
      );
    } catch (e, stackTrace) {
      logger.error('AttachmentExportImport', '获取导出预览图片失败', e, stackTrace);
      return ExportPreviewData(attachments: [], customIcons: []);
    }
  }

  /// 判断是否为图片文件
  bool _isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.png' ||
        ext == '.gif' ||
        ext == '.webp';
  }

  /// 从归档中提取图片用于预览（包括附件和自定义图标）
  /// 返回图片数据列表（文件名和字节数据）
  Future<ArchivePreviewData> getArchivePreviewImages(String archivePath) async {
    try {
      final archiveFile = File(archivePath);
      if (!await archiveFile.exists()) {
        logger.warning('AttachmentExportImport', '归档文件不存在: $archivePath');
        return ArchivePreviewData(attachments: [], customIcons: []);
      }

      logger.info('AttachmentExportImport', '开始解析归档文件: $archivePath');
      final bytes = await archiveFile.readAsBytes();
      final tarData = GZipDecoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(tarData);

      logger.debug('AttachmentExportImport', '归档中共有 ${archive.length} 个文件');
      final attachmentItems = <AttachmentPreviewItem>[];
      final customIconItems = <AttachmentPreviewItem>[];

      // 提取所有图片文件
      for (final file in archive) {
        logger.debug('AttachmentExportImport', '归档文件: ${file.name}');

        // 附件图片（images/ 目录）
        if (file.name.startsWith('images/')) {
          final fileName = path.basename(file.name);
          final imageBytes = file.content as List<int>;
          attachmentItems.add(AttachmentPreviewItem(
            fileName: fileName,
            bytes: Uint8List.fromList(imageBytes),
          ));
          logger.debug('AttachmentExportImport', '添加附件预览: $fileName');
        }

        // 自定义图标（custom_icons/ 目录）
        else if (file.name.startsWith('custom_icons/')) {
          final fileName = path.basename(file.name);
          final imageBytes = file.content as List<int>;
          customIconItems.add(AttachmentPreviewItem(
            fileName: fileName,
            bytes: Uint8List.fromList(imageBytes),
          ));
          logger.debug('AttachmentExportImport', '添加自定义图标预览: $fileName');
        }
      }

      logger.info('AttachmentExportImport',
          '导入预览找到 ${attachmentItems.length} 个附件，${customIconItems.length} 个自定义图标');
      return ArchivePreviewData(
        attachments: attachmentItems,
        customIcons: customIconItems,
      );
    } catch (e, stackTrace) {
      logger.error('AttachmentExportImport', '获取归档预览图片失败', e, stackTrace);
      return ArchivePreviewData(attachments: [], customIcons: []);
    }
  }

  /// 预览归档内容
  /// 返回归档中的元数据信息
  Future<AttachmentArchiveInfo?> previewArchive(String archivePath) async {
    try {
      final archiveFile = File(archivePath);
      if (!await archiveFile.exists()) {
        return null;
      }

      final bytes = await archiveFile.readAsBytes();
      final tarData = GZipDecoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(tarData);

      // 查找元数据文件
      for (final file in archive) {
        if (file.name == 'metadata.json') {
          final metadataJson = utf8.decode(file.content as List<int>);
          final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

          final customIcons = metadata['customIcons'] as List<dynamic>?;

          return AttachmentArchiveInfo(
            version: metadata['version'] as int? ?? 1,
            exportedAt:
                DateTime.tryParse(metadata['exportedAt'] as String? ?? ''),
            count: metadata['count'] as int? ?? 0,
            fileSize: await archiveFile.length(),
            hasAvatar: metadata['avatar'] != null,
            customIconCount: customIcons?.length ?? 0,
          );
        }
      }

      return null;
    } catch (e) {
      logger.error('AttachmentExportImport', '预览归档失败', e);
      return null;
    }
  }

  /// 获取导出目录
  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // Android: 使用公共下载目录
      final dir = Directory('/storage/emulated/0/Download/BeeCount');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else {
      // iOS: 使用文档目录
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/exports');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }
}

/// 附件导入结果
class AttachmentImportResult {
  final bool success;
  final int imported;
  final int skipped;
  final int failed;
  final int overwritten;
  final bool avatarImported;
  final int customIconsImported;
  final int customIconsSkipped;
  final String? message;

  AttachmentImportResult({
    required this.success,
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.overwritten,
    this.avatarImported = false,
    this.customIconsImported = 0,
    this.customIconsSkipped = 0,
    this.message,
  });
}

/// 归档信息
class AttachmentArchiveInfo {
  final int version;
  final DateTime? exportedAt;
  final int count;
  final int fileSize;
  final bool hasAvatar;
  final int customIconCount;

  AttachmentArchiveInfo({
    required this.version,
    this.exportedAt,
    required this.count,
    required this.fileSize,
    this.hasAvatar = false,
    this.customIconCount = 0,
  });
}

/// 附件预览项
class AttachmentPreviewItem {
  final String fileName;
  final Uint8List bytes;

  AttachmentPreviewItem({
    required this.fileName,
    required this.bytes,
  });
}

/// 导出预览数据（本地文件）
class ExportPreviewData {
  final List<File> attachments; // 附件文件
  final List<File> customIcons; // 自定义图标文件

  ExportPreviewData({
    required this.attachments,
    required this.customIcons,
  });

  int get totalCount => attachments.length + customIcons.length;

  bool get isEmpty => totalCount == 0;
}

/// 归档预览数据（从tar.gz中提取）
class ArchivePreviewData {
  final List<AttachmentPreviewItem> attachments; // 附件数据
  final List<AttachmentPreviewItem> customIcons; // 自定义图标数据

  ArchivePreviewData({
    required this.attachments,
    required this.customIcons,
  });

  int get totalCount => attachments.length + customIcons.length;

  bool get isEmpty => totalCount == 0;
}

/// Provider
final attachmentExportImportServiceProvider =
    Provider<AttachmentExportImportService>((ref) {
  return AttachmentExportImportService(ref);
});
