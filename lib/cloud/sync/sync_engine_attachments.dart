part of 'sync_engine.dart';

/// 附件云端同步相关方法。
///
/// 包含上传 / 下载 / 本地磁盘清理 / 分类自定义图标上传等附件层 I/O 操作。
/// 这些方法不参与 sync 的高层编排,跟 push / pull / apply 解耦,所以独立成 part。
/// 主入口 [SyncEngine] 通过 extension 的方式承载,可以自由访问类的私有字段。
extension SyncEngineAttachmentsExt on SyncEngine {
  /// 清掉某账本下所有附件的 cloudFileId / cloudSha256。
  /// 用于"远端账本被重建/清空"的场景：本地以为文件在云上，实际已失效，
  /// 重置后下次 uploadAttachments 会把它们当新的重新上传。
  Future<void> _resetAttachmentCloudRefs(int ledgerId) async {
    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    if (txs.isEmpty) return;
    final txIds = txs.map((t) => t.id).toList();
    final count = await (db.update(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds)))
        .write(const TransactionAttachmentsCompanion(
      cloudFileId: d.Value(null),
      cloudSha256: d.Value(null),
    ));
    if (count > 0) {
      logger.info('SyncEngine', '已重置 $count 条附件的云端引用');
    }
  }

  /// 上传所有分类的自定义图标到云端，返回 categoryId → 云端引用 的映射。
  /// 分类的 customIconPath 是本地文件路径，单独上传后 serializeCategory 会把
  /// cloud 引用写进 payload 让 web 端能拉到。
  ///
  /// 走 user-global 的 `/attachments/category-icons/upload` endpoint,跟账本
  /// 解耦:相同 sha256 的图标全用户只上传 1 份(server 端按 user_id + sha256
  /// 去重),避免历史"每个账本各上传一份"的倍数膨胀。
  Future<Map<int, ({String fileId, String sha256})>>
      _uploadCategoryIcons() async {
    final categories = await db.select(db.categories).get();
    final out = <int, ({String fileId, String sha256})>{};
    final iconSvc = CustomIconService();
    for (final cat in categories) {
      if (cat.iconType != 'custom') continue;
      final rel = cat.customIconPath;
      if (rel == null || rel.isEmpty) continue;
      try {
        final abs = await iconSvc.resolveIconPath(rel);
        final file = File(abs);
        if (!file.existsSync()) {
          logger.debug('SyncEngine',
              '分类 ${cat.name} 的自定义图标文件不存在: $abs');
          continue;
        }
        final bytes = await file.readAsBytes();
        final result = await provider.uploadCategoryIcon(
          bytes: bytes,
          fileName: rel.split('/').last,
        );
        out[cat.id] = (fileId: result.fileId, sha256: result.sha256);
      } catch (e, st) {
        logger.error(
            'SyncEngine', '分类 ${cat.name} 自定义图标上传失败', e, st);
      }
    }
    if (out.isNotEmpty) {
      logger.info('SyncEngine', '分类自定义图标上传完成: ${out.length} 个');
    }
    return out;
  }

  /// 上传账本中未同步的附件到云端。
  ///
  /// Phase 3 改造:Semaphore(concurrency=4) 并发 + 指数退避 retry。
  /// 详见 `.docs/full-pull-refactor/`。
  Future<int> uploadAttachments({required int ledgerId}) async {
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final serverLedgerId = ledgerRow?.syncId ?? ledgerId.toString();

    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    if (txs.isEmpty) return 0;
    final txIds = txs.map((t) => t.id).toList();
    final atts = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds))
          ..where((a) => a.cloudFileId.isNull()))
        .get();
    if (atts.isEmpty) return 0;

    final pool = _AttachmentSemaphore(4);
    final results = await Future.wait(atts.map((att) async {
      await pool.acquire();
      try {
        return await _uploadOneWithRetry(att, serverLedgerId);
      } finally {
        pool.release();
      }
    }));
    final uploaded = results.where((r) => r).length;
    if (uploaded > 0) {
      logger.info('SyncEngine',
          '附件上传完成: $uploaded/${atts.length} (并发 4)');
    }
    return uploaded;
  }

  Future<bool> _uploadOneWithRetry(
      TransactionAttachment att, String serverLedgerId) async {
    final localFile = await _getAttachmentFile(att.fileName);
    if (localFile == null || !localFile.existsSync()) {
      logger.debug('SyncEngine', '附件本地文件不存在,跳过: ${att.fileName}');
      return false;
    }
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final bytes = await localFile.readAsBytes();
        final result = await provider.uploadAttachment(
          ledgerId: serverLedgerId,
          bytes: bytes,
          fileName: att.originalName ?? att.fileName,
        );
        await (db.update(db.transactionAttachments)
              ..where((a) => a.id.equals(att.id)))
            .write(TransactionAttachmentsCompanion(
          cloudFileId: d.Value(result.fileId),
          cloudSha256: d.Value(result.sha256),
        ));
        // 回填后给父 tx 登记 update change(详见旧 _legacyUploadAttachments 注释,
        // 防 "仅元数据" race)。
        final txRow = await (db.select(db.transactions)
              ..where((t) => t.id.equals(att.transactionId)))
            .getSingleOrNull();
        if (txRow?.syncId != null) {
          await changeTracker.recordLedgerChange(
            entityType: 'transaction',
            entityId: att.transactionId,
            entitySyncId: txRow!.syncId!,
            ledgerId: txRow.ledgerId,
            action: 'update',
          );
        }
        return true;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    logger.warning('SyncEngine',
        '附件上传失败 ${att.fileName} after 3 attempts: $lastError');
    return false;
  }

  /// 下载云端附件到本地。Phase 3:并发 + retry。
  Future<int> downloadAttachments({required int ledgerId}) async {
    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    if (txs.isEmpty) return 0;
    final txIds = txs.map((t) => t.id).toList();
    final atts = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds))
          ..where((a) => a.cloudFileId.isNotNull()))
        .get();
    if (atts.isEmpty) return 0;

    final pool = _AttachmentSemaphore(4);
    final results = await Future.wait(atts.map((att) async {
      await pool.acquire();
      try {
        return await _downloadOneWithRetry(att);
      } finally {
        pool.release();
      }
    }));
    final downloaded = results.where((r) => r).length;
    if (downloaded > 0) {
      logger.info('SyncEngine',
          '附件下载完成: $downloaded/${atts.length} (并发 4)');
    }
    return downloaded;
  }

  Future<bool> _downloadOneWithRetry(TransactionAttachment att) async {
    final localFile = await _getAttachmentFile(att.fileName);
    if (localFile == null) return false;
    if (localFile.existsSync()) return false;
    final cloudFileId = att.cloudFileId;
    if (cloudFileId == null) return false;
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final bytes = await provider.downloadAttachment(fileId: cloudFileId);
        final dir = localFile.parent;
        if (!dir.existsSync()) dir.createSync(recursive: true);
        await localFile.writeAsBytes(bytes);
        return true;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    logger.warning('SyncEngine',
        '附件下载失败 fileId=$cloudFileId after 3 attempts: $lastError');
    return false;
  }

  /// 处理 `_applyCategoryChange` 入队的自定义分类图标下载任务。
  /// 主事务 commit 之后由 [SyncEngine.pull] 调用。
  ///
  /// 失败的 job(`_downloadCustomIconWithRetry` 已重试 3 次)会**回到 queue**,
  /// 下一次 pull 触发 drain 时再尝试。这样网络抖动 / 限速场景下不会"图标
  /// 永久空"。
  Future<int> drainCustomIconQueue() async {
    if (pendingCustomIconJobs.isEmpty) return 0;
    final jobs = List<CustomIconDownloadJob>.from(pendingCustomIconJobs);
    pendingCustomIconJobs.clear();
    final pool = _AttachmentSemaphore(4);
    final failed = <CustomIconDownloadJob>[];
    final results = await Future.wait(jobs.map((job) async {
      await pool.acquire();
      try {
        final ok = await _downloadCustomIconWithRetry(job);
        if (!ok) failed.add(job);
        return ok;
      } finally {
        pool.release();
      }
    }));
    if (failed.isNotEmpty) {
      pendingCustomIconJobs.addAll(failed);
      logger.warning('SyncEngine',
          '自定义分类图标下载失败 ${failed.length}/${jobs.length},回 queue 等下次 drain 重试');
    }
    final ok = results.where((r) => r).length;
    if (ok > 0) {
      logger.info('SyncEngine', '自定义分类图标下载完成: $ok/${jobs.length}');
    }
    return ok;
  }

  Future<bool> _downloadCustomIconWithRetry(CustomIconDownloadJob job) async {
    final iconSvc = CustomIconService();
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final existing = await (db.select(db.categories)
              ..where((c) => c.id.equals(job.categoryId)))
            .getSingleOrNull();
        if (existing == null) return false;
        if ((existing.customIconPath ?? '').contains(job.cloudFileId)) {
          try {
            final abs = await iconSvc.resolveIconPath(existing.customIconPath!);
            if (await File(abs).exists()) return true;
          } catch (_) {}
        }
        final bytes = await provider.downloadAttachment(fileId: job.cloudFileId);
        final ext = _detectIconExtension(bytes, originalPath: job.expectedPath);
        final iconDir = await iconSvc.getIconDirectory();
        final safeName = '${job.cloudFileId.replaceAll('/', '_')}$ext';
        final absPath = '${iconDir.path}/$safeName';
        await File(absPath).writeAsBytes(bytes);
        final relPath = 'custom_icons/$safeName';
        await (db.update(db.categories)
              ..where((c) => c.id.equals(job.categoryId)))
            .write(CategoriesCompanion(customIconPath: d.Value(relPath)));
        return true;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    logger.warning('SyncEngine',
        '自定义图标下载失败 fileId=${job.cloudFileId}: $lastError');
    return false;
  }

  /// 获取附件本地文件路径
  Future<File?> _getAttachmentFile(String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentDir = Directory('${appDir.path}/attachments');
      return File('${attachmentDir.path}/$fileName');
    } catch (e) {
      logger.error('SyncEngine', '获取附件路径失败: $fileName', e);
      return null;
    }
  }

  /// 清理给定交易的本地磁盘附件(原图 + 缩略图)。在 transaction_attachments
  /// 行被 db.delete **之前** 调 —— 之后 fileName 就查不到了。
  ///
  /// 跟 `LocalTransactionRepository._deleteAttachmentsForTransaction` 几乎一样,
  /// 但那个是 private;这里是 sync pull 路径独立使用(不想走完整 repo 接口,
  /// 因为 repo 的 deleteTransaction 会 record changeTracker,会造成 pull →
  /// record → push 的回环)。失败只 warn 不抛,不 block 事件 apply。
  Future<void> _cleanupTxAttachmentFilesOnDisk(int transactionId) async {
    try {
      final attachments = await (db.select(db.transactionAttachments)
            ..where((a) => a.transactionId.equals(transactionId)))
          .get();
      if (attachments.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final attachmentDir = Directory('${appDir.path}/attachments');
      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory('${cacheDir.path}/attachment_thumbs');

      for (final att in attachments) {
        // 多笔共享同一物理文件:此处 DB 行尚未删(apply 在本函数之后才删行)，
        // 故排除本交易,看是否还有其他交易的行引用同 fileName,有就保留文件。
        final others = await (db.select(db.transactionAttachments)
              ..where((a) => a.fileName.equals(att.fileName))
              ..where((a) => a.transactionId.equals(transactionId).not()))
            .get();
        if (others.isNotEmpty) continue;

        final file = File('${attachmentDir.path}/${att.fileName}');
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            logger.warning('SyncEngine',
                'pull delete: unlink attachment failed ${att.fileName}: $e');
          }
        }
        final thumbName =
            '${p.basenameWithoutExtension(att.fileName)}_thumb.jpg';
        final thumbFile = File('${thumbDir.path}/$thumbName');
        if (await thumbFile.exists()) {
          try {
            await thumbFile.delete();
          } catch (_) {/* best effort */}
        }
      }
    } catch (e, st) {
      logger.warning(
          'SyncEngine', 'pull delete: 清理附件磁盘文件异常 tx=$transactionId: $e\n$st');
    }
  }

  /// 清理给定分类(含直接子分类)的本地自定义图标文件。
  /// 跟 LocalCategoryRepository 的 _deleteLocalIconFiles 对齐。删 categories
  /// 行之前调。best-effort。
  Future<void> _cleanupCategoryIconFilesOnDisk(List<int> categoryIds) async {
    if (categoryIds.isEmpty) return;
    try {
      final paths = <String>[];
      final selfRows = await (db.select(db.categories)
            ..where((c) => c.id.isIn(categoryIds)))
          .get();
      for (final r in selfRows) {
        final cp = r.customIconPath;
        if (cp != null && cp.trim().isNotEmpty) paths.add(cp);
      }
      final childRows = await (db.select(db.categories)
            ..where((c) => c.parentId.isIn(categoryIds)))
          .get();
      for (final r in childRows) {
        final cp = r.customIconPath;
        if (cp != null && cp.trim().isNotEmpty) paths.add(cp);
      }
      if (paths.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${appDir.path}/custom_icons');
      for (final rel in paths) {
        final fileName = p.basename(rel);
        final file = File('${iconDir.path}/$fileName');
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            logger.warning(
                'SyncEngine', 'pull delete: unlink custom icon failed $fileName: $e');
          }
        }
      }
    } catch (e, st) {
      logger.warning('SyncEngine', 'pull delete: 清理分类图标磁盘文件异常: $e\n$st');
    }
  }
}

/// 并发限流。本 library 内私有,只在附件上传/下载时用。
class _AttachmentSemaphore {
  _AttachmentSemaphore(int limit) : _available = limit;
  int _available;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    if (_available > 0) {
      _available--;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _available++;
    }
  }
}

/// 探测自定义分类图标的扩展名,保证本地落地文件名能被正确识别为图片。
///
/// 优先级:
///   1. originalPath 末尾的扩展名(payload.customIconPath 来自上游 saveCustomIcon
///      生成的 `<id>_<ts>.png` 规范名)
///   2. bytes 前几个 magic bytes:
///      - PNG: `89 50 4E 47 0D 0A 1A 0A`
///      - JPEG: `FF D8 FF`
///      - WebP: `52 49 46 46 .. .. .. .. 57 45 42 50` (RIFF....WEBP)
///   3. fallback `.png`
String _detectIconExtension(List<int> bytes, {String? originalPath}) {
  if (originalPath != null && originalPath.isNotEmpty) {
    final dot = originalPath.lastIndexOf('.');
    if (dot >= 0 && dot < originalPath.length - 1) {
      final ext = originalPath.substring(dot).toLowerCase();
      if (ext.length <= 6 && RegExp(r'^\.[a-z0-9]+$').hasMatch(ext)) return ext;
    }
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return '.png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return '.jpg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return '.webp';
  }
  return '.png';
}
