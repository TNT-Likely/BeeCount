# V4 大数据列表：补齐开库性能索引

## 范围与兼容

历史性能索引只存在于旧版本的 onUpgrade 分支。新建数据库的 createAll 不会执行这些分支，可能缺少交易、标签关系与附件等索引。开库时幂等补齐索引，适用于新建、升级和已有数据库。

## 修复

`BeeDatabase.beforeOpen` 幂等创建下列非唯一索引，覆盖新建、升级和已有 v33 开库。不修改 schema 版本、行数据、唯一性约束、外汇或统计规则。

| 表 | 索引列 | 来源 |
| --- | --- | --- |
| transaction_tags | transaction_id、tag_id，各一项 | 恢复历史迁移两项 |
| transaction_attachments | transaction_id | 恢复历史迁移 |
| transactions | sync_id | 恢复历史迁移 |
| accounts、categories、tags、ledgers | 各表 sync_id | 恢复历史迁移四项 |
| budgets | sync_id、ledger_id、category_id、(ledger_id,type) | 恢复历史迁移四项 |
| transactions | (ledger_id,happened_at DESC) | 新增一项，对应真实首页筛选与排序 |

新增 schema 对象白名单共 13 项，仅索引。已有同名索引通过 `IF NOT EXISTS` 保持；没有新增分页，也没有为回避加载而减少日汇总或完整记录范围。

## 回归要求

验证新建 v33、已有 v33 缺索引及 v32→v33 的真实开库；检查全部原行值、关系和连续重开保持，查询计划应命中索引，首页无需额外排序树。索引仅改变查询计划，不改变 schema 版本、资金口径、行数据与同步身份。

单次机器计时、数据库快照与逐轮 QA 证据保存在本机 `.docs`，不纳入生产源码。
