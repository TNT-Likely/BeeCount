import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/base_repository.dart';
import '../providers/ai_constants.dart';

/// AI 多模态记账底座 · 上下文
///
/// 把 prompt 拼装需要的「用户可用分类 / 账户 / 自定义模板」打包成 value
/// object,由应用层显式构造后传入底座。底座只读取字段,**不**反向依赖
/// Repository / SharedPreferences。
class AiExtractionContext {
  /// 用户可用支出分类(已过滤掉有子分类的父分类)
  final List<String> expenseCategories;

  /// 用户可用收入分类
  final List<String> incomeCategories;

  /// 与当前账本币种相同的账户名称
  final List<String> accounts;

  /// 用户自定义 prompt 模板。`null` 或空白 = 使用默认模板。
  final String? customPromptTemplate;

  const AiExtractionContext({
    this.expenseCategories = const [],
    this.incomeCategories = const [],
    this.accounts = const [],
    this.customPromptTemplate,
  });

  /// 无账本场景的 fallback。prompt 走 hardcoded 默认分类,至少能识别金额。
  static const AiExtractionContext fallback = AiExtractionContext();

  /// 根据当前账本查询用户可用分类 + 同币种账户,再加载用户自定义 prompt
  /// 模板,组装成 context。
  ///
  /// 5 个调用渠道(chat / image / voice / auto-screenshot / auto-text)统一
  /// 用这个工厂,避免重复 query 与漏传字段。
  static Future<AiExtractionContext> forLedger({
    required BaseRepository repository,
    required int ledgerId,
  }) async {
    final expenseCats = await repository.getUsableCategories('expense');
    final incomeCats = await repository.getUsableCategories('income');

    final accountNames = <String>[];
    final ledger = await repository.getLedgerById(ledgerId);
    if (ledger != null) {
      final allAccounts = await repository.getAllAccounts();
      accountNames.addAll(allAccounts
          .where((a) => a.currency == ledger.currency)
          .map((a) => a.name));
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AIConstants.keyAiCustomPrompt);
    final customTemplate =
        (saved != null && saved.trim().isNotEmpty) ? saved : null;

    return AiExtractionContext(
      expenseCategories: expenseCats.map((c) => c.name).toList(),
      incomeCategories: incomeCats.map((c) => c.name).toList(),
      accounts: accountNames,
      customPromptTemplate: customTemplate,
    );
  }
}
