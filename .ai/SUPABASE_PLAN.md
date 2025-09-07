# BeeCount - Supabase 登录与账本同步方案（草案，2025-09-07）

本方案记录登录/注册与多端账本同步的总体设计，便于后续按阶段落地。

## 目标

- 提供账户系统（Email/Password 可选 Apple/Google 登录）。
- 支持多账本、分类、流水的云端存储与多端同步。
- 离线优先，本地可用；网络恢复后自动推送/拉取增量。

## 技术选型

- Supabase（Auth + Postgres + Realtime）
- Flutter 客户端：supabase_flutter（session），Drift（本地 DB），Riverpod（状态），uuid（本地主键）。

## 数据模型（云端）

- users（隐式，使用 Auth 用户）
- ledgers(id uuid pk, user_id uuid, name text, currency text, updated_at timestamptz, deleted bool)
- categories(id uuid pk, ledger_id uuid fk, name text, kind text, icon text, updated_at timestamptz, deleted bool)
- transactions(id uuid pk, ledger_id uuid fk, type text, amount numeric, category_id uuid null, happened_at timestamptz, note text, updated_at timestamptz, deleted bool)
- 所有表 required: user_id 可由外键或通过 ledger 关联推断；记录更新时维护 updated_at；删除走软删 deleted=true。

## 安全（RLS）

- 所有表启用 RLS；仅允许 auth.uid() 拥有/参与的 ledger 数据可读写。
- 典型策略：
  - 使用 ledgers.user_id = auth.uid() 作为过滤；categories/transactions 通过 ledger_id join ledgers 校验归属。

## 同步策略

- 本地每条记录维护 updated_at、deleted，主键为 UUID。
- 客户端维护 last_sync_at（拉取点）与 last_pushed_at（推送点）。
- Pull：拉取云端 updated_at > last_sync_at 的增量（分表），合并到本地；冲突以较新 updated_at 为准。
- Push：上行本地 updated_at > last_pushed_at 的变更；云端以较新为准写入。
- 首次同步：
  - 选择“云端覆盖本地”或“本地上传为主”；或按账本逐一确认。
- Realtime：可订阅 transactions（按 ledger_id 过滤）以获得他端变更实时更新。

## 客户端改造

- 抽象 SyncService：
  - pull(ledgerId, since), push(ledgerId, since), resolveConflicts()。
  - 背压与重试：指数退避；队列化写操作。
- Repository 与 SyncService 解耦：UI 仍走本地 Drift；写操作入队同步任务。
- UI：登录页、同步状态提示、手动“立即同步”。

## 迁移与风险

- 主键策略统一为 UUID，避免本地自增与云端冲突。
- 时区统一存 UTC；客户端展示按本地时区。
- RLS 策略与存储过程要充分测试；防止越权读写。
- 冲突解决可先用“较新为准”，后期再精细化。

## 运维与成本

- 监控 Postgres 负载与存储；归档冷数据（大于一定年限）。
- 备份、恢复策略与合规（隐私数据保护）。

## 待准备

- Supabase 项目、URL/Anon Key，本地 .env 注入。
- 建表与 RLS SQL（后续提供脚本）。
- 客户端依赖与基础骨架（Auth 初始化、SyncService 接口）。

---

本方案先落在 .ai 目录，后续我们按章节逐步实现（先 Auth，再 Ledger/Transaction 同步）。
