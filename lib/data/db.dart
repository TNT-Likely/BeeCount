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
])
class BeeDatabase extends _$BeeDatabase {
  BeeDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 23; // v23: 清空分类 icon 的历史数据走 byName 一次性回填

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
        },
      );

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
  }) async {
    logger.info('db', 'ensureSeed 被调用');
    logger.info('db', 'l10n 是否提供: ${l10n != null}');
    logger.info('db', '货币: $currency');
    logger.info('db', '使用二级分类: $useHierarchicalCategories');
    logger.info('db', '跳过分类创建: $skipCategories');

    // 如果没有提供l10n，使用Lookup创建默认的英文版本
    final effectiveL10n = l10n ?? lookupAppLocalizations(const Locale('en'));
    logger.info('db', '使用的语言环境: ${l10n != null ? "提供的l10n" : "默认英文"}');

    await SeedService.seedDatabase(
      this,
      effectiveL10n,
      currency: currency,
      useHierarchicalCategories: useHierarchicalCategories,
      skipCategories: skipCategories,
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
