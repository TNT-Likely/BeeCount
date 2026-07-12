import 'package:flutter_riverpod/flutter_riverpod.dart';

// 导入任务进度：用于显示"后台导入中"状态与进度
class ImportProgress {
  final bool running;
  final int total;
  final int done;
  final int ok;
  final int fail;
  final int? ledgerId; // 关联的账本ID，用于导入完成后触发刷新
  final int skipped; // 跳过的记录数
  final Map<String, int> skippedTypes; // 跳过的类型及数量

  const ImportProgress({
    required this.running,
    required this.total,
    required this.done,
    required this.ok,
    required this.fail,
    this.ledgerId,
    this.skipped = 0,
    this.skippedTypes = const {},
  });

  ImportProgress copyWith({
    bool? running,
    int? total,
    int? done,
    int? ok,
    int? fail,
    int? ledgerId,
    int? skipped,
    Map<String, int>? skippedTypes,
  }) =>
      ImportProgress(
        running: running ?? this.running,
        total: total ?? this.total,
        done: done ?? this.done,
        ok: ok ?? this.ok,
        fail: fail ?? this.fail,
        ledgerId: ledgerId ?? this.ledgerId,
        skipped: skipped ?? this.skipped,
        skippedTypes: skippedTypes ?? this.skippedTypes,
      );

  /// 判断是否刚完成导入（从运行中变为完成状态）
  bool get isJustCompleted => !running && total > 0;

  static const empty =
      ImportProgress(running: false, total: 0, done: 0, ok: 0, fail: 0);
}

final importProgressProvider =
    StateProvider<ImportProgress>((ref) => ImportProgress.empty);

// 云端恢复进度（登录后的一键恢复）
class CloudRestoreProgress {
  final bool running;
  final int totalLedgers;
  final int currentIndex; // 1-based
  final String? currentLedgerName;
  final int currentTotal; // 当前账本总记录数
  final int currentDone; // 当前账本已处理条数
  const CloudRestoreProgress({
    required this.running,
    required this.totalLedgers,
    required this.currentIndex,
    required this.currentLedgerName,
    required this.currentTotal,
    required this.currentDone,
  });
  CloudRestoreProgress copyWith({
    bool? running,
    int? totalLedgers,
    int? currentIndex,
    String? currentLedgerName,
    int? currentTotal,
    int? currentDone,
  }) =>
      CloudRestoreProgress(
        running: running ?? this.running,
        totalLedgers: totalLedgers ?? this.totalLedgers,
        currentIndex: currentIndex ?? this.currentIndex,
        currentLedgerName: currentLedgerName ?? this.currentLedgerName,
        currentTotal: currentTotal ?? this.currentTotal,
        currentDone: currentDone ?? this.currentDone,
      );
  static const empty = CloudRestoreProgress(
      running: false,
      totalLedgers: 0,
      currentIndex: 0,
      currentLedgerName: null,
      currentTotal: 0,
      currentDone: 0);
}

final cloudRestoreProgressProvider =
    StateProvider<CloudRestoreProgress>((ref) => CloudRestoreProgress.empty);

// 云端恢复完成摘要
class CloudRestoreSummary {
  final int totalLedgers;
  final int successLedgers;
  final int failedLedgers;
  final int totalImported; // 累计导入（含跳过）
  final List<String> failedDetails; // 每个失败账本的原因摘要
  const CloudRestoreSummary({
    required this.totalLedgers,
    required this.successLedgers,
    required this.failedLedgers,
    required this.totalImported,
    required this.failedDetails,
  });
}

final cloudRestoreSummaryProvider =
    StateProvider<CloudRestoreSummary?>((ref) => null);

// 云端恢复日志（仅 UI 展示用途，保留最近若干行）
final cloudRestoreLogProvider =
    StateProvider<List<String>>((ref) => const <String>[]);
