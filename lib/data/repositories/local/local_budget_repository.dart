import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../budget_repository.dart';
import '../../../utils/month_range.dart';

const _uuid = Uuid();

void _validateProjectBudgetState({
  required double amount,
  required String? name,
  required DateTime? startAt,
  required DateTime? endAt,
  required String? status,
}) {
  if (!amount.isFinite || amount <= 0) {
    throw ArgumentError(
        'project budget amount must be finite and greater than zero');
  }
  if ((name ?? '').trim().isEmpty) {
    throw ArgumentError('project budget requires a non-empty name');
  }
  if (startAt == null || endAt == null) {
    throw ArgumentError('project budget requires startAt and endAt');
  }
  if (!startAt.isBefore(endAt)) {
    throw ArgumentError('project budget requires startAt < endAt');
  }
  if (status != 'planned' && status != 'active' && status != 'archived') {
    throw ArgumentError('project budget status must be one of '
        "'planned' / 'active' / 'archived'");
  }
}

/// 本地预算Repository实现
/// 基于 Drift 数据库实现
///
/// 这里 NOT 直接调 changeTracker;changeTracker 的注入是通过 LocalRepository
/// 包装层(lib/data/repositories/local/local_repository.dart)在 CRUD 前后
/// 统一 recordChange,保持跟 transaction / account 的代码结构一致。
class LocalBudgetRepository implements BudgetRepository {
  final BeeDatabase db;

  LocalBudgetRepository(this.db);

  /// 读取账本的自定义每月起始日(1-28);账本缺失或查询异常时按 1(自然月)降级。
  Future<int> _monthStartDayOf(int ledgerId) async {
    try {
      final row = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingleOrNull();
      return (row?.monthStartDay ?? 1).clamp(1, 28);
    } catch (_) {
      return 1;
    }
  }

  // ============================================
  // 基础 CRUD 操作
  // ============================================

  @override
  Future<int> createBudget({
    required int ledgerId,
    required String type,
    int? categoryId,
    required double amount,
    String period = 'monthly',
    int startDay = 1,
    String? name,
    DateTime? startAt,
    DateTime? endAt,
    bool? excludeFromMonthlyTotal,
    String? status,
  }) async {
    // 每条新建预算分配一个 UUID,跨设备 LWW 用。syncId 在 DB schema 上允许
    // NULL,只是为了 v22 migration 对老数据兼容;新建走这里永远填。
    //
    // v31:type='project' 时 name/startAt/endAt 必填,status 默认 'active',
    // excludeFromMonthlyTotal 默认 true(合同要求)。其它类型不写这些字段,
    // companion 保持 absent → DB 默认(null / false / 'active')。
    final isProject = type == 'project';
    if (isProject) {
      _validateProjectBudgetState(
        amount: amount,
        name: name,
        startAt: startAt,
        endAt: endAt,
        status: status ?? 'active',
      );
    }
    return await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: ledgerId,
            type: d.Value(type),
            categoryId: d.Value(categoryId),
            amount: amount,
            period: d.Value(period),
            startDay: d.Value(startDay),
            syncId: d.Value(_uuid.v4()),
            name: isProject ? d.Value(name!.trim()) : const d.Value.absent(),
            startAt: isProject ? d.Value(startAt!) : const d.Value.absent(),
            endAt: isProject ? d.Value(endAt!) : const d.Value.absent(),
            excludeFromMonthlyTotal: isProject
                ? d.Value(excludeFromMonthlyTotal ?? true)
                : (excludeFromMonthlyTotal != null
                    ? d.Value(excludeFromMonthlyTotal)
                    : const d.Value.absent()),
            status: isProject
                ? d.Value(status ?? 'active')
                : (status != null ? d.Value(status) : const d.Value.absent()),
          ),
        );
  }

  @override
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
  }) async {
    // v31:传 null 保持不变;传值才更新。project 字段允许写到 total/category 行
    // 但语义无效(不由本仓库拒绝,由调用方保证)。status 若传入必须是合法值。
    if (status != null &&
        status != 'planned' &&
        status != 'active' &&
        status != 'archived') {
      throw ArgumentError('project budget status must be one of '
          "'planned' / 'active' / 'archived'");
    }
    final existing = await (db.select(db.budgets)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (existing != null && existing.type == 'project') {
      _validateProjectBudgetState(
        amount: amount ?? existing.amount,
        name: name ?? existing.name,
        startAt: startAt ?? existing.startAt,
        endAt: endAt ?? existing.endAt,
        status: status ?? existing.status,
      );
    }
    if (existing?.type == 'project' && existing?.status == 'archived') {
      final reactivatingOnly = status == 'active' &&
          amount == null &&
          startDay == null &&
          enabled == null &&
          name == null &&
          startAt == null &&
          endAt == null &&
          excludeFromMonthlyTotal == null;
      if (!reactivatingOnly) {
        throw StateError(
            'archived project budget is read-only; only active reactivation is allowed');
      }
    }
    await (db.update(db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        amount: amount != null ? d.Value(amount) : const d.Value.absent(),
        startDay: startDay != null ? d.Value(startDay) : const d.Value.absent(),
        enabled: enabled != null ? d.Value(enabled) : const d.Value.absent(),
        name: name != null ? d.Value(name.trim()) : const d.Value.absent(),
        startAt: startAt != null ? d.Value(startAt) : const d.Value.absent(),
        endAt: endAt != null ? d.Value(endAt) : const d.Value.absent(),
        excludeFromMonthlyTotal: excludeFromMonthlyTotal != null
            ? d.Value(excludeFromMonthlyTotal)
            : const d.Value.absent(),
        status: status != null ? d.Value(status) : const d.Value.absent(),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteBudget(int id) async {
    // 先获取预算信息，判断是否为总预算
    final budget = await (db.select(db.budgets)..where((b) => b.id.equals(id)))
        .getSingleOrNull();

    if (budget == null) return;

    if (budget.type == 'total') {
      // v31 修复:删除总预算时只级联清理 total/category,不再连坐 project 行。
      // 早期为了兼容"总预算-分类预算联动"设计,删除 total 时把该账本所有 budgets
      // 一并清掉;这在专项预算落地后会破坏用户数据(project 行被静默删除)。
      await (db.delete(db.budgets)
            ..where((b) =>
                b.ledgerId.equals(budget.ledgerId) &
                b.type.isIn(const ['total', 'category'])))
          .go();
    } else {
      if (budget.type == 'project' && budget.syncId != null) {
        final reference = await (db.select(db.transactions)
              ..where((t) => t.projectBudgetSyncId.equals(budget.syncId!)))
            .getSingleOrNull();
        if (reference != null) {
          throw StateError(
              'cannot delete project budget while transactions reference it');
        }
      }
      // 单条删除:分类预算 / 专项预算走同一路径。
      await (db.delete(db.budgets)..where((b) => b.id.equals(id))).go();
    }
  }

  @override
  Future<Budget?> getTotalBudget(int ledgerId) async {
    // 使用 .get() 然后取第一个，避免多条脏数据时报错
    final budgets = await (db.select(db.budgets)
          ..where((b) =>
              b.ledgerId.equals(ledgerId) &
              b.type.equals('total') &
              b.enabled.equals(true))
          ..orderBy([(b) => d.OrderingTerm(expression: b.createdAt)]))
        .get();
    return budgets.firstOrNull;
  }

  @override
  Future<List<Budget>> getCategoryBudgets(int ledgerId) async {
    return await (db.select(db.budgets)
          ..where((b) =>
              b.ledgerId.equals(ledgerId) &
              b.type.equals('category') &
              b.enabled.equals(true)))
        .get();
  }

  @override
  Future<Budget?> getBudgetByCategory(int ledgerId, int categoryId) async {
    return await (db.select(db.budgets)
          ..where((b) =>
              b.ledgerId.equals(ledgerId) &
              b.type.equals('category') &
              b.categoryId.equals(categoryId) &
              b.enabled.equals(true)))
        .getSingleOrNull();
  }

  @override
  Future<List<Budget>> getProjectBudgets(int ledgerId) async {
    // v31: 专项预算按 startAt 升序返回。archived 也返回,由 UI 层决定是否展示;
    // 生命周期靠 status,不复用 enabled。
    return await (db.select(db.budgets)
          ..where((b) => b.ledgerId.equals(ledgerId) & b.type.equals('project'))
          ..orderBy([(b) => d.OrderingTerm.asc(b.startAt)]))
        .get();
  }

  @override
  Future<Budget?> getProjectBudgetBySyncId(String syncId) async {
    if (syncId.isEmpty) return null;
    final row = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals(syncId) & b.type.equals('project')))
        .getSingleOrNull();
    return row;
  }

  Future<bool> _hasTransactionReferences(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return false;
    final reference = await (db.select(db.transactions)
          ..where((t) => t.projectBudgetSyncId.equals(syncId)))
        .getSingleOrNull();
    return reference != null;
  }

  @override
  Future<void> overwriteBudgetSyncId(int id, String newSyncId) async {
    // v31 恢复期专用:被 transaction 引用的 identity 不得重写，否则会留下
    // dangling projectBudgetSyncId。
    final existing = await (db.select(db.budgets)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (existing != null &&
        existing.syncId != newSyncId &&
        await _hasTransactionReferences(existing.syncId)) {
      throw StateError(
          'cannot overwrite budget syncId while transactions reference it');
    }
    await (db.update(db.budgets)..where((b) => b.id.equals(id)))
        .write(BudgetsCompanion(syncId: d.Value(newSyncId)));
  }

  @override
  Future<Budget?> getBudgetBySyncId(String syncId) async {
    if (syncId.isEmpty) return null;
    return await (db.select(db.budgets)..where((b) => b.syncId.equals(syncId)))
        .getSingleOrNull();
  }

  @override
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
  }) async {
    if (type == 'project') {
      _validateProjectBudgetState(
        amount: amount,
        name: name,
        startAt: startAt,
        endAt: endAt,
        status: status,
      );
    }
    // v31 恢复入口:与 sync_engine_apply._applyBudgetChange 语义对齐。
    // - 已存在同 syncId → 更新所有字段(不含 syncId 本身);
    // - 不存在 → 插入,syncId 用调用方提供的值,**不**新生成。
    // 不记 changeTracker;调用方(import 服务)按需自记。
    final existing = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals(syncId)))
        .getSingleOrNull();
    if (existing != null) {
      if (existing.ledgerId != ledgerId) {
        throw StateError('budget syncId already belongs to another ledger');
      }
      if (existing.type == 'project' &&
          type != 'project' &&
          await _hasTransactionReferences(existing.syncId)) {
        throw StateError(
            'cannot change referenced project budget to a non-project type');
      }
      if (existing.type == 'project' && existing.status == 'archived') {
        final sameBusinessFields = type == 'project' &&
            existing.ledgerId == ledgerId &&
            existing.categoryId == categoryId &&
            existing.amount == amount &&
            existing.period == period &&
            existing.startDay == startDay &&
            existing.enabled == enabled &&
            existing.name == name &&
            _sameInstant(existing.startAt, startAt) &&
            _sameInstant(existing.endAt, endAt) &&
            existing.excludeFromMonthlyTotal == excludeFromMonthlyTotal;
        if (sameBusinessFields && status == 'archived') {
          return existing.id;
        }
        final onlyReactivating = sameBusinessFields && status == 'active';
        if (!onlyReactivating) {
          throw StateError(
              'archived project budget is read-only; only unchanged active reactivation is allowed');
        }
      }
      await (db.update(db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(
        ledgerId: d.Value(ledgerId),
        type: d.Value(type),
        categoryId: d.Value(categoryId),
        amount: d.Value(amount),
        period: d.Value(period),
        startDay: d.Value(startDay),
        enabled: d.Value(enabled),
        name: name != null ? d.Value(name) : const d.Value.absent(),
        startAt: startAt != null ? d.Value(startAt) : const d.Value.absent(),
        endAt: endAt != null ? d.Value(endAt) : const d.Value.absent(),
        excludeFromMonthlyTotal: d.Value(excludeFromMonthlyTotal),
        status: d.Value(status),
        updatedAt: d.Value(DateTime.now()),
      ));
      return existing.id;
    }
    return await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: ledgerId,
          type: d.Value(type),
          categoryId: d.Value(categoryId),
          amount: amount,
          period: d.Value(period),
          startDay: d.Value(startDay),
          enabled: d.Value(enabled),
          syncId: d.Value(syncId),
          name: name != null ? d.Value(name) : const d.Value.absent(),
          startAt: startAt != null ? d.Value(startAt) : const d.Value.absent(),
          endAt: endAt != null ? d.Value(endAt) : const d.Value.absent(),
          excludeFromMonthlyTotal: d.Value(excludeFromMonthlyTotal),
          status: d.Value(status),
        ));
  }

  @override
  Future<List<Budget>> getAllBudgets(int ledgerId) async {
    return await (db.select(db.budgets)
          ..where((b) => b.ledgerId.equals(ledgerId))
          ..orderBy([
            (b) => d.OrderingTerm(expression: b.type),
            (b) => d.OrderingTerm(expression: b.createdAt),
          ]))
        .get();
  }

  @override
  Future<List<Budget>> getAllBudgetsForExport() async {
    return await (db.select(db.budgets)
          ..orderBy([
            (b) => d.OrderingTerm(expression: b.ledgerId),
            (b) => d.OrderingTerm(expression: b.type),
            (b) => d.OrderingTerm(expression: b.createdAt),
          ]))
        .get();
  }

  bool _sameInstant(DateTime? left, DateTime? right) {
    if (left == null || right == null) return left == right;
    return left.isAtSameMomentAs(right);
  }

  // ============================================
  // 预算统计
  // ============================================

  @override
  Future<BudgetUsage> getBudgetUsage(int budgetId, DateTime month) async {
    final budget = await (db.select(db.budgets)
          ..where((b) => b.id.equals(budgetId)))
        .getSingleOrNull();

    if (budget == null) {
      return BudgetUsage(used: 0, budget: 0);
    }

    // v31:project 预算走独立 [startAt, endAt) 半开区间,不受账本 monthStartDay
    // 影响;total/category 沿用旧口径(账本周期跟随 monthStartDay,与调用方传
    // 的 month 锚点一起,由 periodContaining 计算)。
    double used = 0;
    if (budget.type == 'project') {
      if (budget.startAt == null || budget.endAt == null) {
        // 数据缺失:直接返回 used=0,不 crash。调用方(UI)可据此提示补齐。
        return BudgetUsage(used: 0, budget: budget.amount);
      }
      // 项目 usage = 关联到本 project(project_budget_sync_id = budget.syncId)
      // 的 expense 交易之和,尊重 exclude_from_budget。budget.syncId 为空理论上
      // 不会发生(新建都填了 UUID),兜底返回 0 避免误统计。
      final linkSyncId = budget.syncId;
      if (linkSyncId == null || linkSyncId.isEmpty) {
        return BudgetUsage(used: 0, budget: budget.amount);
      }
      final result = await db.customSelect(
        '''
        SELECT COALESCE(SUM(COALESCE(native_amount, amount)), 0) as total
        FROM transactions
        WHERE ledger_id = ?
          AND type = 'expense'
          AND exclude_from_budget = 0
          AND project_budget_sync_id = ?
          AND happened_at >= ?
          AND happened_at < ?
        ''',
        variables: [
          d.Variable.withInt(budget.ledgerId),
          d.Variable.withString(linkSyncId),
          d.Variable.withDateTime(budget.startAt!),
          d.Variable.withDateTime(budget.endAt!),
        ],
        readsFrom: {db.transactions},
      ).getSingle();
      used = _parseDouble(result.data['total']);
      return BudgetUsage(used: used, budget: budget.amount);
    }

    // 预算周期跟随账本 monthStartDay(设计 D5:budget.startDay 弃用,列保留
    // 兼容历史同步数据)。month 参数语义 = 「包含该日期的周期」,调用方传 now
    // (见 budget_providers.dart)。
    final sd = await _monthStartDayOf(budget.ledgerId);
    final range = periodContaining(month, sd);
    final startDate = range.start;
    final endDate = range.end;

    // 查询该周期内的支出
    if (budget.type == 'total') {
      // 总预算:统计所有支出,但排除关联到 excludeFromMonthlyTotal=true 的
      // project 的支出(v31 合同要求)。NOT EXISTS 子查询确认关联的 project
      // 行是否设为剔除。
      final result = await db.customSelect(
        '''
        SELECT COALESCE(SUM(COALESCE(t.native_amount, t.amount)), 0) as total
        FROM transactions t
        WHERE t.ledger_id = ?
          AND t.type = 'expense'
          AND t.exclude_from_budget = 0
          AND t.happened_at >= ?
          AND t.happened_at < ?
          AND NOT EXISTS (
            SELECT 1 FROM budgets pb
            WHERE pb.sync_id = t.project_budget_sync_id
              AND pb.type = 'project'
              AND pb.exclude_from_monthly_total = 1
          )
        ''',
        variables: [
          d.Variable.withInt(budget.ledgerId),
          d.Variable.withDateTime(startDate),
          d.Variable.withDateTime(endDate),
        ],
        readsFrom: {db.transactions, db.budgets},
      ).getSingle();
      used = _parseDouble(result.data['total']);
    } else if (budget.type == 'category') {
      // v31 修复:严格判断 type,且要求 categoryId 非空;避免历史上"else 分支
      // 兜底一切"导致 project 行落入 categoryId! 解包 crash。D013:有效同账本
      // project link 独占项目池;孤儿/跨账本/非 project 的历史 link 仍属分类池。
      // 数据异常直接返回 used=0 而不是 throw。
      if (budget.categoryId == null) {
        return BudgetUsage(used: 0, budget: budget.amount);
      }
      final result = await db.customSelect(
        '''
        SELECT COALESCE(SUM(COALESCE(t.native_amount, t.amount)), 0) as total
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.ledger_id = ?
          AND t.type = 'expense'
          AND t.exclude_from_budget = 0
          AND t.happened_at >= ?
          AND t.happened_at < ?
          AND (t.category_id = ? OR c.parent_id = ?)
          AND NOT EXISTS (
            SELECT 1 FROM budgets pb
            WHERE t.project_budget_sync_id IS NOT NULL
              AND t.project_budget_sync_id <> ''
              AND pb.sync_id = t.project_budget_sync_id
              AND pb.ledger_id = t.ledger_id
              AND pb.type = 'project'
          )
        ''',
        variables: [
          d.Variable.withInt(budget.ledgerId),
          d.Variable.withDateTime(startDate),
          d.Variable.withDateTime(endDate),
          d.Variable.withInt(budget.categoryId!),
          d.Variable.withInt(budget.categoryId!),
        ],
        readsFrom: {db.transactions, db.categories, db.budgets},
      ).getSingle();
      used = _parseDouble(result.data['total']);
    } else {
      // 未知类型:不再"else 兜底 category",直接返回 0 保守。
      return BudgetUsage(used: 0, budget: budget.amount);
    }

    return BudgetUsage(used: used, budget: budget.amount);
  }

  @override
  Future<BudgetOverview> getBudgetOverview(int ledgerId, DateTime month) async {
    // 获取总预算
    final totalBudget = await getTotalBudget(ledgerId);
    BudgetUsage? totalUsage;

    if (totalBudget != null) {
      totalUsage = await getBudgetUsage(totalBudget.id, month);
    }

    // 获取分类预算使用情况
    final categoryUsages = await getCategoryBudgetUsages(ledgerId, month);

    // 计算剩余天数(周期跟随账本 monthStartDay,与 getBudgetUsage 同口径)
    final now = DateTime.now();
    final sd = await _monthStartDayOf(ledgerId);
    final endDate = periodContaining(now, sd).end;
    final daysRemaining = endDate.difference(now).inDays;

    // 计算日均可用
    final remaining = totalUsage?.remaining ?? 0;
    final dailyAvailable = daysRemaining > 0 ? remaining / daysRemaining : 0.0;

    return BudgetOverview(
      totalBudget: totalUsage,
      categoryBudgets: categoryUsages,
      daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
      dailyAvailable: dailyAvailable > 0 ? dailyAvailable : 0,
    );
  }

  @override
  Future<List<CategoryBudgetUsage>> getCategoryBudgetUsages(
    int ledgerId,
    DateTime month,
  ) async {
    final budgets = await getCategoryBudgets(ledgerId);
    final result = <CategoryBudgetUsage>[];

    for (final budget in budgets) {
      if (budget.categoryId == null) continue;

      // 获取分类信息
      final category = await (db.select(db.categories)
            ..where((c) => c.id.equals(budget.categoryId!)))
          .getSingleOrNull();

      if (category == null) continue;

      // 获取使用情况
      final usage = await getBudgetUsage(budget.id, month);

      result.add(CategoryBudgetUsage(
        budgetId: budget.id,
        categoryId: category.id,
        categoryName: category.name,
        categoryIcon: category.icon,
        // 透传完整 Category 给 UI,让 CategoryBudgetTile 能用 CategoryIconWidget
        // 渲染 iconType='custom' 的自定义图片图标(只有 categoryIcon 字符串时
        // 走 CategoryService.getCategoryIcon switch,自定义路径会兜底成
        // Icons.category 通用占位 — 这是用户报"分类预算图标不正确"的根因)。
        category: category,
        usage: usage,
      ));
    }

    // 按使用率降序排列
    result.sort((a, b) => b.usage.rate.compareTo(a.usage.rate));

    return result;
  }

  // ============================================
  // 监听
  // ============================================

  @override
  Stream<List<Budget>> watchBudgets(int ledgerId) {
    return (db.select(db.budgets)
          ..where((b) => b.ledgerId.equals(ledgerId))
          ..orderBy([
            (b) => d.OrderingTerm(expression: b.type),
            (b) => d.OrderingTerm(expression: b.createdAt),
          ]))
        .watch();
  }

  // ============================================
  // 辅助方法
  // ============================================

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return 0.0;
  }
}
