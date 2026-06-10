import 'ledger_repository.dart';
import 'transaction_repository.dart';
import 'category_repository.dart';
import 'account_repository.dart';
import 'statistics_repository.dart';
import 'recurring_transaction_repository.dart';
import 'ai_repository.dart';
import 'tag_repository.dart';
import 'budget_repository.dart';
import 'attachment_repository.dart';
import 'exchange_rate_repository.dart';

/// 基础 Repository 抽象类
/// 组合所有 Repository 接口，用于类型约束
/// LocalRepository、CloudRepository、ApiRepository 等都应该实现这个抽象类
///
/// 设计原则：
/// - 不包含任何具体实现细节（如数据库访问）
/// - 仅定义数据访问的抽象接口
/// - 支持无缝切换不同的数据源实现
abstract class BaseRepository
    implements
        LedgerRepository,
        TransactionRepository,
        CategoryRepository,
        AccountRepository,
        StatisticsRepository,
        RecurringTransactionRepository,
        AIRepository,
        TagRepository,
        BudgetRepository,
        AttachmentRepository,
        ExchangeRateRepository {}
