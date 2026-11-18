import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../system/logger_service.dart';

/// 重复交易频率枚举
enum RecurringFrequency {
  daily('daily'), // 每天
  weekly('weekly'), // 每周
  monthly('monthly'), // 每月
  yearly('yearly'); // 每年

  final String value;
  const RecurringFrequency(this.value);

  static RecurringFrequency fromString(String value) {
    return RecurringFrequency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}

/// 纯排期输入参数（同时供数据库实体与编辑页未保存草稿复用）
class RecurringScheduleSpec {
  const RecurringScheduleSpec({
    required this.frequency,
    required this.interval,
    required this.startDate,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    this.endDate,
    this.lastGeneratedDate,
    this.enabled = true,
  });

  factory RecurringScheduleSpec.fromModel(RecurringTransaction model) {
    return RecurringScheduleSpec(
      frequency: RecurringFrequency.fromString(model.frequency),
      interval: model.interval,
      startDate: model.startDate,
      dayOfMonth: model.dayOfMonth,
      dayOfWeek: model.dayOfWeek,
      monthOfYear: model.monthOfYear,
      endDate: model.endDate,
      lastGeneratedDate: model.lastGeneratedDate,
      enabled: model.enabled,
    );
  }

  final RecurringFrequency frequency;
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastGeneratedDate;
  final bool enabled;

  RecurringScheduleSpec copyWith({
    DateTime? lastGeneratedDate,
    bool updateLastGeneratedDate = false,
  }) {
    return RecurringScheduleSpec(
      frequency: frequency,
      interval: interval,
      startDate: startDate,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      monthOfYear: monthOfYear,
      endDate: endDate,
      lastGeneratedDate: updateLastGeneratedDate
          ? lastGeneratedDate
          : this.lastGeneratedDate,
      enabled: enabled,
    );
  }
}

/// 单期预计记账推演结果
class RecurringOccurrencePreview {
  const RecurringOccurrencePreview({
    required this.date,
    required this.daysFromToday,
    this.nominalDayOfMonth,
    this.adjustedForMonthEnd = false,
  });

  final DateTime date;
  final int daysFromToday;
  final int? nominalDayOfMonth;
  final bool adjustedForMonthEnd;
}

class _OccurrenceStep {
  const _OccurrenceStep({
    required this.date,
    this.nominalDay,
    this.adjusted = false,
  });

  final DateTime date;
  final int? nominalDay;
  final bool adjusted;
}

/// 重复交易服务
///
/// 注意：此服务负责生成待处理的周期交易记录及排期推演，
/// 基础 CRUD 操作请使用 RecurringTransactionRepository。
class RecurringTransactionService {
  static const _tag = 'Recurring';

  static Future<Set<int>>? _inFlightScan;
  static bool _pendingRescan = false;

  final dynamic repository;

  RecurringTransactionService(this.repository);

  /// 剥离时分秒，统一归一化到本地自然日零点
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 跨夏令时安全的自然日差值（target - base）
  static int calendarDaysBetween(DateTime target, DateTime base) {
    final a = DateTime.utc(target.year, target.month, target.day);
    final b = DateTime.utc(base.year, base.month, base.day);
    return a.difference(b).inDays;
  }

  /// 静态方法：生成待处理的重复交易（带进程内 SingleFlight 互斥防重入）
  ///
  /// [rescanIfBusy] 为 true 时，若当前已有扫描在途，会在本轮结束后自动补扫一次，
  /// 确保刚保存/启用的新规则不会被在途旧快照漏掉。
  ///
  /// 返回：本次生成了交易的账本 ID 集合（用于触发同步和统计刷新）
  static Future<Set<int>> generatePendingTransactionsStatic({
    required dynamic repository,
    bool verbose = false,
    bool rescanIfBusy = false,
  }) {
    if (_inFlightScan != null) {
      if (rescanIfBusy) _pendingRescan = true;
      logger.info(_tag, '已有周期扫描任务在途，复用当前单飞任务 (rescan=$rescanIfBusy)');
      return _inFlightScan!;
    }

    Future<Set<int>> runSerialized() async {
      final affectedLedgers = <int>{};
      try {
        do {
          _pendingRescan = false;
          logger.info(_tag,
              '开始生成待处理的重复交易 (Repository=${repository.runtimeType}, verbose=$verbose)');
          final service = RecurringTransactionService(repository);
          final generated = await service.generatePendingTransactions();
          if (generated.isNotEmpty) {
            final ids = generated.map((t) => t.ledgerId).toSet();
            affectedLedgers.addAll(ids);
            logger.info(
                _tag, '本轮共生成 ${generated.length} 条重复交易，涉及账本 $ids');
          } else {
            logger.info(_tag, '本轮没有需要生成的重复交易');
          }
        } while (_pendingRescan);
        return affectedLedgers;
      } catch (e, stackTrace) {
        logger.error(_tag, '生成重复交易失败', e, stackTrace);
        return affectedLedgers;
      } finally {
        _inFlightScan = null;
        _pendingRescan = false;
      }
    }

    final future = runSerialized();
    _inFlightScan = future;
    return future;
  }

  static _OccurrenceStep _buildMonthly(int year, int month, int targetDay) {
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;
    return _OccurrenceStep(
      date: DateTime(year, month, actualDay),
      nominalDay: targetDay,
      adjusted: actualDay < targetDay,
    );
  }

  static _OccurrenceStep _stepOccurrence(
    RecurringScheduleSpec spec, {
    required DateTime? cursor,
  }) {
    final anchor = dateOnly(spec.startDate);
    final interval = spec.interval < 1 ? 1 : spec.interval;
    final effectiveCursor =
        (cursor != null && !anchor.isAfter(cursor)) ? dateOnly(cursor) : null;

    if (effectiveCursor == null) {
      switch (spec.frequency) {
        case RecurringFrequency.daily:
          return _OccurrenceStep(date: anchor);
        case RecurringFrequency.weekly:
          final dow = spec.dayOfWeek;
          if (dow != null && dow >= 1 && dow <= 7) {
            final offset = (dow - anchor.weekday + 7) % 7;
            return _OccurrenceStep(
              date: DateTime(anchor.year, anchor.month, anchor.day + offset),
            );
          }
          return _OccurrenceStep(date: anchor);
        case RecurringFrequency.monthly:
          final nominalDay = (spec.dayOfMonth ?? anchor.day).clamp(1, 31);
          var cand = _buildMonthly(anchor.year, anchor.month, nominalDay);
          if (cand.date.isBefore(anchor)) {
            cand = _buildMonthly(anchor.year, anchor.month + 1, nominalDay);
          }
          return cand;
        case RecurringFrequency.yearly:
          final targetMonth = (spec.monthOfYear ?? anchor.month).clamp(1, 12);
          // 兼容修复：历史编辑器切到 yearly 时可能残留创建当日 dayOfMonth 且 monthOfYear 为 null，
          // 仅当 monthOfYear 与 dayOfMonth 均显式存在时才取 dayOfMonth，否则严格锚定 startDate。
          final nominalDay =
              (spec.monthOfYear != null && spec.dayOfMonth != null
                      ? spec.dayOfMonth!
                      : anchor.day)
                  .clamp(1, 31);
          var cand = _buildMonthly(anchor.year, targetMonth, nominalDay);
          if (cand.date.isBefore(anchor)) {
            cand = _buildMonthly(anchor.year + 1, targetMonth, nominalDay);
          }
          return cand;
      }
    }

    switch (spec.frequency) {
      case RecurringFrequency.daily:
        return _OccurrenceStep(
          date: DateTime(
            effectiveCursor.year,
            effectiveCursor.month,
            effectiveCursor.day + interval,
          ),
        );
      case RecurringFrequency.weekly:
        return _OccurrenceStep(
          date: DateTime(
            effectiveCursor.year,
            effectiveCursor.month,
            effectiveCursor.day + 7 * interval,
          ),
        );
      case RecurringFrequency.monthly:
        final nominalDay = (spec.dayOfMonth ?? anchor.day).clamp(1, 31);
        return _buildMonthly(
          effectiveCursor.year,
          effectiveCursor.month + interval,
          nominalDay,
        );
      case RecurringFrequency.yearly:
        final targetMonth = (spec.monthOfYear ?? anchor.month).clamp(1, 12);
        final nominalDay =
            (spec.monthOfYear != null && spec.dayOfMonth != null
                    ? spec.dayOfMonth!
                    : anchor.day)
                .clamp(1, 31);
        return _buildMonthly(
          effectiveCursor.year + interval,
          targetMonth,
          nominalDay,
        );
    }
  }

  static _OccurrenceStep? _calculateNextDueStep(
    RecurringScheduleSpec spec, {
    required DateTime today,
  }) {
    final endDay = spec.endDate == null ? null : dateOnly(spec.endDate!);
    final anchor = dateOnly(spec.startDate);
    final rawLast =
        spec.lastGeneratedDate == null ? null : dateOnly(spec.lastGeneratedDate!);
    final effectiveLast =
        (rawLast != null && !anchor.isAfter(rawLast)) ? rawLast : null;
    final interval = spec.interval < 1 ? 1 : spec.interval;

    if (effectiveLast == null) {
      var cur = _stepOccurrence(spec, cursor: null);
      if (cur.date.isAfter(today)) return null;
      if (endDay != null && cur.date.isAfter(endDay)) return null;

      // 从未生成过的规则（firstGen）：
      // 定位 <= min(today, endDay) 的最近一期：
      // 1) 正常当月新建（如 11/1 建每月 15 日，11/16 打开）→ 命中 11/15，不再跨日漏单（#584）；
      // 2) 远古历史开始日（如 30 天前建每天）→ 直接快进到最近到期日（今天），只生成 1 笔不刷历史脏数据（#135）。
      final upperBound =
          (endDay != null && endDay.isBefore(today)) ? endDay : today;
      if (spec.frequency == RecurringFrequency.daily ||
          spec.frequency == RecurringFrequency.weekly) {
        final stepDays = spec.frequency == RecurringFrequency.daily
            ? interval
            : 7 * interval;
        final span = calendarDaysBetween(upperBound, cur.date);
        if (span >= stepDays) {
          final jumps = span ~/ stepDays;
          cur = _OccurrenceStep(
            date: DateTime(
              cur.date.year,
              cur.date.month,
              cur.date.day + jumps * stepDays,
            ),
          );
        }
        return cur;
      }

      var guard = 0;
      while (guard++ < 5000) {
        final nxt = _stepOccurrence(spec, cursor: cur.date);
        if (nxt.date.isAfter(upperBound)) break;
        cur = nxt;
      }
      return cur;
    }

    final nxt = _stepOccurrence(spec, cursor: effectiveLast);
    if (nxt.date.isAfter(today)) return null;
    if (endDay != null && nxt.date.isAfter(endDay)) return null;
    return nxt;
  }

  /// 纯函数推演接下来 [count] 次启动记账时间（与真实生成完全同源）
  static List<RecurringOccurrencePreview> previewUpcomingOccurrences(
    RecurringScheduleSpec spec, {
    int count = 3,
    DateTime? now,
  }) {
    if (count <= 0 || !spec.enabled) return const [];
    final today = dateOnly(now ?? DateTime.now());
    final endDay = spec.endDate == null ? null : dateOnly(spec.endDate!);
    final anchor = dateOnly(spec.startDate);
    final rawLast =
        spec.lastGeneratedDate == null ? null : dateOnly(spec.lastGeneratedDate!);
    final effectiveLast =
        (rawLast != null && !anchor.isAfter(rawLast)) ? rawLast : null;

    final out = <RecurringOccurrencePreview>[];
    final due = _calculateNextDueStep(spec, today: today);

    _OccurrenceStep firstStep;
    if (due != null) {
      firstStep = due;
    } else {
      firstStep = _stepOccurrence(spec, cursor: effectiveLast);
      // 若 effectiveLast 为空但 startDate 远早于今天且因 endDate 已截止，上面会在 endDay 拦截
      if (endDay != null && firstStep.date.isAfter(endDay)) {
        return const [];
      }
      // 防御：若因异常边界仍在 today 之前，推进到首个 > today 的未来期次
      var guard = 0;
      while (!firstStep.date.isAfter(today) && guard++ < 5000) {
        firstStep = _stepOccurrence(spec, cursor: firstStep.date);
        if (endDay != null && firstStep.date.isAfter(endDay)) {
          return const [];
        }
      }
    }

    out.add(RecurringOccurrencePreview(
      date: firstStep.date,
      daysFromToday: calendarDaysBetween(firstStep.date, today),
      nominalDayOfMonth: firstStep.nominalDay,
      adjustedForMonthEnd: firstStep.adjusted,
    ));

    var simCursor = firstStep.date;
    while (out.length < count) {
      final nxt = _stepOccurrence(spec, cursor: simCursor);
      if (endDay != null && nxt.date.isAfter(endDay)) break;
      out.add(RecurringOccurrencePreview(
        date: nxt.date,
        daysFromToday: calendarDaysBetween(nxt.date, today),
        nominalDayOfMonth: nxt.nominalDay,
        adjustedForMonthEnd: nxt.adjusted,
      ));
      simCursor = nxt.date;
    }
    return out;
  }

  /// 计算下一次应该立即生成交易的自然日。返回 null 表示当前时刻无需生成。
  ///
  /// [now] 仅用于测试注入当前时间；正常调用走 `DateTime.now()`。
  DateTime? calculateNextDate(RecurringTransaction recurring, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final spec = RecurringScheduleSpec.fromModel(recurring);
    final due = _calculateNextDueStep(spec, today: today);
    if (due == null) {
      logger.info(_tag,
          'calc id=${recurring.id} freq=${recurring.frequency} interval=${recurring.interval} start=${recurring.startDate} end=${recurring.endDate} lastGen=${recurring.lastGeneratedDate} → 当前无到期项(today=$today)');
      return null;
    }
    logger.info(_tag,
        'calc id=${recurring.id} freq=${recurring.frequency} interval=${recurring.interval} lastGen=${recurring.lastGeneratedDate} → 到期生成 next=${due.date}');
    return due.date;
  }

  /// 生成所有待处理的到期交易记录（单规则异常隔离 + 单期事务原子落库）
  Future<List<Transaction>> generatePendingTransactions({DateTime? now}) async {
    final nowTs = now ?? DateTime.now();
    logger.info(_tag, '开始扫描周期交易 (now=$nowTs)');

    final ledgers = await repository.getAllLedgers();
    final ledgerIds = <int>{for (final l in ledgers) l.id as int};
    logger.info(_tag, '获取到 ${ledgers.length} 个有效账本');

    final allRecurring =
        (await repository.getAllRecurringTransactions()) as List<RecurringTransaction>;
    final generatedTransactions = <Transaction>[];

    for (final recurring in allRecurring) {
      if (!recurring.enabled) continue;
      if (!ledgerIds.contains(recurring.ledgerId)) {
        logger.warning(_tag,
            '周期交易 id=${recurring.id} 跳过:所属账本 ledgerId=${recurring.ledgerId} 不存在');
        continue;
      }

      try {
        logger.info(_tag,
            '处理周期交易 id=${recurring.id} ledger=${recurring.ledgerId} freq=${recurring.frequency} interval=${recurring.interval} start=${recurring.startDate} end=${recurring.endDate} lastGen=${recurring.lastGeneratedDate}');

        // 关联账户校验：隐藏账户（#240 E2）或已删除的关联账户均跳过且不推进游标
        final fromAccount = recurring.accountId != null
            ? await repository.getAccount(recurring.accountId)
            : null;
        final toAccount = recurring.toAccountId != null
            ? await repository.getAccount(recurring.toAccountId)
            : null;
        if ((fromAccount?.hidden ?? false) || (toAccount?.hidden ?? false)) {
          logger.info(_tag,
              '周期交易 id=${recurring.id} 跳过:关联账户已隐藏(accountId=${recurring.accountId}, toAccountId=${recurring.toAccountId})');
          continue;
        }
        if ((recurring.accountId != null && fromAccount == null) ||
            (recurring.toAccountId != null && toAccount == null)) {
          logger.warning(_tag,
              '周期交易 id=${recurring.id} 跳过:关联账户不存在(accountId=${recurring.accountId}, toAccountId=${recurring.toAccountId})');
          continue;
        }

        var currentRecurring = recurring;
        var loopGuard = 0;
        while (true) {
          if (++loopGuard > 1000) {
            logger.warning(
                _tag, '周期交易 id=${recurring.id} 单次生成超过 1000 笔，中止防死循环');
            break;
          }
          final nextDate = calculateNextDate(currentRecurring, now: nowTs);
          if (nextDate == null) break;

          logger.info(_tag,
              '周期交易 id=${currentRecurring.id} 生成到期账单: happenedAt=$nextDate amount=${currentRecurring.amount} type=${currentRecurring.type}');

          Transaction? created;
          if (repository is BaseRepository) {
            created = await (repository as BaseRepository)
                .generateRecurringOccurrence(
              recurringId: currentRecurring.id,
              scheduledDate: nextDate,
            );
            if (created == null) {
              // 事务内重检未通过（已被并发处理、禁用或账户状态变化）→ 安全退出当前规则循环
              break;
            }
          } else {
            final txCurrency = currentRecurring.accountId != null
                ? null
                : currentRecurring.currencyCode;
            final transactionId = await repository.addTransaction(
              ledgerId: currentRecurring.ledgerId,
              type: currentRecurring.type,
              amount: currentRecurring.amount,
              categoryId: currentRecurring.categoryId,
              accountId: currentRecurring.accountId,
              toAccountId: currentRecurring.toAccountId,
              happenedAt: nextDate,
              note: currentRecurring.note,
              recurringId: currentRecurring.id,
              currencyCode: txCurrency,
            );
            await repository.updateLastGeneratedDate(
              currentRecurring.id,
              nextDate,
            );
            created = await repository.getTransactionById(transactionId);
          }

          if (created != null) {
            generatedTransactions.add(created);
          }

          final refreshed =
              (await repository.getAllRecurringTransactions())
                  as List<RecurringTransaction>;
          final matched =
              refreshed.where((r) => r.id == currentRecurring.id).toList();
          if (matched.isEmpty) break;
          currentRecurring = matched.first;
        }
      } catch (e, stackTrace) {
        // 单规则隔离：一条规则异常绝不牵连同账本其它规则或其它账本（#584）
        logger.error(
            _tag, '处理周期交易 id=${recurring.id} 异常，已隔离跳过', e, stackTrace);
      }
    }

    return generatedTransactions;
  }

  /// 获取重复交易的描述文字
  String getFrequencyDescription(
    RecurringTransaction recurring,
    String Function(RecurringFrequency, int) translator,
  ) {
    final frequency = RecurringFrequency.fromString(recurring.frequency);
    return translator(frequency, recurring.interval);
  }

  /// 获取下一次生成时间的描述
  String? getNextGenerationDescription(
    RecurringTransaction recurring,
    String Function(DateTime) formatter,
  ) {
    final upcoming = previewUpcomingOccurrences(
      RecurringScheduleSpec.fromModel(recurring),
      count: 1,
    );
    if (upcoming.isEmpty) return null;
    return formatter(upcoming.first.date);
  }
}
