import '../db.dart';

/// 按 syncId 恢复一条 budget 所需的完整业务字段。
class BudgetRestoreBySyncIdData {
  final String syncId;
  final int ledgerId;
  final String type;
  final int? categoryId;
  final double amount;
  final String period;
  final int startDay;
  final bool enabled;
  final String? name;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool excludeFromMonthlyTotal;
  final String status;

  const BudgetRestoreBySyncIdData({
    required this.syncId,
    required this.ledgerId,
    required this.type,
    this.categoryId,
    required this.amount,
    this.period = 'monthly',
    this.startDay = 1,
    this.enabled = true,
    this.name,
    this.startAt,
    this.endAt,
    this.excludeFromMonthlyTotal = false,
    this.status = 'active',
  });
}

/// 预算使用情况
class BudgetUsage {
  final double used; // 已用金额
  final double budget; // 预算金额
  final double remaining; // 剩余金额
  final double rate; // 使用率 (0-1)

  BudgetUsage({
    required this.used,
    required this.budget,
  })  : remaining = budget - used,
        rate = budget > 0 ? (used / budget).clamp(0.0, double.infinity) : 0;

  /// 状态：normal, warning, danger, exceeded
  String get status {
    if (rate >= 1.0) return 'exceeded';
    if (rate >= 0.9) return 'danger';
    if (rate >= 0.7) return 'warning';
    return 'normal';
  }
}

/// 预算概览
class BudgetOverview {
  final BudgetUsage? totalBudget;
  final List<CategoryBudgetUsage> categoryBudgets;
  final int daysRemaining;
  final double dailyAvailable;

  const BudgetOverview({
    this.totalBudget,
    this.categoryBudgets = const [],
    required this.daysRemaining,
    required this.dailyAvailable,
  });
}

/// 分类预算使用情况
class CategoryBudgetUsage {
  final int budgetId;
  final int categoryId;
  final String categoryName;
  final String? categoryIcon;

  /// 完整的 Category 对象 —— 让 UI 走 CategoryIconWidget 拿 iconType /
  /// customIconPath / iconCloudFileId,自定义图片预算也能正常渲染图标。
  /// 老调用方还在读 categoryIcon 字段,这里两边并存。
  final Category? category;
  final BudgetUsage usage;

  const CategoryBudgetUsage({
    required this.budgetId,
    required this.categoryId,
    required this.categoryName,
    this.categoryIcon,
    this.category,
    required this.usage,
  });
}

/// 预算仓库接口
abstract class BudgetRepository {
  // ============ 预算 CRUD ============

  /// 创建预算(通用入口:total / category / project)。project 行必须传
  /// [name] / [startAt] / [endAt];其余可选,project 默认走冻结合同(status=active,
  /// excludeFromMonthlyTotal=true)。非 project 类型不应传这些字段,若误传本地
  /// 会被忽略(生成的 companion 保持 absent)。
  Future<int> createBudget({
    required int ledgerId,
    required String type,
    int? categoryId,
    required double amount,
    String period = 'monthly',
    int startDay = 1,
    // v31: 专项预算(type='project')字段。冻结合同见
    // local-artifacts/special-budget/plans/2026-07-23-app-phase3-contract.md。
    String? name,
    DateTime? startAt,
    DateTime? endAt,
    bool? excludeFromMonthlyTotal,
    String? status,
  });

  /// 更新预算。amount / startDay / enabled 保留旧签名(total/category)。
  /// v31 新增字段仅对 type='project' 有效,传 null 表示保持不变(不是清除)。
  Future<void> updateBudget(
    int id, {
    double? amount,
    int? startDay,
    bool? enabled,
    String? name,
    DateTime? startAt,
    DateTime? endAt,
    bool? excludeFromMonthlyTotal,
    String? status,
  });

  /// 删除预算
  Future<void> deleteBudget(int id);

  /// 获取账本的总预算
  Future<Budget?> getTotalBudget(int ledgerId);

  /// 获取账本的所有分类预算
  Future<List<Budget>> getCategoryBudgets(int ledgerId);

  /// 获取指定分类的预算
  Future<Budget?> getBudgetByCategory(int ledgerId, int categoryId);

  /// v31: 获取账本的所有专项预算(type='project'),按 startAt 升序返回。
  Future<List<Budget>> getProjectBudgets(int ledgerId);

  /// v31: 按 syncId 查找专项预算(返回 null 表示不存在或类型不匹配)。
  Future<Budget?> getProjectBudgetBySyncId(String syncId);

  /// v31: 恢复路径专用 — 把某条 budget 行的 syncId 强制改成 [newSyncId]。
  /// 通用 CRUD 不允许改 syncId;仅在导入器需要保留 payload 里的原始 syncId
  /// (不能让 createBudget 生成的临时 UUID 泄漏出去)时用。**不**记 change:
  /// 恢复期不能反向回推。
  Future<void> overwriteBudgetSyncId(int id, String newSyncId);

  /// v31: 恢复路径专用 — 按 syncId 直接 upsert budget 行。已有 syncId →
  /// 更新;不存在 → 插入。返回本地 int id。
  ///
  /// 与 [createBudget] 的差异:createBudget 会生成新 UUID;这里保留 payload
  /// 中的 syncId。[recordChanges]=true 时,聚合仓库必须把 upsert 与 change log
  /// 写入同一事务；云端恢复路径保持 false。
  ///
  /// 用于:v7 snapshot 恢复、跨端 change apply。
  Future<int> restoreBudgetBySyncId({
    required String syncId,
    required int ledgerId,
    required String type,
    int? categoryId,
    required double amount,
    String period = 'monthly',
    int startDay = 1,
    bool enabled = true,
    String? name,
    DateTime? startAt,
    DateTime? endAt,
    bool excludeFromMonthlyTotal = false,
    String status = 'active',
    bool recordChanges = false,
  });

  /// 按 syncId 查任何 type 的 budget(区别于 [getProjectBudgetBySyncId] 只查
  /// project)。恢复期做幂等检查时使用。
  Future<Budget?> getBudgetBySyncId(String syncId);

  /// 获取账本的所有预算
  Future<List<Budget>> getAllBudgets(int ledgerId);

  /// 获取所有账本的所有预算（用于导出）
  Future<List<Budget>> getAllBudgetsForExport();

  // ============ 预算统计 ============

  /// 获取预算使用情况
  /// [month] 为周期锚点(调用方传 now):实际统计范围 = 包含该日期的
  /// [账本起始日, 次月起始日) 周期,由账本 monthStartDay 决定(D5:预算跟随账本)。
  ///
  /// v31:对 type='project' 行,使用 [startAt, endAt) 半开区间,统计已关联
  /// (projectBudgetSyncId 匹配)的 expense 交易之和(仍尊重 exclude_from_budget)。
  Future<BudgetUsage> getBudgetUsage(int budgetId, DateTime month);

  /// 获取账本当月预算概览
  /// [month] 为周期锚点(调用方传 now):实际统计范围 = 包含该日期的
  /// [账本起始日, 次月起始日) 周期,由账本 monthStartDay 决定(D5:预算跟随账本)。
  Future<BudgetOverview> getBudgetOverview(int ledgerId, DateTime month);

  /// 批量获取分类预算使用情况
  /// [month] 为周期锚点(调用方传 now):实际统计范围 = 包含该日期的
  /// [账本起始日, 次月起始日) 周期,由账本 monthStartDay 决定(D5:预算跟随账本)。
  Future<List<CategoryBudgetUsage>> getCategoryBudgetUsages(
    int ledgerId,
    DateTime month,
  );

  // ============ 监听 ============

  /// 监听预算变化
  Stream<List<Budget>> watchBudgets(int ledgerId);
}
