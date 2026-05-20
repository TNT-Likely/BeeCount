/// 本地孤儿数据清理 — 数据模型。
///
/// `OrphanScanner` 扫出来的每条异常对应一个 `OrphanRecord`。`OrphanCleaner`
/// 接 List<OrphanRecord> 按 `type` dispatch 到具体删除分支。UI 层按 type
/// 分组显示、按 record 勾选。
///
/// type 枚举跟 plan 文件里的 A1..A10 / B1..B3 / C1 一一对应,后续加新检测
/// 项只需扩枚举 + scanner / cleaner 各加一个 case。
library;

/// 孤儿数据类型,跟 plan 检测清单对齐。
enum OrphanType {
  /// A1 预算指向已删账本
  budgetMissingLedger,

  /// A2 附件行指向已删交易
  attachmentMissingTx,

  /// A3 tag 关联指向已删交易
  txTagMissingTx,

  /// A4 tag 关联指向已删标签
  txTagMissingTag,

  /// A5 交易的 account_id / to_account_id 失主
  txMissingAccount,

  /// A6 交易的 category_id 失主
  txMissingCategory,

  /// A7 二级分类失父
  categoryMissingParent,

  /// A8 预算分类失主
  budgetMissingCategory,

  /// A9 共享二级分类失父
  sharedCategoryMissingParent,

  /// A10 TransactionTagOverrides 失主交易
  txTagOverrideMissingTx,

  /// B1 附件原图无引用
  fileOrphanAttachment,

  /// B2 分类自定义图标无引用
  fileOrphanCustomIcon,

  /// B3 共享分类图标缓存无引用
  fileOrphanSharedIcon,

  /// C1 local_changes 失主实体
  localChangeMissingEntity,
}

/// 单条孤儿数据。
///
/// - DB 类(A/C):`localId` 或 `syncId` 至少一个非空,`filePath`/`sizeBytes` null
/// - 文件类(B):`filePath` 非空,`sizeBytes` 有值,`localId`/`syncId` null
class OrphanRecord {
  const OrphanRecord({
    required this.type,
    required this.title,
    required this.subtitle,
    this.localId,
    this.syncId,
    this.filePath,
    this.sizeBytes,
    this.extra,
  });

  final OrphanType type;

  /// UI 主标题,e.g. "预算 #5"
  final String title;

  /// UI 副标题,e.g. "金额 ¥3000 · 账本已删 (ledgerId=2)"
  final String subtitle;

  /// 主表行 id(B 类是 null)。cleaner 按 type + localId 删 DB 行。
  final int? localId;

  /// 实体 syncId(部分类型有)。C1 用 syncId 定位 local_changes 行。
  final String? syncId;

  /// 文件绝对路径(仅 B 类)。cleaner 直接 File(path).delete()。
  final String? filePath;

  /// 文件大小 bytes(仅 B 类)。UI 显示用。
  final int? sizeBytes;

  /// 类型专属附加 payload(不必序列化),cleaner 内部用。
  /// 例:txTagMissingTx 携带 txId 用于复用主表更新逻辑。
  final Map<String, Object?>? extra;

  /// 稳定的唯一标识 — UI 给 ListView key + 勾选集合用。
  String get uniqueKey {
    final id = localId ?? syncId ?? filePath ?? '';
    return '${type.name}:$id';
  }
}

/// 孤儿数据按 group 聚合结果。UI 用三组 SectionCard 渲染。
class OrphanScanReport {
  const OrphanScanReport({
    required this.dbOrphans,
    required this.fileOrphans,
    required this.syncOrphans,
  });

  /// A1..A10
  final List<OrphanRecord> dbOrphans;

  /// B1..B3
  final List<OrphanRecord> fileOrphans;

  /// C1
  final List<OrphanRecord> syncOrphans;

  int get totalCount =>
      dbOrphans.length + fileOrphans.length + syncOrphans.length;

  int get totalSizeBytes => fileOrphans.fold<int>(
      0, (sum, r) => sum + (r.sizeBytes ?? 0));

  Iterable<OrphanRecord> get all sync* {
    yield* dbOrphans;
    yield* fileOrphans;
    yield* syncOrphans;
  }

  static const empty = OrphanScanReport(
    dbOrphans: [],
    fileOrphans: [],
    syncOrphans: [],
  );
}

/// 清理结果 — `OrphanCleaner.clean` 返回。
class OrphanCleanResult {
  const OrphanCleanResult({
    required this.successCount,
    required this.failures,
  });

  final int successCount;

  /// 失败列表,key=record.uniqueKey, value=异常信息
  final List<({OrphanRecord record, String error})> failures;

  bool get hasFailure => failures.isNotEmpty;
  int get totalAttempted => successCount + failures.length;

  static const empty =
      OrphanCleanResult(successCount: 0, failures: <({OrphanRecord record, String error})>[]);
}
