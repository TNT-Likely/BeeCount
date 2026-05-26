import 'dart:io';

import '../../ai/core/ai_extraction_context.dart';
import '../../ai/core/ai_extraction_engine.dart';
import '../../ai/core/bill_info.dart';
import '../../data/repositories/base_repository.dart';
import '../../l10n/app_localizations.dart';
import '../billing/bill_creation_service.dart';
import '../system/logger_service.dart';
import 'bookkeeping_result.dart';

/// AI 记账应用层 (Layer 2)。
///
/// 5 个调用渠道(对话 / 图片 / 语音 / 自动截图 / 自动通知文本)的统一入口。
/// 内部:
/// 1. 构造 [AiExtractionContext](查用户可用分类 + 同币种账户 + 自定义 prompt)
/// 2. 调底座 [AiExtractionEngine] 拿 `List<BillInfo>`
/// 3. 逐笔通过 [BillCreationService.createFromBill] 落库
/// 4. 聚合成 [BookkeepingResult] 返回
///
/// 渠道层只需 `bookkeeper.fromText/fromImage/fromAudio(...)` 一行调用,
/// 不再重复实现「调 extract → createTx → 同步」样板。
class AiBookkeeper {
  static const String _tag = 'AiBookkeeper';

  final BaseRepository _repo;
  final AiExtractionEngine _engine;
  final BillCreationService _persister;

  const AiBookkeeper({
    required BaseRepository repository,
    required AiExtractionEngine engine,
    required BillCreationService persister,
  })  : _repo = repository,
        _engine = engine,
        _persister = persister;

  /// 文本记账(对话 / 自动通知文本)
  Future<BookkeepingResult> fromText({
    required String text,
    required int ledgerId,
    required List<String> billingTypes,
    AppLocalizations? l10n,
  }) async {
    final context = await AiExtractionContext.forLedger(
      repository: _repo,
      ledgerId: ledgerId,
    );
    final bills = await _engine.extractFromText(text, context);
    return _persistAll(
      bills: bills,
      ledgerId: ledgerId,
      billingTypes: billingTypes,
      l10n: l10n,
    );
  }

  /// 图片记账(相册 / 相机 / 自动截图)
  ///
  /// [onSaved] 每成功保存一笔就回调一次(传入 txId 和这笔在结果中的序号),
  /// 常用于给每笔挂图片附件 — 用户期望多笔记账时每笔都能溯源到原图,所以
  /// 默认行为是「**每笔都挂**」,而非只挂首笔。
  Future<BookkeepingResult> fromImage({
    required File image,
    required int ledgerId,
    required List<String> billingTypes,
    AppLocalizations? l10n,
    Future<void> Function(int txId, int index)? onSaved,
  }) async {
    final context = await AiExtractionContext.forLedger(
      repository: _repo,
      ledgerId: ledgerId,
    );
    final bills = await _engine.extractFromImage(image, context);
    return _persistAll(
      bills: bills,
      ledgerId: ledgerId,
      billingTypes: billingTypes,
      l10n: l10n,
      onSaved: onSaved,
    );
  }

  /// 语音记账。第二项返回值是 STT 识别出的原始文本(便于 UI 在记账失败时
  /// 展示「未识别账单信息: {text}」)。
  Future<({BookkeepingResult result, String? recognizedText})> fromAudio({
    required File audio,
    required int ledgerId,
    required List<String> billingTypes,
    AppLocalizations? l10n,
  }) async {
    final context = await AiExtractionContext.forLedger(
      repository: _repo,
      ledgerId: ledgerId,
    );
    final audioResult = await _engine.extractFromAudio(audio, context);
    final result = await _persistAll(
      bills: audioResult.bills,
      ledgerId: ledgerId,
      billingTypes: billingTypes,
      l10n: l10n,
    );
    return (result: result, recognizedText: audioResult.recognizedText);
  }

  /// 仅语音转文字(快捷指令首步,不走提取)
  Future<String?> speechToText(File audio) => _engine.speechToText(audio);

  // ============================================================
  // 内部:落库 + 聚合结果
  // ============================================================

  Future<BookkeepingResult> _persistAll({
    required List<BillInfo> bills,
    required int ledgerId,
    required List<String> billingTypes,
    AppLocalizations? l10n,
    Future<void> Function(int txId, int index)? onSaved,
  }) async {
    if (bills.isEmpty) {
      return BookkeepingResult.empty;
    }

    final saved = <BillInfo>[];
    final txIds = <int>[];
    var failed = 0;

    for (var i = 0; i < bills.length; i++) {
      final bill = bills[i].copyWith(ledgerId: ledgerId);
      try {
        final txId = await _persister.createFromBill(
          bill: bill,
          ledgerId: ledgerId,
          billingTypes: billingTypes,
          l10n: l10n,
        );
        if (txId == null) {
          failed++;
          logger.warning(_tag, '第 ${i + 1} 笔创建失败: ${bill.toJson()}');
          continue;
        }

        // 1. **优先**触发 onSaved 回调(主要用于保存图片附件)。
        //    放在 _enrichWithActualNames 前面是为了缩短附件保存的时间窗口 ——
        //    iOS 后台 launch 场景下,用户随时可能切走 / 关 app 导致进程被 kill。
        //    enrich 是给 UI 卡片显示用,被 kill 影响的只是名称展示,不影响数据
        //    完整性;附件被 kill 才是数据丢失。
        if (onSaved != null) {
          try {
            await onSaved(txId, txIds.length);
          } catch (e, st) {
            logger.error(_tag, 'onSaved 回调异常,不影响主流程', e, st);
          }
        }

        // 2. 查实际入库的 category / account 名称,回填到 BillInfo
        //    (UI 卡片显示用,避免显示 AI 原始名称)。
        //    enrich 自带兜底不会抛,但即便抛了也要保 savedBills/txIds 长度对齐。
        BillInfo enriched;
        try {
          enriched = await _enrichWithActualNames(bill, txId);
        } catch (e, st) {
          logger.error(_tag, 'enrichWithActualNames 异常,用 AI 原始 BillInfo',
              e, st);
          enriched = bill;
        }
        saved.add(enriched);
        txIds.add(txId);
      } catch (e, st) {
        failed++;
        logger.error(_tag, '第 ${i + 1} 笔创建异常', e, st);
      }
    }

    if (failed > 0) {
      logger.warning(_tag, '成功 ${txIds.length} 笔,失败 $failed 笔');
    }

    return BookkeepingResult(
      savedBills: List.unmodifiable(saved),
      transactionIds: List.unmodifiable(txIds),
      failedCount: failed,
    );
  }

  /// 查询实际入库的分类/账户名称,回填到 BillInfo。AI 给的可能是"奶茶"
  /// 但 BillCreationService 匹配到的可能是"餐饮",卡片要显示后者。
  Future<BillInfo> _enrichWithActualNames(BillInfo bill, int txId) async {
    try {
      final tx = await _repo.getTransactionById(txId);
      if (tx == null) return bill;
      String? actualCategory;
      String? actualAccount;
      if (tx.categoryId != null) {
        final cat = await _repo.getCategoryById(tx.categoryId!);
        actualCategory = cat?.name;
      }
      if (tx.accountId != null) {
        final acc = await _repo.getAccount(tx.accountId!);
        actualAccount = acc?.name;
      }
      return bill.copyWith(
        category: actualCategory ?? bill.category,
        account: actualAccount ?? bill.account,
      );
    } catch (e, st) {
      logger.error(_tag, '回填实际名称失败,使用 AI 原始名称', e, st);
      return bill;
    }
  }
}
