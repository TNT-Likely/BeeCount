import 'dart:io';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart';
import '../l10n/app_localizations.dart';
import '../services/data/category_service.dart';
import '../services/data/seed_service.dart';
import '../services/system/logger_service.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'db.g.dart';

// --- Tables ---

class Ledgers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get type => text().withDefault(const Constant('personal'))();  // personal / shared
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // 跨设备同步唯一标识：跟 accounts/categories/tags 的 syncId 同语义，
  // 对齐 BeeCount Cloud server 的 ledger.external_id。device B 首次登录
  // 通过 readLedgers() 拉到的 ext_id 会写到这里，后续 push/pull 都用这个
  // 做设备间的 ledger 匹配，而不是本地 autoIncrement id（A/B 本地 id 必然
  // 不一致）。v21 migration 里已为旧数据把 id 回填成 syncId 以兼容。
  TextColumn get syncId => text().nullable()();
  // v24: 共享账本字段 — server 端 LedgerMember.role 同步下来
  TextColumn get myRole => text().withDefault(const Constant('owner'))();  // owner / editor
  IntColumn get memberCount => integer().withDefault(const Constant(1))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  TextColumn get ownerUserId => text().nullable()();  // 当前 Owner 是谁
  // v27: 自定义每月起始日(1-28),统计/预算/小部件按 [当月N日, 次月N日) 聚合,
  // 1=自然月。随 sync 跨设备(payload key `monthStartDay`,server 列
  // ledgers.month_start_day)。见 .docs/period-start-date/design.md。
  IntColumn get monthStartDay => integer().withDefault(const Constant(1))();
}

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer()(); // 保留用于v2迁移，后续会移除
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('cash'))();
  TextColumn get currency =>
      text().withDefault(const Constant('CNY'))(); // v1.15.0新增：币种
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt =>
      dateTime().nullable()(); // v1.15.0: 改为可空，避免迁移问题
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))(); // 排序顺序，数字越小越靠前
  RealColumn get creditLimit => real().nullable()(); // 信用额度
  IntColumn get billingDay => integer().nullable()(); // 账单日 (1-28)
  IntColumn get paymentDueDay => integer().nullable()(); // 还款日 (1-28)
  TextColumn get bankName => text().nullable()(); // 开户行
  TextColumn get cardLastFour => text().nullable()(); // 卡号后四位
  TextColumn get note => text().nullable()(); // 备注
  TextColumn get syncId => text().nullable()(); // 跨设备同步唯一标识 (UUID)
}

/// 自动汇率本地缓存。日期键 append-only;可随时整表重建 → **不进同步**(README D2)。
/// 方向:1 quote = rate base(rate 为 decimal 字符串)。
class ExchangeRates extends Table {
  TextColumn get baseCurrency => text()();
  TextColumn get quoteCurrency => text()();
  TextColumn get rateDate => text()(); // 'YYYY-MM-DD',取源数据自带日期
  TextColumn get rate => text()();
  TextColumn get source => text()(); // 'server'|'fawazahmed0'|'frankfurter'
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {baseCurrency, quoteCurrency, rateDate};
}

/// 手动汇率覆盖:固定生效直到删除(README D9)。user-global 同步实体,
/// 字段约定对齐 Accounts(syncId UUID)。方向同 ExchangeRates:1 quote = rate base。
/// 业务唯一键 (baseCurrency, quoteCurrency),唯一索引在 v28 迁移建。
class ExchangeRateOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get baseCurrency => text()();
  TextColumn get quoteCurrency => text()();
  TextColumn get rate => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // expense / income
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))(); // 排序顺序，数字越小越靠前
  IntColumn get parentId => integer().nullable()(); // 父分类ID，null 表示一级分类
  IntColumn get level =>
      integer().withDefault(const Constant(1))(); // 层级：1=一级，2=二级
  // v13: 自定义图标支持
  TextColumn get iconType =>
      text().withDefault(const Constant('material'))(); // material / custom / community
  TextColumn get customIconPath => text().nullable()(); // 自定义图标本地路径
  TextColumn get communityIconId => text().nullable()(); // 社区图标ID（预留）
  TextColumn get syncId => text().nullable()(); // 跨设备同步唯一标识 (UUID)
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer()();
  TextColumn get type => text()(); // expense / income / transfer
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get accountId => integer().nullable()();
  IntColumn get toAccountId => integer().nullable()();
  DateTimeColumn get happenedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  IntColumn get recurringId => integer().nullable()(); // 关联到重复交易模板
  TextColumn get syncId => text().nullable()(); // 跨设备同步唯一标识 (UUID)
  // v24: 共享账本"谁记的"显示
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get lastEditedByUserId => text().nullable()();
  // v25: 共享账本 sync_id override(§7 决策)
  // Editor 在共享账本下记 tx 时,选 Owner 的 SharedLedger{Categories,Accounts,Tags}
  // 行,但本地 Categories/Accounts/Tags 主表没有对应 int id。这些 override
  // 字段直接存 Owner 的 syncId 字符串,categoryId / accountId 留 null;sync push
  // 时序列化优先用 override(server LWW key 是 syncId,主表 syncId 也是 string)。
  // Owner / 单人账本场景:override 字段为 null,走老路径(categoryId int 反查
  // Categories.syncId)。
  TextColumn get categorySyncIdOverride => text().nullable()();
  TextColumn get accountSyncIdOverride => text().nullable()();
  TextColumn get toAccountSyncIdOverride => text().nullable()();
  TextColumn get tagSyncIdsOverride => text().nullable()();  // JSON list

  /// 不计入收支:true 时从收支统计/图表/月年汇总剔除,但仍计入账户余额、净资产、
  /// 账单列表(.docs/transaction-flags/01 §二 D1)。
  BoolColumn get excludeFromStats =>
      boolean().withDefault(const Constant(false))();

  /// 不计入预算:true 时从预算用量剔除。与 excludeFromStats 完全独立(D2)。
  BoolColumn get excludeFromBudget =>
      boolean().withDefault(const Constant(false))();
}

class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer()();
  TextColumn get type => text()(); // expense / income / transfer
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable()(); // 转账时为null
  IntColumn get accountId => integer().nullable()();
  IntColumn get toAccountId => integer().nullable()(); // 转账的目标账户
  TextColumn get note => text().nullable()();

  // 重复规则
  TextColumn get frequency => text()(); // daily / weekly / monthly / yearly
  IntColumn get interval =>
      integer().withDefault(const Constant(1))(); // 间隔（每1天、每2周等）
  IntColumn get dayOfMonth => integer().nullable()(); // 月的第几天（1-31）
  IntColumn get dayOfWeek => integer().nullable()(); // 周几（1=周一, 7=周日）
  IntColumn get monthOfYear => integer().nullable()(); // 哪个月（1-12，用于yearly）

  // 时间范围
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()(); // 为空表示永久
  DateTimeColumn get lastGeneratedDate =>
      dateTime().nullable()(); // 最后一次生成交易的日期

  // 状态
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// AI 对话表
class Conversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  @Deprecated('对话已改为全局，不再与账本关联')
  IntColumn get ledgerId => integer().nullable()();
  TextColumn get title => text().withDefault(const Constant('AI对话'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// AI 消息表
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId => integer()();
  TextColumn get role => text()(); // 'user' | 'assistant'
  TextColumn get content => text()();
  TextColumn get messageType => text()(); // 'text' | 'bill_card'
  TextColumn get metadata => text().nullable()(); // JSON (BillInfo 数据)
  IntColumn get transactionId => integer().nullable()(); // 关联的交易ID(撤销用)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 标签表
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();                    // 标签名称
  TextColumn get color => text().nullable()();        // 颜色值（如 #FF5722）
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();  // 排序
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncId => text().nullable()(); // 跨设备同步唯一标识 (UUID)
}

// 本地变更追踪表（用于增量同步）
class LocalChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();       // transaction/account/category/tag
  IntColumn get entityId => integer()();       // 本地实体ID
  TextColumn get entitySyncId => text()();     // 实体的 syncId (UUID)
  IntColumn get ledgerId => integer()();       // 关联账本ID
  TextColumn get action => text()();           // create/update/delete
  TextColumn get payloadJson => text().nullable()(); // 变更后的完整 JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get pushedAt => dateTime().nullable()(); // 非null表示已推送
}

// 同步状态表
class SyncState extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();         // 设备唯一标识
  TextColumn get providerType => text().withDefault(const Constant('beecount_cloud'))(); // 防止不同 provider 的 cursor 冲突
  IntColumn get serverCursor => integer().withDefault(const Constant(0))(); // 服务端变更游标
  DateTimeColumn get lastPushAt => dateTime().nullable()();
  DateTimeColumn get lastPullAt => dateTime().nullable()();
}

// 交易-标签关联表
class TransactionTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer()();         // 交易ID
  IntColumn get tagId => integer()();                 // 标签ID
}

// v27: 共享账本 §7 — 交易标签 sync_id override
// Editor 在共享账本下记 tx 选 Owner 的 tag,Tag 主表没该行(SharedLedgerTags
// 才有),传统 transaction_tags.tag_id 没法存 (本地 int id 不存在)。这张
// override 表按 (transaction_id, tag_sync_id) 存,sync push 时 union 进 tagIds
// payload;tx 反查 / 编辑回显时 union 主表 transaction_tags + 本表。
class TransactionTagOverrides extends Table {
  TextColumn get transactionSyncId => text()();   // tx.syncId(全局唯一)
  TextColumn get tagSyncId => text()();           // Owner tag syncId
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {transactionSyncId, tagSyncId};
}

// v26: sync pull 时 server 端下发的 change 在本地 apply 抛错的持久化记录。
// 健康用户这张表是空的;只在出错时写入,供 UI 暴露 + 用户重试/跳过 + 开发者
// 远程诊断。详见 .docs/full-pull-refactor/04-data-model.md。
class SyncPullErrors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get changeId => integer().unique()();      // server change_id,唯一
  TextColumn get ledgerExternalId => text().nullable()(); // user-global change 可空
  TextColumn get entityType => text()();
  TextColumn get entitySyncId => text()();
  TextColumn get action => text()();                   // upsert / delete
  TextColumn get rawChangeJson => text()();            // 完整 change JSON,供诊断 + 复制给用户
  TextColumn get errorClass => text().nullable()();    // Dart exception 类名
  TextColumn get errorMessage => text().nullable()();  // exception.toString() 首行
  TextColumn get stackTrace => text().nullable()();    // 截断到 ~2KB
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(1))();
  TextColumn get userAction => text().nullable()();    // null / 'skip' / 'retry_requested'
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

// 交易附件表
class TransactionAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer()(); // 关联的交易ID
  TextColumn get fileName => text()();        // 文件名（不含路径）
  TextColumn get originalName => text().nullable()(); // 原始文件名
  IntColumn get fileSize => integer().nullable()();   // 文件大小（bytes）
  IntColumn get width => integer().nullable()();      // 图片宽度
  IntColumn get height => integer().nullable()();     // 图片高度
  IntColumn get sortOrder => integer().withDefault(const Constant(0))(); // 排序序号
  TextColumn get cloudFileId => text().nullable()();   // 云端文件ID
  TextColumn get cloudSha256 => text().nullable()();   // 云端文件SHA256
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 预算表
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 跨设备同步 syncId(UUID)。v22 新增,migration 给老行补 UUID;之后每次 create
  /// 都必须填。server 端按此做 entity_sync_id,跨设备 LWW 合并。
  TextColumn get syncId => text().nullable()();

  /// 关联账本ID
  IntColumn get ledgerId => integer()();

  /// 预算类型：total-总预算, category-分类预算
  TextColumn get type => text().withDefault(const Constant('total'))();

  /// 关联分类ID（仅分类预算有值）
  IntColumn get categoryId => integer().nullable()();

  /// 预算金额
  RealColumn get amount => real()();

  /// 预算周期：monthly-月度, weekly-周度, yearly-年度
  TextColumn get period => text().withDefault(const Constant('monthly'))();

  /// 周期起始日（1-31，月度预算；1-7，周度预算）
  IntColumn get startDay => integer().withDefault(const Constant(1))();

  /// 是否启用
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// 共享账本(v24)
// ============================================================================

/// 账本成员镜像表。server `LedgerMember` 表的本地副本,用于"X 记的"显示 +
/// 离线渲染。`GET /api/v1/ledgers/{id}/members` 拉来后写入;`member_change`
/// WS 事件触发增量更新。
class LedgerMembers extends Table {
  TextColumn get ledgerSyncId => text()();        // ledger.syncId(全 user 唯一)
  TextColumn get userId => text()();
  TextColumn get email => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get role => text()();                // owner / editor
  DateTimeColumn get joinedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();   // 本地更新时间,用于 cache 失效

  @override
  Set<Column> get primaryKey => {ledgerSyncId, userId};
}

/// 共享账本里 Owner 的 user-global 分类镜像。Editor 在共享账本下打开"选分类"
/// 弹窗读这表(而非自己的 Categories)。`GET /api/v1/ledgers/{id}/shared-resources`
/// 拉来落库;`shared_resource_change` WS 事件增量更新。
class SharedLedgerCategories extends Table {
  TextColumn get ledgerSyncId => text()();
  TextColumn get syncId => text()();              // Owner 的 user-global category sync_id
  TextColumn get name => text()();
  TextColumn get kind => text()();                // expense / income
  TextColumn get icon => text().nullable()();
  TextColumn get iconType => text().withDefault(const Constant('material'))();
  TextColumn get iconCloudFileId => text().nullable()();   // 自定义图标:attachment UUID
  TextColumn get iconCloudSha256 => text().nullable()();   // 自定义图标:sha256(本地 cache 去重)
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  TextColumn get parentName => text().nullable()();
  // v25 共享账本二级分类:parent 的 syncId,用于 picker 建稳定父子链
  // (parent_name 兜底/显示,parent_sync_id 主)。
  TextColumn get parentSyncId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ledgerSyncId, syncId};
}

/// 共享账本里 Owner 的 user-global 账户镜像。
class SharedLedgerAccounts extends Table {
  TextColumn get ledgerSyncId => text()();
  TextColumn get syncId => text()();
  TextColumn get name => text()();
  TextColumn get accountType => text().withDefault(const Constant('cash'))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get note => text().nullable()();
  RealColumn get initialBalance => real().nullable()();
  RealColumn get creditLimit => real().nullable()();
  IntColumn get billingDay => integer().nullable()();
  IntColumn get paymentDueDay => integer().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get cardLastFour => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ledgerSyncId, syncId};
}

/// 共享账本里 Owner 的 user-global 标签镜像。
class SharedLedgerTags extends Table {
  TextColumn get ledgerSyncId => text()();
  TextColumn get syncId => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ledgerSyncId, syncId};
}

@DriftDatabase(tables: [
  Ledgers,
  Accounts,
  Categories,
  Transactions,
  RecurringTransactions,
  Conversations,
  Messages,
  Tags,
  TransactionTags,
  Budgets,
  TransactionAttachments,
  LocalChanges,
  SyncState,
  LedgerMembers,
  SharedLedgerCategories,
  SharedLedgerAccounts,
  SharedLedgerTags,
  TransactionTagOverrides,
  SyncPullErrors,
  ExchangeRates,
  ExchangeRateOverrides,
])
class BeeDatabase extends _$BeeDatabase {
  BeeDatabase() : super(_openConnection());

  /// 测试专用:直接注入 [QueryExecutor](通常是 NativeDatabase.memory()),
  /// 跳过 [_openConnection] 的文件系统 / 平台副作用。test/ 下的 unit test
  /// 用这个。
  BeeDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 29; // v29: 账单标记 — exclude_from_stats / exclude_from_budget

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            // 添加 sortOrder 字段（使用原始 SQL，因为此时代码还未生成）
            await customStatement(
                'ALTER TABLE categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;');

            // 为现有分类设置默认的 sortOrder（按 id 顺序）
            await customStatement('''
          UPDATE categories
          SET sort_order = (
            SELECT COUNT(*)
            FROM categories AS c2
            WHERE c2.id <= categories.id
          ) - 1;
        ''');
          }
          if (from < 3) {
            // 创建重复交易表
            await migrator.createTable(recurringTransactions);

            // 为 transactions 表添加 recurring_id 字段
            await customStatement(
                'ALTER TABLE transactions ADD COLUMN recurring_id INTEGER;');
          }
          if (from < 4) {
            // 为 accounts 表添加 initial_balance 字段
            await customStatement(
                'ALTER TABLE accounts ADD COLUMN initial_balance REAL NOT NULL DEFAULT 0.0;');
          }
          if (from < 5) {
            // v5: 账户独立改造
            // 注意：数据迁移逻辑在 MigrationService 中统一处理
            // 这里只添加必要的字段

            // 检查字段是否已存在，避免重复添加
            final tableInfo =
                await customSelect('PRAGMA table_info(accounts)').get();
            final hasCurrency =
                tableInfo.any((row) => row.data['name'] == 'currency');
            final hasCreatedAt =
                tableInfo.any((row) => row.data['name'] == 'created_at');
            final hasUpdatedAt =
                tableInfo.any((row) => row.data['name'] == 'updated_at');

            if (!hasCurrency) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN currency TEXT NOT NULL DEFAULT \'CNY\';');
            }

            if (!hasCreatedAt) {
              // SQLite 不支持非常量默认值，先添加可空字段，然后更新
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN created_at INTEGER;');
              await customStatement(
                  'UPDATE accounts SET created_at = strftime(\'%s\', \'now\') WHERE created_at IS NULL;');
            }

            if (!hasUpdatedAt) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN updated_at INTEGER;');
            }

            // 注意：不在onUpgrade中更新currency数据
            // 数据迁移统一由 MigrationService 处理，避免重复逻辑
          }
          if (from < 6) {
            // v6: 二级分类支持
            // 检查字段是否已存在，避免重复添加
            final tableInfo =
                await customSelect('PRAGMA table_info(categories)').get();
            final hasParentId =
                tableInfo.any((row) => row.data['name'] == 'parent_id');
            final hasLevel =
                tableInfo.any((row) => row.data['name'] == 'level');

            if (!hasParentId) {
              await customStatement(
                  'ALTER TABLE categories ADD COLUMN parent_id INTEGER;');
            }

            if (!hasLevel) {
              await customStatement(
                  'ALTER TABLE categories ADD COLUMN level INTEGER NOT NULL DEFAULT 1;');
            }

            // 确保所有现有分类的 level 都为 1（一级分类）
            await customStatement(
                'UPDATE categories SET level = 1 WHERE level IS NULL OR level = 0;');
          }
          if (from < 7) {
            print('[DB Migration] 开始迁移到 v7: 周期账单支持转账');
            // v7: 周期账单支持转账
            // 需要将 category_id 改为可空，并添加 to_account_id 字段
            // SQLite 不支持修改列约束，所以需要重建表

            // 1. 创建新表
            print('[DB Migration] 步骤1: 创建新表');
            await customStatement('''
              CREATE TABLE IF NOT EXISTS recurring_transactions_new (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                ledger_id INTEGER NOT NULL,
                type TEXT NOT NULL,
                amount REAL NOT NULL,
                category_id INTEGER,
                account_id INTEGER,
                to_account_id INTEGER,
                note TEXT,
                frequency TEXT NOT NULL,
                interval INTEGER NOT NULL DEFAULT 1,
                day_of_month INTEGER,
                day_of_week INTEGER,
                month_of_year INTEGER,
                start_date INTEGER NOT NULL,
                end_date INTEGER,
                last_generated_date INTEGER,
                enabled INTEGER NOT NULL DEFAULT 1,
                created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
                updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
              );
            ''');

            // 2. 复制数据
            print('[DB Migration] 步骤2: 复制数据');
            await customStatement('''
              INSERT INTO recurring_transactions_new
              (id, ledger_id, type, amount, category_id, account_id, to_account_id, note,
               frequency, interval, day_of_month, day_of_week, month_of_year,
               start_date, end_date, last_generated_date, enabled, created_at, updated_at)
              SELECT id, ledger_id, type, amount, category_id, account_id,
                     NULL as to_account_id, note,
                     frequency, interval, day_of_month, day_of_week, month_of_year,
                     start_date, end_date, last_generated_date, enabled, created_at, updated_at
              FROM recurring_transactions;
            ''');

            // 3. 删除旧表
            print('[DB Migration] 步骤3: 删除旧表');
            await customStatement('DROP TABLE recurring_transactions;');

            // 4. 重命名新表
            print('[DB Migration] 步骤4: 重命名新表');
            await customStatement('ALTER TABLE recurring_transactions_new RENAME TO recurring_transactions;');
            print('[DB Migration] v7 迁移完成');
          }
          if (from < 8) {
            // v8: AI 对话助手
            print('[DB Migration] 开始迁移到 v8: AI 对话助手');
            await migrator.createTable(conversations);
            await migrator.createTable(messages);
            logger.info('DB', 'v8 迁移完成: AI Chat tables created');
            print('[DB Migration] v8 迁移完成');
          }
          if (from < 9) {
            // v9: 为 ledgers 表添加 type 字段（支持家庭账本）
            print('[DB Migration] 开始迁移到 v9: 添加 ledgers.type 字段');

            // 检查字段是否已存在，避免重复添加
            final tableInfo =
                await customSelect('PRAGMA table_info(ledgers)').get();
            final hasType =
                tableInfo.any((row) => row.data['name'] == 'type');

            if (!hasType) {
              await customStatement(
                  'ALTER TABLE ledgers ADD COLUMN type TEXT NOT NULL DEFAULT \'personal\';');
              logger.info('DB', 'v9 迁移完成: ledgers.type 字段已添加');
            } else {
              logger.info('DB', 'v9 迁移跳过: ledgers.type 字段已存在');
            }

            print('[DB Migration] v9 迁移完成');
          }
          if (from < 10) {
            // v10: 添加标签功能
            print('[DB Migration] 开始迁移到 v10: 添加标签功能');

            // 创建 tags 表
            await migrator.createTable(tags);
            logger.info('DB', 'v10: tags 表已创建');

            // 创建 transaction_tags 关联表
            await migrator.createTable(transactionTags);
            logger.info('DB', 'v10: transaction_tags 表已创建');

            // 创建索引以提高查询性能
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_transaction_tags_transaction ON transaction_tags(transaction_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_transaction_tags_tag ON transaction_tags(tag_id)');
            logger.info('DB', 'v10: 索引已创建');

            print('[DB Migration] v10 迁移完成');
          }
          if (from < 11) {
            // v11: 添加预算功能
            print('[DB Migration] 开始迁移到 v11: 添加预算功能');

            // 创建 budgets 表
            await migrator.createTable(budgets);
            logger.info('DB', 'v11: budgets 表已创建');

            // 创建索引以提高查询性能
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_budgets_ledger ON budgets(ledger_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_budgets_ledger_type ON budgets(ledger_id, type)');
            logger.info('DB', 'v11: 预算索引已创建');

            print('[DB Migration] v11 迁移完成');
          }
          if (from < 12) {
            // v12: 添加交易附件功能
            print('[DB Migration] 开始迁移到 v12: 添加交易附件功能');

            // 创建 transaction_attachments 表
            await migrator.createTable(transactionAttachments);
            logger.info('DB', 'v12: transaction_attachments 表已创建');

            // 创建索引以提高查询性能
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_attachments_transaction ON transaction_attachments(transaction_id)');
            logger.info('DB', 'v12: 附件索引已创建');

            print('[DB Migration] v12 迁移完成');
          }
          if (from < 13) {
            // v13: 分类自定义图标支持
            print('[DB Migration] 开始迁移到 v13: 分类自定义图标支持');

            // 检查字段是否已存在，避免重复添加
            final tableInfo =
                await customSelect('PRAGMA table_info(categories)').get();
            final hasIconType =
                tableInfo.any((row) => row.data['name'] == 'icon_type');
            final hasCustomIconPath =
                tableInfo.any((row) => row.data['name'] == 'custom_icon_path');
            final hasCommunityIconId =
                tableInfo.any((row) => row.data['name'] == 'community_icon_id');

            if (!hasIconType) {
              await customStatement(
                  "ALTER TABLE categories ADD COLUMN icon_type TEXT NOT NULL DEFAULT 'material';");
              logger.info('DB', 'v13: icon_type 字段已添加');
            }

            if (!hasCustomIconPath) {
              await customStatement(
                  'ALTER TABLE categories ADD COLUMN custom_icon_path TEXT;');
              logger.info('DB', 'v13: custom_icon_path 字段已添加');
            }

            if (!hasCommunityIconId) {
              await customStatement(
                  'ALTER TABLE categories ADD COLUMN community_icon_id TEXT;');
              logger.info('DB', 'v13: community_icon_id 字段已添加');
            }

            print('[DB Migration] v13 迁移完成');
          }
          if (from < 14) {
            // v14: 迁移转账记录到虚拟转账分类
            print('[DB Migration] 开始迁移到 v14: 迁移转账记录到虚拟转账分类');
            await SeedService.migrateTransferTransactions(this);
            logger.info('DB', 'v14 迁移完成: 转账记录已关联到虚拟转账分类');
            print('[DB Migration] v14 迁移完成');
          }
          if (from < 15) {
            // v15: 交易添加 syncId 用于云同步
            print('[DB Migration] 开始迁移到 v15: 添加 syncId 字段');

            // 1. 添加 sync_id 列
            await customStatement(
                'ALTER TABLE transactions ADD COLUMN sync_id TEXT;');
            logger.info('DB', 'v15: sync_id 字段已添加');

            // 2. 为所有已有交易生成 UUID v4
            // 使用 SQLite 内置函数生成简易唯一ID（hex + random）
            // 格式: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
            await customStatement('''
              UPDATE transactions SET sync_id =
                lower(hex(randomblob(4))) || '-' ||
                lower(hex(randomblob(2))) || '-4' ||
                substr(lower(hex(randomblob(2))),2) || '-' ||
                substr('89ab', abs(random()) % 4 + 1, 1) ||
                substr(lower(hex(randomblob(2))),2) || '-' ||
                lower(hex(randomblob(6)))
              WHERE sync_id IS NULL;
            ''');
            logger.info('DB', 'v15: 已为现有交易回填 syncId');

            // 3. 创建索引
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_transactions_sync_id ON transactions(sync_id);');
            logger.info('DB', 'v15: syncId 索引已创建');

            print('[DB Migration] v15 迁移完成');
          }
          if (from < 16) {
            // v16: 账户添加 sortOrder 排序字段
            print('[DB Migration] 开始迁移到 v16: 账户排序');

            await customStatement(
                'ALTER TABLE accounts ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;');
            logger.info('DB', 'v16: sort_order 字段已添加');

            // 回填：按 type 分组，组内按 created_at 排序赋值 sortOrder
            await customStatement('''
              UPDATE accounts SET sort_order = (
                SELECT COUNT(*)
                FROM accounts AS a2
                WHERE a2.type = accounts.type
                  AND (a2.created_at < accounts.created_at
                       OR (a2.created_at = accounts.created_at AND a2.id < accounts.id)
                       OR (a2.created_at IS NULL AND accounts.created_at IS NOT NULL)
                       OR (a2.created_at IS NULL AND accounts.created_at IS NULL AND a2.id < accounts.id))
              );
            ''');
            logger.info('DB', 'v16: 已为现有账户回填 sortOrder');

            print('[DB Migration] v16 迁移完成');
          }
          if (from < 17) {
            // v17: 账户添加信用卡字段
            print('[DB Migration] 开始迁移到 v17: 信用卡字段');

            final tableInfo =
                await customSelect('PRAGMA table_info(accounts)').get();
            final hasCreditLimit =
                tableInfo.any((row) => row.data['name'] == 'credit_limit');
            final hasBillingDay =
                tableInfo.any((row) => row.data['name'] == 'billing_day');
            final hasPaymentDueDay =
                tableInfo.any((row) => row.data['name'] == 'payment_due_day');

            if (!hasCreditLimit) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN credit_limit REAL;');
              logger.info('DB', 'v17: credit_limit 字段已添加');
            }

            if (!hasBillingDay) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN billing_day INTEGER;');
              logger.info('DB', 'v17: billing_day 字段已添加');
            }

            if (!hasPaymentDueDay) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN payment_due_day INTEGER;');
              logger.info('DB', 'v17: payment_due_day 字段已添加');
            }

            print('[DB Migration] v17 迁移完成');
          }
          if (from < 18) {
            // v18: 账户添加元信息字段
            print('[DB Migration] 开始迁移到 v18: 账户元信息');

            final tableInfo =
                await customSelect('PRAGMA table_info(accounts)').get();
            final hasBankName =
                tableInfo.any((row) => row.data['name'] == 'bank_name');
            final hasCardLastFour =
                tableInfo.any((row) => row.data['name'] == 'card_last_four');
            final hasNote =
                tableInfo.any((row) => row.data['name'] == 'note');

            if (!hasBankName) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN bank_name TEXT;');
              logger.info('DB', 'v18: bank_name 字段已添加');
            }

            if (!hasCardLastFour) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN card_last_four TEXT;');
              logger.info('DB', 'v18: card_last_four 字段已添加');
            }

            if (!hasNote) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN note TEXT;');
              logger.info('DB', 'v18: note 字段已添加');
            }

            print('[DB Migration] v18 迁移完成');
          }
          if (from < 19) {
            // v19: 同步基础设施
            print('[DB Migration] 开始迁移到 v19: 同步基础设施');

            // 1. 为 accounts 添加 sync_id
            final accountInfo =
                await customSelect('PRAGMA table_info(accounts)').get();
            if (!accountInfo.any((row) => row.data['name'] == 'sync_id')) {
              await customStatement(
                  'ALTER TABLE accounts ADD COLUMN sync_id TEXT;');
              // 回填 UUID
              await customStatement('''
                UPDATE accounts SET sync_id =
                  lower(hex(randomblob(4))) || '-' ||
                  lower(hex(randomblob(2))) || '-4' ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  substr('89ab', abs(random()) % 4 + 1, 1) ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  lower(hex(randomblob(6)))
                WHERE sync_id IS NULL;
              ''');
              await customStatement(
                  'CREATE INDEX IF NOT EXISTS idx_accounts_sync_id ON accounts(sync_id);');
              logger.info('DB', 'v19: accounts.sync_id 已添加并回填');
            }

            // 2. 为 categories 添加 sync_id
            final categoryInfo =
                await customSelect('PRAGMA table_info(categories)').get();
            if (!categoryInfo.any((row) => row.data['name'] == 'sync_id')) {
              await customStatement(
                  'ALTER TABLE categories ADD COLUMN sync_id TEXT;');
              await customStatement('''
                UPDATE categories SET sync_id =
                  lower(hex(randomblob(4))) || '-' ||
                  lower(hex(randomblob(2))) || '-4' ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  substr('89ab', abs(random()) % 4 + 1, 1) ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  lower(hex(randomblob(6)))
                WHERE sync_id IS NULL;
              ''');
              await customStatement(
                  'CREATE INDEX IF NOT EXISTS idx_categories_sync_id ON categories(sync_id);');
              logger.info('DB', 'v19: categories.sync_id 已添加并回填');
            }

            // 3. 为 tags 添加 sync_id
            final tagInfo =
                await customSelect('PRAGMA table_info(tags)').get();
            if (!tagInfo.any((row) => row.data['name'] == 'sync_id')) {
              await customStatement(
                  'ALTER TABLE tags ADD COLUMN sync_id TEXT;');
              await customStatement('''
                UPDATE tags SET sync_id =
                  lower(hex(randomblob(4))) || '-' ||
                  lower(hex(randomblob(2))) || '-4' ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  substr('89ab', abs(random()) % 4 + 1, 1) ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  lower(hex(randomblob(6)))
                WHERE sync_id IS NULL;
              ''');
              await customStatement(
                  'CREATE INDEX IF NOT EXISTS idx_tags_sync_id ON tags(sync_id);');
              logger.info('DB', 'v19: tags.sync_id 已添加并回填');
            }

            // 4. 创建 local_changes 表
            await migrator.createTable(localChanges);
            logger.info('DB', 'v19: local_changes 表已创建');

            // 5. 创建 sync_state 表
            await migrator.createTable(syncState);
            logger.info('DB', 'v19: sync_state 表已创建');

            print('[DB Migration] v19 迁移完成');
          }
          if (from < 20) {
            // v20: 附件云端同步字段
            print('[DB Migration] 开始迁移到 v20: 附件云端同步字段');

            final tableInfo =
                await customSelect('PRAGMA table_info(transaction_attachments)').get();
            final hasCloudFileId =
                tableInfo.any((row) => row.data['name'] == 'cloud_file_id');
            final hasCloudSha256 =
                tableInfo.any((row) => row.data['name'] == 'cloud_sha256');

            if (!hasCloudFileId) {
              await customStatement(
                  'ALTER TABLE transaction_attachments ADD COLUMN cloud_file_id TEXT;');
              logger.info('DB', 'v20: cloud_file_id 字段已添加');
            }

            if (!hasCloudSha256) {
              await customStatement(
                  'ALTER TABLE transaction_attachments ADD COLUMN cloud_sha256 TEXT;');
              logger.info('DB', 'v20: cloud_sha256 字段已添加');
            }

            print('[DB Migration] v20 迁移完成');
          }
          if (from < 21) {
            // v21: ledgers 加 syncId（跨设备同步 ledger 匹配）
            print('[DB Migration] 开始迁移到 v21: ledgers.sync_id');

            final ledgerInfo =
                await customSelect('PRAGMA table_info(ledgers)').get();
            if (!ledgerInfo.any((row) => row.data['name'] == 'sync_id')) {
              await customStatement(
                  'ALTER TABLE ledgers ADD COLUMN sync_id TEXT;');
              // 把现有 ledger.id 回填成 syncId（转字符串）。这样旧 A 设备已推
              // 到 server 的 external_id（= 当时的 id.toString()）对得上新列，
              // 后续 push/pull 都走 syncId，无脑兼容。
              await customStatement(
                  "UPDATE ledgers SET sync_id = CAST(id AS TEXT) WHERE sync_id IS NULL;");
              await customStatement(
                  'CREATE INDEX IF NOT EXISTS idx_ledgers_sync_id ON ledgers(sync_id);');
              logger.info('DB', 'v21: ledgers.sync_id 已添加并回填');
            }

            print('[DB Migration] v21 迁移完成');
          }
          if (from < 22) {
            // v22: budgets 加 syncId(跨设备同步 budget 匹配)
            print('[DB Migration] 开始迁移到 v22: budgets.sync_id');

            final budgetInfo =
                await customSelect('PRAGMA table_info(budgets)').get();
            if (!budgetInfo.any((row) => row.data['name'] == 'sync_id')) {
              await customStatement(
                  'ALTER TABLE budgets ADD COLUMN sync_id TEXT;');
              // SQLite 没有原生 UUID。用 lower(hex(randomblob(16))) 造 32 位
              // 随机 hex,足够当 server entity_sync_id 用。格式跟 UUID 不是
              // 标准 36 位,但 server 侧校验只要求非空字符串。
              await customStatement(
                  "UPDATE budgets SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL;");
              await customStatement(
                  'CREATE INDEX IF NOT EXISTS idx_budgets_sync_id ON budgets(sync_id);');
              logger.info('DB', 'v22: budgets.sync_id 已添加并回填');
            }

            print('[DB Migration] v22 迁移完成');
          }
          if (from < 23) {
            // v23: 清理"分类图标靠 getCategoryIconByName 运行时推导"的毒瘤代码。
            // 历史上 `category.icon` 允许为 null/空,渲染时走 `getCategoryIconByName`
            // 按中文关键字模糊匹配回退推导图标。这个方案:
            //   - 改名就换图标(用户会懵)
            //   - 只认中文,英语/繁中走不到
            //   - web/server 必须复刻同一套 40 条正则,维护两份
            // v23 一次性把 icon IS NULL/'' 的分类按 byName 推算出结果写回 DB,
            // 之后渲染层 getCategoryIconData 只认 icon 字段、不再 byName 推导。
            // 结合服务端 alembic 0002 的同名 backfill,两端同步"迁 read-time 到
            // write-time"。
            print('[DB Migration] 开始迁移到 v23: backfill category icons via byName');

            // 取所有 icon 空的分类,按 name 推导图标字符串回填
            final rows = await customSelect(
              "SELECT id, name FROM categories WHERE icon IS NULL OR icon = ''",
            ).get();
            var updated = 0;
            for (final row in rows) {
              final id = row.data['id'] as int;
              final name = row.data['name'] as String? ?? '';
              // 用 CategoryService.resolveIconNameByName(类似原 getCategoryIconByName
              // 但返回字符串名)一次性固化到 DB。此后渲染不再 byName。
              final iconName = CategoryService.resolveIconNameByName(name);
              await customStatement(
                'UPDATE categories SET icon = ? WHERE id = ?',
                [iconName, id],
              );
              updated++;
            }
            logger.info('DB', 'v23: backfilled $updated categories');
            print('[DB Migration] v23 迁移完成: 回填 $updated 条分类');
          }
          if (from < 24) {
            // v24: 共享账本完整 schema(合并自 v24/v25/v26/v27 的迭代,测试阶段
            // 一次落地最终态)。
            //
            // 重要:所有 ALTER / createTable 都包"存在则跳过"防御 — 用户从
            // 3.1.3 升级到带 bug 的 3.2.0 时 v25 ALTER 失败,但 v24 的 DDL
            // 已经隐式 commit(SQLite DDL 不可回滚),user_version 仍 23。
            // 装新版本再跑 onUpgrade(from=23) 时 v24 第一句又会 duplicate column
            // 卡死。每条都要幂等。
            print('[DB Migration] 开始迁移到 v24: 共享账本完整 schema');

            await _addColumnIfMissing(
                'ledgers', 'my_role',
                "ALTER TABLE ledgers ADD COLUMN my_role TEXT NOT NULL DEFAULT 'owner';");
            await _addColumnIfMissing(
                'ledgers', 'member_count',
                "ALTER TABLE ledgers ADD COLUMN member_count INTEGER NOT NULL DEFAULT 1;");
            await _addColumnIfMissing(
                'ledgers', 'is_shared',
                "ALTER TABLE ledgers ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0;");
            await _addColumnIfMissing(
                'ledgers', 'owner_user_id',
                "ALTER TABLE ledgers ADD COLUMN owner_user_id TEXT;");

            await _addColumnIfMissing(
                'transactions', 'created_by_user_id',
                "ALTER TABLE transactions ADD COLUMN created_by_user_id TEXT;");
            await _addColumnIfMissing(
                'transactions', 'last_edited_by_user_id',
                "ALTER TABLE transactions ADD COLUMN last_edited_by_user_id TEXT;");
            await _addColumnIfMissing(
                'transactions', 'category_sync_id_override',
                'ALTER TABLE transactions ADD COLUMN category_sync_id_override TEXT;');
            await _addColumnIfMissing(
                'transactions', 'account_sync_id_override',
                'ALTER TABLE transactions ADD COLUMN account_sync_id_override TEXT;');
            await _addColumnIfMissing(
                'transactions', 'to_account_sync_id_override',
                'ALTER TABLE transactions ADD COLUMN to_account_sync_id_override TEXT;');
            await _addColumnIfMissing(
                'transactions', 'tag_sync_ids_override',
                'ALTER TABLE transactions ADD COLUMN tag_sync_ids_override TEXT;');

            await _createTableIfMissing(migrator, 'ledger_members', ledgerMembers);
            await _createTableIfMissing(migrator, 'shared_ledger_categories', sharedLedgerCategories);
            await _createTableIfMissing(migrator, 'shared_ledger_accounts', sharedLedgerAccounts);
            await _createTableIfMissing(migrator, 'shared_ledger_tags', sharedLedgerTags);
            await _createTableIfMissing(migrator, 'transaction_tag_overrides', transactionTagOverrides);

            // 重置 server_cursor — 强制下次启动全量重拉,确保 sync_engine_apply
            // 用最新的 override 写入逻辑填回 *SyncIdOverride 字段。
            await customStatement('UPDATE sync_state SET server_cursor = 0');

            print('[DB Migration] v24 迁移完成');
          }
          if (from < 25) {
            // v25: SharedLedgerCategories 加 parent_sync_id 列。
            // 注:v24 `createTable(sharedLedgerCategories)` 用**当前 schema**
            // 建表,已经带 parent_sync_id 列 — 干净 from=23 升级时这里 ALTER
            // 会 duplicate。用 helper PRAGMA 检查后再 ALTER。
            logger.info('DBMigration',
                '开始迁移到 v25: SharedLedgerCategories.parent_sync_id');
            await _addColumnIfMissing(
                'shared_ledger_categories', 'parent_sync_id',
                'ALTER TABLE shared_ledger_categories ADD COLUMN parent_sync_id TEXT;');
            // 数据回填:对每个 level=2 行,在同 ledger_sync_id + kind 内按
            // parent_name 反查 level=1 行的 syncId 填进 parent_sync_id。
            // 用 IS NULL/'' 守护让 UPDATE 可幂等重跑。
            await customStatement('''
              UPDATE shared_ledger_categories AS child
              SET parent_sync_id = (
                SELECT parent.sync_id
                FROM shared_ledger_categories AS parent
                WHERE parent.ledger_sync_id = child.ledger_sync_id
                  AND parent.name = child.parent_name
                  AND parent.kind = child.kind
                  AND COALESCE(parent.level, 1) = 1
                LIMIT 1
              )
              WHERE COALESCE(child.level, 1) >= 2
                AND child.parent_name IS NOT NULL
                AND (child.parent_sync_id IS NULL OR child.parent_sync_id = '')
            ''');
            // reset server_cursor 让后续 pull 重拉 user-global category change。
            await customStatement('UPDATE sync_state SET server_cursor = 0');
            logger.info('DBMigration', 'v25 迁移完成');
          }
          if (from < 26) {
            // v26: 新增 sync_pull_errors 表。健康用户为空,只在 pull apply
            // 抛错时写入,UI 据此显示"同步异常"banner + 重试/跳过操作。
            // 详见 .docs/full-pull-refactor/04-data-model.md
            logger.info('DBMigration', '开始迁移到 v26: sync_pull_errors');
            await _createTableIfMissing(migrator, 'sync_pull_errors', syncPullErrors);
            logger.info('DBMigration', 'v26 迁移完成');
          }
          if (from < 27) {
            logger.info('DBMigration', '开始迁移到 v27: ledgers.month_start_day');
            // v27: 账本自定义每月起始日(1-28),默认 1=自然月
            await customStatement(
                'ALTER TABLE ledgers ADD COLUMN month_start_day INTEGER NOT NULL DEFAULT 1;');
            logger.info('DBMigration', 'v27 迁移完成');
          }
          if (from < 28) {
            logger.info('DBMigration', '开始迁移到 v28: 多币种 MVP(exchange_rates / exchange_rate_overrides)');
            await _createTableIfMissing(migrator, 'exchange_rates', exchangeRates);
            await _createTableIfMissing(migrator, 'exchange_rate_overrides', exchangeRateOverrides);
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_override_pair '
                'ON exchange_rate_overrides (base_currency, quote_currency);');
            logger.info('DBMigration', 'v28 迁移完成');
          }
          if (from < 29) {
            logger.info('DBMigration', '开始迁移到 v29: 账单标记(不计入收支/不计入预算)');
            await _addColumnIfMissing('transactions', 'exclude_from_stats',
                'ALTER TABLE transactions ADD COLUMN exclude_from_stats INTEGER NOT NULL DEFAULT 0;');
            await _addColumnIfMissing('transactions', 'exclude_from_budget',
                'ALTER TABLE transactions ADD COLUMN exclude_from_budget INTEGER NOT NULL DEFAULT 0;');
            logger.info('DBMigration', 'v29 迁移完成');
          }
        },
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_override_pair '
              'ON exchange_rate_overrides (base_currency, quote_currency);');
        },
      );

  /// Migration helper: 列不存在再 ALTER ADD,避免 partial state 重跑时
  /// "duplicate column" 把启动卡死。
  ///
  /// SQLite DDL 隐式 commit 且不可回滚;上次 onUpgrade 跑到一半失败时,前面
  /// 已成功的 ALTER 已写入文件但 user_version 没更新,下次启动同一段重跑就
  /// 报 duplicate。每条 ALTER 都通过这里走 PRAGMA 检查可幂等。
  Future<void> _addColumnIfMissing(
      String table, String column, String ddl) async {
    final cols =
        await customSelect("PRAGMA table_info($table)").get();
    final exists =
        cols.any((r) => r.read<String>('name') == column);
    if (exists) {
      logger.info(
          'DBMigration', '$table.$column 已存在,跳过 ALTER');
      return;
    }
    await customStatement(ddl);
  }

  /// Migration helper: 表不存在再 createTable,避免 partial state 重跑时
  /// "table already exists"。
  Future<void> _createTableIfMissing(
      Migrator m, String tableName, dynamic table) async {
    final row = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).getSingleOrNull();
    if (row != null) {
      logger.info('DBMigration', '$tableName 表已存在,跳过 createTable');
      return;
    }
    await m.createTable(table);
  }

  // Seed minimal data
  /// [l10n] 国际化对象，如果为null则使用英文作为默认语言
  /// [currency] 货币代码
  /// [useHierarchicalCategories] 是否使用二级分类
  ///
  /// 注意：此方法只应在真正的首次初始化时调用（欢迎页完成时）
  Future<void> ensureSeed({
    AppLocalizations? l10n,
    String currency = 'CNY',
    bool useHierarchicalCategories = false,
    bool skipCategories = false,
    bool createDefaultLedger = true,
  }) async {
    logger.info('db', 'ensureSeed 被调用');
    logger.info('db', 'l10n 是否提供: ${l10n != null}');
    logger.info('db', '货币: $currency');
    logger.info('db', '使用二级分类: $useHierarchicalCategories');
    logger.info('db', '跳过分类创建: $skipCategories');
    logger.info('db', '创建默认账本: $createDefaultLedger');

    // 如果没有提供l10n，使用Lookup创建默认的英文版本
    final effectiveL10n = l10n ?? lookupAppLocalizations(const Locale('en'));
    logger.info('db', '使用的语言环境: ${l10n != null ? "提供的l10n" : "默认英文"}');

    await SeedService.seedDatabase(
      this,
      effectiveL10n,
      currency: currency,
      useHierarchicalCategories: useHierarchicalCategories,
      skipCategories: skipCategories,
      createDefaultLedger: createDefaultLedger,
    );
    logger.info('db', '数据库初始化完成');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'beecount.sqlite'));

    // 开发环境：如果检测到锁文件，尝试删除（仅用于调试）
    try {
      final shmFile = File(p.join(dir.path, 'beecount.sqlite-shm'));
      final walFile = File(p.join(dir.path, 'beecount.sqlite-wal'));

      if (shmFile.existsSync() || walFile.existsSync()) {
        logger.warning('db', '检测到 SQLite 临时文件，可能存在锁定');
        // 注意：只在开发环境中记录，不自动删除，因为可能正在使用
      }
    } catch (e) {
      logger.debug('db', '检查锁文件时出错: $e');
    }

    return NativeDatabase.createInBackground(file);
  });
}

/// 开发工具：清除数据库锁文件（仅在应用完全关闭后使用）
Future<void> clearDatabaseLockFiles() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final shmFile = File(p.join(dir.path, 'beecount.sqlite-shm'));
    final walFile = File(p.join(dir.path, 'beecount.sqlite-wal'));

    if (shmFile.existsSync()) {
      await shmFile.delete();
      logger.info('db', '已删除 .sqlite-shm 文件');
    }

    if (walFile.existsSync()) {
      await walFile.delete();
      logger.info('db', '已删除 .sqlite-wal 文件');
    }

    logger.info('db', '数据库锁文件清理完成');
  } catch (e) {
    logger.error('db', '清理锁文件失败', e);
  }
}
