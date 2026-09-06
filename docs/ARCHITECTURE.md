# BeeCount(蜜蜂记账)项目架构与代码文件功能说明

> 本文档基于对 `D:\编程\andriod\BeeCount` 全量代码的完整阅读整理而成。
> 最后更新:2026-08-07 · 代码规模:lib/ 下约 346 个 Dart 文件

---

## 目录

- [1. 项目概览](#1-项目概览)
- [2. 技术栈](#2-技术栈)
- [3. 目录结构总览](#3-目录结构总览)
- [4. 分层架构](#4-分层架构)
- [5. 数据层详解](#5-数据层详解)
- [6. 云同步架构详解](#6-云同步架构详解)
- [7. AI 智能记账架构详解](#7-ai-智能记账架构详解)
- [8. 桌面小组件系统详解](#8-桌面小组件系统详解)
- [9. 主题与设计系统](#9-主题与设计系统)
- [10. 代码文件功能说明(逐文件)](#10-代码文件功能说明逐文件)
- [11. 平台层(Android / iOS)](#11-平台层android--ios)
- [12. 测试、脚本与 CI/CD](#12-测试脚本与-cicd)
- [13. 构建与发布](#13-构建与发布)

---

## 1. 项目概览

**蜜蜂记账(BeeCount)** 是一款开源、离线优先的个人财务管理 / 支出追踪 App,主打「数据主权」:

- **数据主权**:本地优先存储(SQLite),提供 BeeCount Cloud(自建 REST+WS 实时同步)/ iCloud / Supabase / WebDAV / S3 五种同步方案
- **AI 记账**:对话记账 / OCR 拍照记账 / 语音记账 / 截图自动记账(Android 截图监听 + iOS AppIntents 快捷指令)
- **核心记账**:多账本、多账户、二级分类、预算、周期记账、标签、图表分析、CSV(支付宝/微信)导入导出、YAML 配置导出
- **桌面小组件**:6 类内容 × 12 种规格(iOS WidgetKit + Android AppWidget),离屏渲染 PNG 图片方案
- **无广告 / 无追踪 / 免费**

平台支持:Android 5.0+(minSdk 23)、iOS 15.5+。包名 `com.tntlikely.beecount`。

---

## 2. 技术栈

| 领域 | 技术 |
|---|---|
| UI 框架 | Flutter 3.27+ / Dart 3.6+ |
| 状态管理 | Riverpod 2.x(`flutter_riverpod`) |
| 本地数据库 | Drift 2.x(SQLite ORM,`build_runner` 代码生成),schema v31 |
| 云同步 | 自研 `flutter_cloud_sync` 框架 + 5 个后端 provider 包 |
| AI | 自研 `flutter_ai_kit` 框架 + 智谱 GLM / OpenAI 兼容 provider |
| 图表 | fl_chart + 自研折线图(line_chart.dart) |
| 其他关键依赖 | home_widget、flutter_local_notifications、local_auth、image_picker/image_cropper/flutter_image_compress、file_picker、csv/excel/archive、supabase_flutter、dio/http、share_plus、qr_flutter、gal、in_app_purchase 等 |

---

## 3. 目录结构总览

```
BeeCount/
├── lib/                          # ★ 全部 Dart 业务代码(346 个文件)
│   ├── main.dart                 # 应用入口(启动初始化、深链监听、主题装配)
│   ├── app.dart                  # 主壳 BeeApp:底部导航、AppLink 派发、云同步启动
│   ├── theme.dart                # BeeTheme 基础主题工厂(明/暗)
│   ├── providers.dart            # 唯一出口:re-export providers/all_providers.dart
│   ├── ai/                       # AI 底座(无 UI):核心引擎/服务商配置/隐私
│   ├── cloud/                    # 云同步:新旧两代引擎 + 事件/序列化
│   ├── data/                     # 数据层:Drift 数据库 + Repository(接口+Local 实现)
│   ├── l10n/                     # 本地化(arb + 生成的 app_localizations)
│   ├── models/                   # 领域模型(展示/快捷指令等)
│   ├── pages/                    # ★ 74 个页面文件,按功能 18 个子目录
│   ├── providers/                # ★ 29 个 Riverpod provider 文件
│   ├── services/                 # ★ 服务层:57 个文件,业务编排
│   ├── styles/                   # Design Token + 头部皮肤系统(18 个皮肤文件)
│   ├── utils/                    # 22 个工具文件
│   ├── widget/                   # 桌面小组件(单数):管理器/规格/数据/6 视图
│   └── widgets/                  # 通用 UI 组件(复数):63 个文件,9 个子目录
├── android/                      # Android 平台层(13 个 Kotlin 文件 + Widget)
├── ios/                          # iOS 平台层(WidgetKit 扩展 + AppIntents)
├── packages/                     # ★ 8 个自定义本地包(2 个框架 + 6 个 provider)
│   ├── flutter_ai_kit/           # 通用 AI 框架(纯 Dart,零依赖)
│   ├── flutter_ai_kit_zhipu/     # 智谱 GLM provider
│   ├── flutter_ai_kit_openai/    # OpenAI 兼容协议 provider
│   ├── flutter_cloud_sync/       # 通用云同步框架 + BeeCountCloudProvider
│   ├── flutter_cloud_sync_supabase/ / _webdav/ / _icloud/ / _s3/
├── assets/                       # logo、SVG 图标、图片、头部皮肤、头像
├── test/                         # ~70 个测试文件(单元/组件/E2E)
├── scripts/                      # 图标生成、商店数据生成、i18n 检查
├── tool/                         # keystore 生成脚本
├── docs/                         # 云配置指南、贡献指南、Design Token 文档
├── demo/                         # 演示数据生成器与视频/GIF
├── preview/                      # 商店截图素材
└── .github/workflows/            # release.yml / issue-lint.yml / pullfrog.yml
```

---

## 4. 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│  UI 层  lib/pages/ + lib/widgets/ + lib/widget/(小组件)      │
│  ← 纯展示 + 交互,通过 Riverpod watch/read 取数据、触发刷新   │
├─────────────────────────────────────────────────────────────┤
│  状态层  lib/providers/ (29 个文件)                          │
│  ← Riverpod:数据库/仓库装配、主题、币种、同步、统计、UI 状态  │
│  ← "Tick 刷新模式":StateProvider<int> 计数器作刷新信号        │
├─────────────────────────────────────────────────────────────┤
│  服务层  lib/services/ (57 个文件)                           │
│  ← 业务编排:AI 记账、自动记账、导入导出、更新、附件、孤儿清理 │
├─────────────────────────────────────────────────────────────┤
│  数据层  lib/data/                                           │
│  ← Drift 数据库(db.dart, 21 张表)                            │
│  ← Repository 接口 + Local 实现(写路径挂 ChangeTracker)      │
├─────────────────────────────────────────────────────────────┤
│  同步层  lib/cloud/ + packages/flutter_cloud_sync*/          │
│  ← SyncEngine(新一代增量同步)+ CloudSyncManager(旧快照同步)  │
├─────────────────────────────────────────────────────────────┤
│  AI 底座  lib/ai/ + packages/flutter_ai_kit*/                │
│  ← 提取引擎、Prompt 构建、JSON 容错解析、多服务商管理         │
└─────────────────────────────────────────────────────────────┘
```

**核心设计范式**:

1. **本地优先 + 增量同步**:所有写操作经 `LocalRepository` → 登记 `local_changes` 表(`ChangeTracker`)→ `SyncCoordinator` 250ms 防抖 → `SyncEngine` 推云。云端只存用户自己的数据,离线可用。
2. **Tick 刷新模式**:全项目用 `StateProvider<int>` 计数器(`statsRefreshProvider`、`syncGenerationProvider`、`ledgerListRefreshProvider` 等)作为"刷新信号",派生 provider watch 后自动重算,替代手动 invalidate。
3. **共享账本双轨制**:Owner 数据在主表,Editor 视角用 `SharedLedger*` 镜像表 + `syncId → 负整数 synthetic id` 映射,配合 `syncIdOverride` 字段引用 Owner 资源。
4. **防御性编程**:iOS 后台 kill 场景(urgent 附件复制、onSaved 回调前置、通知独立 ID)、异常绝不阻断主流程、多源汇率链、APK 完整性校验等。

---

## 5. 数据层详解

### 5.1 数据库(`lib/data/db.dart`,schema v31)

21 张表:

| 表 | 用途 | 关键说明 |
|---|---|---|
| `ledgers` | 账本 | syncId(跨设备)、monthStartDay(自定义月度起始日 v27)、共享账本字段(myRole/memberCount/ownerUserId) |
| `accounts` | 账户 | 独立账户(v5)、sortOrder、信用卡字段、hidden(v31)、syncId |
| `exchange_rates` | 自动汇率缓存 | append-only,不进同步,复合 PK(base,quote,date) |
| `exchange_rate_overrides` | 手动汇率覆盖 | user-global 同步实体,v28 唯一索引 |
| `categories` | 分类 | 二级分类(parentId/level)、自定义图标(iconType/customIconPath/communityIconId)、syncId |
| `transactions` | 交易(核心) | 收支/转账三类、syncId、createdByUserId/lastEditedByUserId(共享账本)、*SyncIdOverride 字段、excludeFromStats/Budget(v29)、currencyCode/nativeAmount(v30 交易级多币种) |
| `recurring_transactions` | 周期记账模板 | 日/周/月/年频率、lastGeneratedDate |
| `conversations` / `messages` | AI 对话 | 已全局化;message 含 BillInfo JSON、transactionId(撤销) |
| `tags` / `transaction_tags` | 标签 | 多对多关联 |
| `local_changes` | 同步变更追踪 | entityType/entityId/syncId/action/payloadJson/pushedAt |
| `sync_state` | 同步游标 | deviceId/serverCursor/lastPushAt/lastPullAt |
| `transaction_tag_overrides` | 共享账本标签 override | 复合 PK(transactionSyncId, tagSyncId) |
| `sync_pull_errors` | pull 失败持久化 | 重试队列(v26) |
| `transaction_attachments` | 附件元数据 | cloudFileId/cloudSha256(v20) |
| `budgets` | 预算 | 总预算/分类预算、period、startDay |
| `ledger_members` | 账本成员镜像 | 复合 PK(ledgerSyncId, userId)(v24) |
| `shared_ledger_categories` / `_accounts` / `_tags` | Owner 分类/账户/标签镜像 | Editor 视角(v24,二级分类 parentSyncId v25) |

**迁移要点**:v1→v31 全量手工迁移;`_addColumnIfMissing`/`_createTableIfMissing` 幂等 helper;v23 图标回填、v24 共享账本(重置 cursor 强制全量重拉)、v30 交易级多币种 SQL 回填。

### 5.2 Repository 分层

```
lib/data/repositories/
├── base_repository.dart      # 聚合 11 个接口 + 6 个多币种聚合方法
├── *_repository.dart         # 12 个纯抽象接口 + exceptions.dart
└── local/
    ├── local_repository.dart # ★ 聚合门面(2815 行):委托 + ChangeTracker 增强 + 折算兜底
    └── local_*.dart          # 11 个子仓库(纯 Drift 读写)
```

- **装配点**:`lib/providers/database_providers.dart` 的 `repositoryProvider` → `LocalRepository(db, changeTracker)`,仅在 BeeCount Cloud 激活时注入 ChangeTracker。
- **写路径增强**:单条写后按实体类型记 user-global(白名单:account/category/tag/exchange_rate_override,ledgerId=0)或 ledger-scope change;批量写用 `db.batch` 一次插入 N 条;FullPull 走 `recordChanges=false` 静默写入。
- **v30 多币种兜底**:`_resolveTxCurrency`/`_effectiveRatesFor`/`_recalcNativeAmounts`,手动覆盖 > 最新自动汇率,取不到按 1.0 并在 UI 出横幅提示。
- **脏数据修复**:`getTransferCategory` 被动合并重复虚拟转账分类;`migrateCategory/Account` 迁移后逐条登记 change。

---

## 6. 云同步架构详解

### 6.1 两代架构并存

| 代际 | 文件 | 机制 |
|---|---|---|
| 新一代(主) | `lib/cloud/sync/`(16 个文件) | **增量变更同步**:ChangeTracker → SyncCoordinator → SyncEngine(push/pull/实时 WS),fullPush 仅首次 |
| 旧一代 | `lib/cloud/transactions_sync_manager.dart` | 快照式:getRemoteData/setRemoteData 全量替换,配合 `sync_diff_service.dart` 手动预览合并,供 iCloud/WebDAV/S3/Supabase 使用 |

### 6.2 新一代引擎主流程

```
本地写 → ChangeTracker 写 local_changes → SyncCoordinator watch(250ms 防抖)
  → SyncEngine.sync(互斥锁,idle/pushing/pulling)
    ├─ fullPush? 远端无此 ledger 且非共享 Editor → 导出整账本 JSON
    ├─ push:ChangePush 序列化(syncId 引用 + 实体 JSON),user-global 与 ledger-scope 分离
    ├─ pull:AppCursorStore 安全游标(persistCursor:false,全成功才 commit)
    │   ├─ 跳过本设备产生的 change(deviceId 防回声)
    │   └─ apply 失败进 SyncErrorStore 下次重试
    └─ WS 实时通道:sync_change/backup_restore/profile_change/member_change → _schedulePull
```

- **冲突解决**:LWW——`shouldApplyRemote` 恒 true,以服务器 `server_received_at` 为准,客户端无条件采用远端。
- **8 种 entityType**:transaction/account/category/tag/budget/exchange_rate_override/ledger/ledger_snapshot;profile 走 `/profile/me`。
- **附件体系**:`sync_engine_attachments.dart` 上传/下载/清理,分类图标按内容 sha256 去重;附件本身不进 change 表,靠父交易 payload 的 attachments 数组下发。
- **健康检查**:`sync_engine_status.dart` 对比本地/server 实体计数诊断。

### 6.3 自定义包(packages/)

| 包 | 用途 |
|---|---|
| `flutter_cloud_sync` | 通用云同步框架:`CloudSyncManager<T>`(状态缓存/upload/download/getStatus)、Auth/Storage/Realtime 抽象、ProviderFactory、`BeeCountCloudProvider`(4732 行,自建云 REST+WS 协议,含 2FA TOTP) |
| `flutter_cloud_sync_supabase` | Supabase bucket 后端 |
| `flutter_cloud_sync_webdav` | WebDAV(坚果云/Nextcloud/群晖) |
| `flutter_cloud_sync_icloud` | iCloud Drive(仅 iOS) |
| `flutter_cloud_sync_s3` | S3 协议(AWS/Cloudflare R2/B2/MinIO/阿里 OSS/腾讯 COS/七牛) |

---

## 7. AI 智能记账架构详解

```
五渠道(对话/图片/语音/自动截图/自动文本)
  → lib/services/ai/ai_bookkeeper.dart (统一编排 Layer 2)
      → lib/ai/core/:AiExtractionEngine 提取 List<BillInfo>
          ├─ AiExtractionContext.forLedger():可用分类 + 同币种账户 + 自定义 prompt
          ├─ prompt_builder.dart:强制 JSON 数组、字段约束、占位符注入
          └─ json_response_parser.dart:容错解析(数组/对象/Markdown 围栏/trailing comma)
      → lib/services/billing/bill_creation_service.dart 落库
          ├─ 分类匹配四级:完全 → 包含 → CategoryMatcher 关键词打分(13 大类映射)→ 兜底"其他"
          └─ 账户匹配:同币种/类型映射(余额宝→支付宝)/默认账户
  → lib/ai/providers/:AIProviderManager 多服务商 CRUD(SharedPreferences 持久化)
      → packages/flutter_ai_kit*:
          ├─ flutter_ai_kit:AIProvider<TInput,TOutput> 抽象 + 6 种执行策略(cloud_only/cloud_first/local_only/local_first/cost_optimized/custom_priority)
          ├─ flutter_ai_kit_zhipu:GLM provider(glm-4.6v-flash,chat/vision/audio/embeddings)
          └─ flutter_ai_kit_openai:OpenAI 兼容(chat/vision/Whisper STT)+ ServicePresets
```

**自动记账链路**(`auto_billing_service.dart`):截图监听(Android ContentObserver / iOS AppIntents)→ 防重复(已处理路径缓存 100 条 + 5s 窗口)→ 文件就绪等待(3s)→ AI 能力检查 → AiBookkeeper.fromImage → 结果通知(成功/失败独立通知 ID,避免 iOS 静默更新)。

---

## 8. 桌面小组件系统详解

`lib/widget/`(单数)是独立于 `lib/widgets/` 的小组件子系统:

- **规格表** `widget_spec.dart`:6 类内容(glance 收支速览 / netWorth 净资产 / quickAdd 快速记账 / budget 预算进度 / recent 最近交易 / dashboard 综合仪表盘)× 12 种 (type, size) 组合,记录 logicalSize、iOS kind、Android provider 类名、共享存储 imageKey。
- **渲染流程** `widget_manager.dart`:触发(记账/切账本/主题色/前台恢复/系统明暗切换)→ `_renderGate` 串行门 → `getInstalledWidgets()` 只渲已安装(启动预热全目录)→ `WidgetGatherBatch` 批次取数缓存 → headless `HomeWidget.renderFlutterWidget` 渲染 PNG(pixelRatio 3.0,错误红屏防护)→ 原生壳按 key 读图。
- **数据层** `widget_data_service.dart`:纯 repo→数值聚合,不依赖 Riverpod(可单测),多币种折算复用 `rate_math.dart` 同一口径。
- **视图层** `views/`:6 个 headless 视图 + `widget_view_style.dart` 视觉规范,数据由调用方格式化后传入。
- **平台侧**:iOS 为 WidgetKit 扩展(Swift,TimelineProvider 30 分钟刷新,App Group `group.com.tntlikely.beecount` 共享图片);Android 为 9 个 AppWidget provider(含 5 个尺寸入口子类)。

---

## 9. 主题与设计系统

- **`lib/theme.dart`**:BeeTheme 基础 ThemeData。亮色主色蜂蜜金 `#F8C91C`,暗色纯黑背景(OLED 友好)。
- **`lib/styles/tokens.dart`**(689 行):语义化 Design Token(BeeTokens)——Surface/Text/Icon/Border/Semantic/Interactive/Brand 七大类,全部为 `Color X(BuildContext)` 函数式,内部按 isDark 自动切换。
- **皮肤系统** `lib/styles/header_skins.dart`:皮肤 = 叠在主题色底之上的装饰层(渲染于 PrimaryHeader 的 Stack)。两类:
  - 代码皮肤(CustomPainter 渐变/几何/场景,15+ 款,每款一个 part 文件)
  - 图片皮肤(SVG,BoxFit.cover 铺满,可整幅染主题色)
  - 注册表 `kHeaderSkins` + `headerSkinById(id)`;选择状态持久化并随 appearance 包推送到 BeeCount Cloud 多设备同步。

---

## 10. 代码文件功能说明(逐文件)

> 按目录分组;每行格式:文件名 — 职责一句话。

### 10.1 入口与根文件

| 文件 | 功能 |
|---|---|
| `lib/main.dart` | 应用入口:edge-to-edge、日志/时区/通知/App Group 初始化、恢复提醒与截图监听、全局 ProviderContainer(+小组件观察器)、AppLink URL 监听与冷启动暂存、孤儿文件一次性 GC、主题装配(明暗 + 动态主题色 + 字体缩放 clamp) |
| `lib/app.dart` | 主壳 `BeeApp`:4 Tab 主框架(首页/统计/资产/我的)、Telegram 风格悬浮胶囊底部栏 + 中心记账按钮(长按扇形菜单)、AppLink/快捷项深链统一派发(持久化+resumed 认领)、BeeCount Cloud 启动同步(Phase1 用户级 + Phase2 每账本并行)、应用锁生命周期处理、小组件刷新 |
| `lib/theme.dart` | `BeeTheme.lightTheme/darkTheme` 基础主题工厂 + BeeTypography 字阶 |
| `lib/providers.dart` | 唯一对外出口,re-export `providers/all_providers.dart` |

### 10.2 数据层 `lib/data/` + `lib/models/`

| 文件 | 功能 |
|---|---|
| `data/db.dart` | Drift 数据库定义:21 张表 + v1→v31 全量迁移 + 索引/DAO |
| `data/db.g.dart` | Drift 代码生成产物(61 万字节,勿手改) |
| `data/category_node.dart` | CategoryNode 分类树节点 + CategoryHierarchy(建树/取一级/子级/叶子) |
| `data/models/category_icon.dart` | CategoryIconType 枚举 + CategoryIconData(本地路径解析) |
| `data/repositories/repositories.dart` | barrel 导出全部接口与实现 |
| `data/repositories/base_repository.dart` | 聚合 11 个 Repository 接口 + v30 多币种聚合方法 |
| `data/repositories/ledger_repository.dart` | 账本 CRUD、记账天数/笔数统计、清空账本 |
| `data/repositories/transaction_repository.dart` | 交易 CRUD、批量插入(含标签/附件关系)、日历统计、按 syncId 批量操作 |
| `data/repositories/category_repository.dart` | 分类 CRUD、二级层级、名称判重、迁移、图标管理 |
| `data/repositories/account_repository.dart` | 账户 CRUD、余额/消费、净值/资产构成、信用卡、每日余额快照 |
| `data/repositories/statistics_repository.dart` | 分类/天/月/年聚合统计 + 共享账本 synthetic 映射 |
| `data/repositories/recurring_transaction_repository.dart` | 周期记账 CRUD、启用/禁用、活跃引用计数 |
| `data/repositories/ai_repository.dart` | AI 会话/消息 CRUD、按交易 ID 反查 |
| `data/repositories/tag_repository.dart` | 标签 CRUD、交易-标签关联、最近使用 |
| `data/repositories/budget_repository.dart` | 预算 CRUD、使用情况/概览(BudgetUsage/Overview VO) |
| `data/repositories/attachment_repository.dart` | 附件 CRUD、文件名引用计数、云端引用回填 |
| `data/repositories/exchange_rate_repository.dart` | 自动汇率 upsert/查询、手动覆盖 CRUD |
| `data/repositories/exceptions.dart` | DuplicateNameException 等异常 |
| `data/repositories/local/local_repository.dart` | ★ 聚合门面(2815 行):委托 11 子仓 + ChangeTracker 写路径增强 + 批量 change 优化 + 多币种折算兜底 + 级联删除登记 + 脏数据修复 |
| `data/repositories/local/local_transaction_repository.dart` | 交易 Drift 实现:三连 LEFT JOIN、共享账本 synthetic hydration、附件引用计数删除、备注历史聚合 |
| `data/repositories/local/local_account_repository.dart` | 账户 Drift 实现:余额计算(排除共享账本)、净值/资产构成、估值账户 |
| `data/repositories/local/local_category_repository.dart` | 分类 Drift 实现:判重、synthetic 负 id watch、两级汇总 |
| `data/repositories/local/local_tag_repository.dart` | 标签 Drift 实现:关联、最近使用、synthetic 反查 |
| `data/repositories/local/local_statistics_repository.dart` | 统计 SQL 实现:monthStartDay 周期、excludeFromStats 过滤 |
| `data/repositories/local/local_budget_repository.dart` | 预算 Drift 实现:usage 统计(总/分类+子分类) |
| `data/repositories/local/local_attachment_repository.dart` | 附件 Drift 实现 |
| `data/repositories/local/local_ai_repository.dart` | AI 表纯 CRUD |
| `data/repositories/local/local_exchange_rate_repository.dart` | 汇率 Drift 实现(change 记录走 getter 闭包注入) |
| `data/repositories/local/local_recurring_transaction_repository.dart` | 周期记账纯 CRUD |
| `models/ai_quick_command.dart` | AI 快捷指令模型 + 6 个预设指令 |
| `models/ledger_display_item.dart` | 账本展示模型(fromLocal/fromRemote 工厂,remote 占位 id) |
| `models/note_history.dart` | 备注历史模型(范围/排序/条目) |

### 10.3 云同步 `lib/cloud/`

| 文件 | 功能 |
|---|---|
| `cloud/sync_service.dart` | SyncService 抽象 + LocalOnlySyncService 本地空实现 |
| `cloud/transactions_sync_manager.dart` | 旧一代快照式同步管理器(CloudSyncManager<Ledger> 全量替换) |
| `cloud/transactions_json.dart` | 交易 JSON v4 导出/导入(快照交换格式) |
| `cloud/sync_diff_service.dart` | SyncChange/SyncPreview 模型 + JSON 前后 diff + 手动预览合并 |
| `cloud/sync/change_tracker.dart` | local_changes 记录器,user-global 白名单契约(ledgerId=0) |
| `cloud/sync/sync_engine.dart` | ★ 新一代同步主类:sync() 编排、fullPush 判定、triggerAutoSync 防抖、设备 ID、事件总线 |
| `cloud/sync/sync_engine_apply.dart` | pull 落地路径:applyRemoteChange 按 8 种 entityType 分发 |
| `cloud/sync/sync_engine_attachments.dart` | 附件/分类图标上传下载清理 + 内容去重 |
| `cloud/sync/sync_engine_profile.dart` | 用户档案同步(profile/me → 主题色/收支配色/外观/头像回写) |
| `cloud/sync/sync_engine_pull.dart` | 拉取引擎:AppCursorStore 安全游标 + SyncErrorStore 重试 |
| `cloud/sync/sync_engine_realtime.dart` | WS 实时监听:事件分发/重连/schedulePull |
| `cloud/sync/sync_engine_resolvers.dart` | syncId ↔ 本地 int id 双向解析 + LookupCache |
| `cloud/sync/sync_engine_serialization.dart` | push 序列化 + fullPush + _exportLedgerJson |
| `cloud/sync/sync_engine_status.dart` | 同步健康检查(本地 vs server 计数对比) |
| `cloud/sync/sync_engine_resolvers.dart` | (见上) |
| `cloud/sync/sync_events.dart` | sealed SyncEvent:PullCompleted/PushCompleted/SharedResourceChanged 等 |
| `cloud/sync/sync_providers.dart` | syncEngineProvider(family by ledger)、状态/待推送计数 provider |
| `cloud/sync/sync_conflict_resolver.dart` | LWW 冲突解决(shouldApplyRemote 恒 true) |
| `cloud/sync/sync_coordinator.dart` | watch local_changes 未推送行,250ms 防抖触发自动同步 |
| `cloud/sync/entity_serializer.dart` | 实体 JSON 序列化器 |

### 10.4 AI 底座 `lib/ai/`

| 文件 | 功能 |
|---|---|
| `ai/core/ai_extraction_engine.dart` | AiExtractionEngine 抽象 + DefaultAiExtractionEngine(text/image/audio/speechToText) |
| `ai/core/bill_info.dart` | BillInfo 模型 + BillType(income/expense/transfer) |
| `ai/core/prompt_builder.dart` | 默认 Prompt 模板:强制 JSON 数组、字段约束、多币种/多分类匹配、占位符 |
| `ai/core/json_response_parser.dart` | 容错 JSON 解析(数组/单对象/围栏/trailing comma/非法字符 sanitize) |
| `ai/core/ai_extraction_context.dart` | forLedger():可用分类 + 同币种账户 + 自定义 prompt 上下文组装 |
| `ai/providers/ai_provider_factory.dart` | 静态工厂:chat()/imageToText()/audioToText() 按类型创建 |
| `ai/providers/ai_provider_manager.dart` | 多服务商 CRUD + 能力绑定(chat/vision/audio)+ 旧配置迁移 |
| `ai/providers/ai_provider_config.dart` | AIServiceProviderConfig 模型 + AIProviderCapability |
| `ai/providers/ai_constants.dart` | 配置 key 与默认值 |
| `ai/privacy/ai_privacy_consent.dart` | AI 隐私同意版本号存储(v1) |

### 10.5 服务层 `lib/services/`

| 文件 | 功能 |
|---|---|
| `services/ai/ai_bookkeeper.dart` | ★ AI 记账统一编排:5 渠道 → 提取 → 落库 → 聚合 BookkeepingResult;onSaved 前置、enrich 回填 |
| `services/ai/ai_chat_service.dart` | AI 对话服务:记账意图判定(正则+关键词)+ 撤销记账 + 自由对话 |
| `services/ai/ai_quick_command_service.dart` | AI 快捷指令:按指令类型直查 DB 生成数据文本填入 prompt |
| `services/ai/bookkeeping_result.dart` | AI 记账结果模型(成功/失败笔数、txIds) |
| `services/automation/auto_billing_config.dart` | 自动记账常量(等待超时 3s/防重复 5s/缓存 100 条) |
| `services/automation/auto_billing_service.dart` | ★ 自动记账核心:processScreenshot/processText、防重复、就绪等待、AI 兜底、通知(独立 ID)、挂附件、后处理 |
| `services/billing/bill_creation_service.dart` | ★ BillInfo → transaction:类型解析、四级分类匹配、账户匹配、落库、自动标签 |
| `services/billing/category_matcher.dart` | 13 大类中文关键词映射 + 打分匹配(完全 2 分/名称 3 分) |
| `services/billing/post_processor.dart` | 交易后统一后处理:刷新统计/标签/附件 + 触发同步(UI/后台/Provider 三变体) |
| `services/currency/exchange_rate_service.dart` | 公网汇率 6 源链式容错(fastly→gcore→jsdelivr→frankfurter...),24h 节流 |
| `services/currency/rate_math.dart` | 多币种纯函数层:取倒数、手动/自动合并、nativeAmount 折算、净资产折算 |
| `services/data/category_service.dart` | 分类图标名推导(关键词→icon,供 v23 迁移) |
| `services/data/migration_service.dart` | v1.15.0 账户独立迁移(备份/建表/继承币种/验证/回滚) |
| `services/data/note_history_service.dart` | 备注历史聚合查询 |
| `services/data/recurring_transaction_service.dart` | 周期交易:下次生成日期计算(闰年/2 月 30 日)、批量生成(千笔保护) |
| `services/data/seed_service.dart` | ★ 种子数据:默认账本/账户/分类,确定性 syncId(uuid v5)防多设备重复 |
| `services/data/tag_seed_service.dart` | 预设标签:20 色板 + 25 个默认标签 + 记账方式标签 |
| `services/data/tx_author_service.dart` | 共享账本 tx 作者标记(createdByUserId/lastEditedByUserId) |
| `services/export/config_export_service.dart` | ★ 全量配置导出/导入 YAML(账本/分类/账户/标签/周期/预算/设置/AI/Cloud) |
| `services/export/share_poster_service.dart` | 海报生成:屏外渲染 Widget → 3x PNG → 存相册/分享 |
| `services/export/share_poster_data_service.dart` | 海报数据计算(年/月/账本/档案,TOP3、环比、日均) |
| `services/export/share_poster_types.dart` | 海报类型枚举 + 数据模型 |
| `services/import/bill_parser.dart` | 账单解析抽象接口 + ParseResult |
| `services/import/csv_parser.dart` | CSV 解析:自动分隔符检测、引号转义、去 BOM |
| `services/import/file_reader.dart` | 分块流式读取 + 编码自动识别(UTF-16/GBK 等) |
| `services/import/parsers/alipay_parser.dart` | 支付宝账单解析器(关键词定位表头) |
| `services/import/parsers/wechat_parser.dart` | 微信账单解析器 |
| `services/import/parsers/generic_parser.dart` | 通用解析器(列数一致性找表头、字段规范化) |
| `services/maintenance/orphan_record.dart` | 孤儿数据模型(14 项类型枚举) |
| `services/maintenance/orphan_scanner.dart` | 13 个检测器(LEFT JOIN 悬空引用 + 文件孤儿 + 同步孤儿) |
| `services/maintenance/orphan_cleaner.dart` | 批量清理(事务内 dispatch,tx 失主只置 null) |
| `services/maintenance/orphan_seeder.dart` | debug 专用孤儿数据注入工具 |
| `services/marketing/product_promos.dart` | 家族产品推广中央注册表(蜜蜂家当/域名) |
| `services/payment/donation_service.dart` | iOS IAP 打赏(6 档咖啡商品) |
| `services/platform/app_link_service.dart` | ★ beecount:// 深链解析(9 种动作)+ iOS AppIntents 事件桥接 + 完成通知放行 |
| `services/platform/image_share_handler_service.dart` | Android 图片分享接收(MethodChannel → AutoBilling) |
| `services/platform/quick_actions_service.dart` | 长按图标快捷项(4 个)+ 冷启动缓存补发 |
| `services/platform/screenshot_monitor_service.dart` | Android 截图监听启停(Google Play 版禁用) |
| `services/security/app_lock_service.dart` | 应用锁:SHA-256 PIN、生物识别、超时锁定策略 |
| `services/system/logger_service.dart` | 日志系统:带 tag 结构化日志、环形缓冲、文件落盘(全局 logger 单例) |
| `services/system/reminder_monitor_service.dart` | 记账提醒自愈(resumed 时每 6h 检查一次) |
| `services/system/update_service.dart` | 更新服务外观层:checkUpdateWithUI 流程编排 |
| `services/ui/avatar_service.dart` | 头像管理:选图/压缩/相对路径存储/远端版本比对 |
| `services/ui/ui_scale_service.dart` | UI 缩放服务(类 rem:密度 80% + 宽度 20% 权重) |
| `services/update/update_result.dart` | 更新结果模型 + 工厂 |
| `services/update/update_checker.dart` | GitHub Releases 检查:随机 UA、3 重试、按 ABI 挑 APK(arm64 优先) |
| `services/update/update_downloader.dart` | APK 流式下载:进度对话框 + 通知节流 + 取消 |
| `services/update/update_installer.dart` | APK 安装:原生 Intent + OpenFilex 兜底 |
| `services/update/update_cache.dart` | APK 缓存:版本匹配、7 天过期、完整性验证(5-200MB + ZIP 魔数) |
| `services/update/update_notifications.dart` | 更新进度/完成/取消通知 |
| `services/update/update_permissions.dart` | 更新权限:存储 + 安装 + 通知(拒绝不阻塞) |
| `services/update/update_dialogs.dart` | 更新全部弹窗(确认/指南/错误兜底/版本对比) |
| `services/update/github_mirror_service.dart` | GitHub 镜像加速:6 源 HEAD 延迟测试 + 自动选最快 |
| `services/data_import_service.dart` | ★ 统一数据导入(CSV 与云端 FullPull 共用):账户按名去重、分类先一级后二级、批量插交易 |
| `services/attachment_service.dart` | 附件:选图/拍照/压缩、sha256 内容去重命名、urgent 模式、引用计数删除 |
| `services/attachment_export_import_service.dart` | 附件 + 头像 + 图标 → tar.gz 打包导出/导入 |
| `services/category_package_service.dart` | 分类包:分类配置 + 自定义图标 → zip 导出/导入 |
| `services/custom_icon_service.dart` | 自定义图标:压缩(96/48px)、sha256 缓存、共享图标完整性校验 |

### 10.6 状态层 `lib/providers/`

| 文件 | 功能 |
|---|---|
| `all_providers.dart` | 统一 barrel 导出 13 个核心 provider 文件 |
| `database_providers.dart` | ★ 数据库实例、repositoryProvider(按云配置注入 ChangeTracker)、当前账本、各实体 Stream/Future providers |
| `theme_providers.dart` | 主题模式/主色(推云)/隐藏金额/皮肤/收支配色/昵称,全部带持久化 Init + 云端推送 |
| `currency_providers.dart` | 主币种(云同步)/使用中币种/有效汇率/折算净资产/未折算计数 |
| `sync_providers.dart` | ★ 同步中枢:引擎分派、事件流 → tick 分发、启动同步、profile 对账 |
| `ui_state_providers.dart` | 底部 Tab、深链待处理、选中月、AppInit 状态机、Splash 预加载管线、展示缓存 |
| `statistics_providers.dart` | 统计查询全家桶(watch statsRefreshProvider tick) |
| `security_providers.dart` | 应用锁/隐私模糊屏状态 |
| `language_provider.dart` | 语言 StateNotifier + 持久化 |
| `font_scale_provider.dart` | 字体/UI 缩放(8 档 + 自定义) |
| `widget_provider.dart` | 小组件更新入口(updateAppWidget) |
| `budget_providers.dart` / `calendar_providers.dart` / `tag_providers.dart` | 预算/日历/标签域查询 |
| `avatar_providers.dart` / `github_star_provider.dart` | 头像 tick / GitHub Star 数(1h 缓存) |
| `shared_ledger_providers.dart` | 共享账本:刷新 tick、成员、收支统计(autoDispose) |
| `cloud_mode_providers.dart` | 应用模式(现仅 local) |
| `smart_billing_providers.dart` / `voice_billing_providers.dart` | 智能记账开关 / 语音记账设置 |
| `import_export_providers.dart` | 导入/云端恢复进度状态机 |
| `reminder_providers.dart` / `credit_card_providers.dart` / `credit_card_reminder_providers.dart` | 提醒设置 / 信用卡额度 / 还款提醒 |
| `maintenance_providers.dart` / `update_providers.dart` | 孤儿清理器 / 更新进度 |
| `ai_chat_providers.dart` / `ai_config_providers.dart` / `ai_privacy_consent_providers.dart` | AI 服务装配 / 全局配置 / 隐私同意 |

### 10.7 页面层 `lib/pages/`

| 目录/文件 | 功能 |
|---|---|
| `main/home_page.dart` | 首页明细 Tab:按日分组交易流 + 月度收支 header + 预算卡 + 提醒卡(双通道缓存展示) |
| `main/analytics_page.dart` | 洞察 Tab:月/年/全部 × 收支/结余图表、分类排行、外币折算横幅、海报分享 |
| `main/mine_page.dart` | 我的 Tab:云同步/设置/数据/AI/自动化/关于/打赏入口聚合页 |
| `main/ledgers_page_new.dart` | 账本列表:本地 + 远程分离、创建/切换/恢复、共享账本成员 |
| `account/accounts_page.dart` | 资产总览:类型分组拖拽排序、净资产卡、构成环图、多币种折算 |
| `account/account_edit_page.dart` | 账户新增/编辑表单(信用卡字段、隐藏与排序) |
| `account/account_detail_page.dart` | 账户详情:余额/消费/统计 + 分页交易 + 分类饼图 |
| `account/net_worth_trend_page.dart` | 全屏净值趋势图(近 3/6/12 月) |
| `ai/ai_chat_page.dart` | AI 对话:多模态记账、流式打字机、账单卡片确认、快捷指令 |
| `ai/ai_settings_page.dart` | AI 智能识别设置(开关/策略/视觉模型/隐私同意) |
| `ai/ai_provider_manage_page.dart` | AI 服务商管理(API Key/能力绑定/测活) |
| `ai/ai_prompt_edit_page.dart` | 自定义提示词编辑 |
| `ai/ai_model_selection_page.dart` | 文本/视觉模型选择 |
| `auth/splash_page.dart` / `welcome_page.dart` | 启动闪屏 / 首次欢迎页(隐私价值 + 选币种 + 引导) |
| `auth/login_page.dart` / `pin_setup_page.dart` / `app_lock_screen.dart` | 云登录(2FA)/ PIN 设置三步向导 / 解锁屏 |
| `automation/auto_billing_settings_page.dart` / `ios_auto_billing_page.dart` | 自动记账设置(Android 截图监听 / iOS 快捷指令) |
| `budget/budget_page.dart` / `budget_edit_page.dart` | 预算总览(进度环/日均可支配)/ 新增编辑 |
| `calendar/calendar_page.dart` | 日历页:月收支标记 + 选中日交易 |
| `category/category_manage_page.dart` | 分类管理:收支双 Tab、拖拽排序、自定义图标、分类包 |
| `category/category_edit_page.dart` | 分类编辑:名称/图标/二级/自定义图片 |
| `category/category_migration_page.dart` / `icon_picker_page.dart` | 分类批量迁移 / 图标选择器 |
| `cloud/cloud_service_page.dart` | ★ 云服务配置中心:5 种后端全向导 |
| `cloud/cloud_sync_page.dart` | 旧版快照同步页 + 预览弹窗 |
| `cloud/beecount_cloud_sync_page.dart` | BeeCount Cloud 增量同步状态面板 + 健康检查 |
| `cloud/devices_page.dart` / `invite_page.dart` / `join_shared_ledger_page.dart` | 设备管理 / 共享邀请码生成 / 加入共享账本 |
| `cloud/member_list_page.dart` / `member_stats_page.dart` | 成员管理(踢人/退出)/ 成员收支统计 |
| `cloud/sync_preview_dialog.dart` | 同步变更预览弹窗(分项勾选) |
| `currency/exchange_rate_page.dart` | 汇率管理:自动拉取 + 手动覆盖 + 主币种切换 |
| `data/import_page.dart` / `import_confirm_page.dart` / `export_page.dart` | 账单导入选择 / 导入确认与映射 / CSV 全量导出 |
| `donation/donation_page.dart` | 打赏页(IAP) |
| `maintenance/orphan_cleanup_page.dart` | 孤儿数据清理页(扫描/勾选/删除) |
| `report/annual_report_page.dart` | 年度账单:全年汇总/月度趋势/海报生成 |
| `settings/appearance_settings_page.dart` | 外观汇总:主题/主色/皮肤/字体/语言/金额格式 |
| `settings/personalize_page.dart` / `header_skin_page.dart` / `font_settings_page.dart` | 主题换装(6 色+自定义)/ 皮肤选择网格 / 字体档位 |
| `settings/language_settings_page.dart` | 语言设置(切后刷小组件) |
| `settings/data_management_page.dart` | 数据管理汇总(导入导出/分类/配置/存储/孤儿) |
| `settings/storage_management_page.dart` | 存储空间(扫描 AI 模型/APK 缓存清理) |
| `settings/config_import_export_page.dart` | 配置打包 JSON 导入导出 |
| `settings/automation_page.dart` / `smart_billing_page.dart` | 自动化汇总 / 智能记账汇总(Google Play 版隐藏截图入口) |
| `settings/widget_management_page.dart` | 小组件管理:6 类组件画廊 + 实时重渲染 |
| `settings/reminder_settings_page.dart` / `app_lock_settings_page.dart` | 记账提醒(精确闹钟)/ 应用锁(PIN/生物识别/超时) |
| `settings/about_page.dart` / `help_center_page.dart` / `privacy_policy_page.dart` | 关于(更新/Star)/ 帮助中心(WebView embed)/ 隐私政策 |
| `settings/log_center_page.dart` | 日志中心(过滤/搜索/导出) |
| `settings/shortcuts_guide_page.dart` / `attachment_preview_page.dart` | 快捷方式引导 / 附件导出导入预览 |
| `tag/tag_manage_page.dart` / `tag_edit_page.dart` / `tag_detail_page.dart` | 标签管理 / 编辑 / 详情统计 |
| `transaction/transaction_editor_page.dart` | ★ 交易编辑器:收支/转账、金额弹窗、分类/账户/标签/附件/多币种、周期、quickAdd |
| `transaction/search_page.dart` | 搜索:关键词/备注/金额/分类 + 日期分组 |
| `transaction/recurring_transaction_page.dart` / `_edit_page.dart` | 周期交易列表(启停/立即生成)/ 编辑(频率/结束条件) |
| `transaction/category_detail_page.dart` | 分类明细:统计 + 交易列表(四种排序) |
| `attachment/attachment_preview_page.dart` | 附件预览(左右滑动/缩放/增删) |

### 10.8 通用组件 `lib/widgets/`

| 目录/文件 | 功能 |
|---|---|
| `ui/`(13) | primary_header(页头+皮肤)、toast、dialog、wheel_date/time/picker(滚轮选择)、searchable_dropdown、message_popover_menu、bee_popup_menu、skeleton(骨架屏)、capsule_switcher、speed_dial_fab |
| `biz/`(26) | 金额:format_money/amount_text/amount_editor_sheet(金额键盘,6 万字节);列表:transaction_list(+item/row_title/day_section_header);卡片:section_card/ledger_card/home_budget_summary/product_promo_card;选择器:category_selector_dialog/ledger_selector_dialog/ledger_picker_sheet/account_selector/account_picker/note_picker_dialog/attachment_picker;其他:app_list_tile/app_empty/info_tag/tag_chip/pin_entry_pad/login_2fa_challenge_view/bee_icon |
| `ai/`(4) | typewriter_text(打字机)、bill_card_widget(账单卡片)、ai_quick_commands_bar、ai_privacy_consent_dialog |
| `analytics/`(2) | analytics_summary、category_rank_row |
| `category/`(2+1) | category_selector、subcategory_container;根级 category_icon |
| `charts/`(5) | line_chart(自研可滑动折线)、category_pie_chart、balance_trend_chart、asset_composition_chart、account_category_pie_chart |
| `currency/`(2) | currency_picker_sheet、currency_flag |
| `posters/`(6) | annual_report/month_summary/year_summary/ledger_summary/user_profile/app_promo 六类分享海报 |
| `transaction/`(1) | transfer_form 转账表单 |
| 根(2) | measure_size、category_icon |

### 10.9 桌面小组件 `lib/widget/`(单数)

| 文件 | 功能 |
|---|---|
| `widget_spec.dart` | ★ 12 个规格定义(logicalSize/iOS kind/Android provider/imageKey)、catalog、defaultSet |
| `widget_manager.dart` | ★ 渲染管理器:串行门、只渲已安装、预热、批渲染、错误防护、原生刷新 |
| `widget_data_service.dart` | 数据取数:repo→数值聚合(纯函数可单测,多币种复用 rate_math) |
| `views/glance_view.dart` | 收支速览视图 |
| `views/net_worth_view.dart` | 净资产视图 |
| `views/quick_add_view.dart` | 快速记账视图 |
| `views/budget_view.dart` | 预算进度视图 |
| `views/recent_view.dart` | 最近交易视图 |
| `views/dashboard_view.dart` | 综合仪表盘视图 |
| `views/widget_view_style.dart` | 小组件视觉规范(品牌色/明暗/等宽数字) |

### 10.10 样式 `lib/styles/` + 工具 `lib/utils/`

| 文件 | 功能 |
|---|---|
| `styles/tokens.dart` | ★ BeeTokens Design Token(七大类,函数式明暗切换)+ BeeTextTokens |
| `styles/header_skins.dart` | 皮肤注册表 kHeaderSkins + headerSkinById |
| `styles/header_skins/*.dart`(18) | 各款代码皮肤 part 文件:aurora 极光/bokeh/bubbles/clouds/galaxy 银河/image(图片)/lowpoly/memphis/ meteor 流星/mountains/prism 棱镜/sakura 樱花/silk 丝绸/skyline 天际线/sunset 落日/terrazzo 水磨石/waves 波光/pattern_skins(蜂巢/星空/条纹/樱花/流星/孟菲斯图案) |
| `utils/currencies.dart` | ★ 货币唯一定义处(150+ 币种 ISO 4217 + 符号/本地化名) |
| `utils/format_utils.dart` | 金额格式化(中文万/英文 k-M 智能精度/千分号) |
| `utils/date_parser.dart` | 日期解析(14 种格式,一律本地墙钟) |
| `utils/account_type_utils.dart` | 账户类型:资产/负债分类、估值账户、图标 |
| `utils/category_utils.dart` | 分类名显示(key 判定/翻译 key/多名称) |
| `utils/analytics_average.dart` | 日均/月均/年均统一求值 |
| `utils/lru_cache.dart` | LRU 工具(账户最近使用排序) |
| `utils/month_range.dart` | 自定义月度周期(monthStartDay) |
| `utils/net_worth_trend_utils.dart` | 净值趋势降采样(月末值) |
| `utils/notification_util.dart` / `_factory.dart` / `_android.dart` / `_ios.dart` | 通知抽象 / 平台工厂 / Android 实现(精确闹钟)/ iOS 实现 |
| `utils/platform_info.dart` | 平台信息(iOS 版本/AppIntents 支持) |
| `utils/shared_ledger_picker_filter.dart` | 共享账本 picker 过滤(syncId → 负 id) |
| `utils/transaction_edit_utils.dart` | 交易编辑入口装配(override 标签/多币种初始值) |
| `utils/voice_billing_helper.dart` | 语音记账编排(权限/录音/STT/记账/后处理) |
| `utils/image_billing_helper.dart` | 图片记账 UI 入口(相册/相机/loading) |
| `utils/file_picker_helper.dart` | FilePicker 封装(扩展名 fallback/异常) |
| `utils/xlsx_reader.dart` | XLSX → CSV 转换(日期规范化) |
| `utils/website_urls.dart` | 官网 URL 中央管理(embed/暗黑/主题色参数) |
| `utils/ui_scale_extensions.dart` | .scaled() 扩展 + UIScaleMixin |

### 10.11 本地化 `lib/l10n/`

| 文件 | 功能 |
|---|---|
| `app_zh.arb` / `app_zh_TW.arb` / `app_en.arb` / `app_ko.arb` | 翻译源文件(繁中 / 简中 / 英文 / 韩文) |
| `app_localizations*.dart` | `flutter gen-l10n` 生成产物(zh/en/ko + 汇总) |

---

## 11. 平台层(Android / iOS)

### 11.1 Android(`android/`)

- **构建**:`com.tntlikely.beecount`;compileSdk 36 / minSdk 23(record_android 硬要求)/ Kotlin 2.2 / Java 17 / coreLibraryDesugaring;flavor:`dev`(`.dev` 后缀 + "测试版")与 `prod`;release 开启 minify;ABI 拆分(arm64/armv7/x86_64/universal,APK 命名 `app-<flavor>-release-v<ver>(<code>).apk`)。
- **权限**:录音、媒体读取(Android 13 READ_MEDIA_IMAGES)、安装包(自更新)、通知/精确闹钟、启动完成、省电白名单、生物识别。**无无障碍服务**(截图监听走 ContentObserver)。
- **原生 Kotlin(13 个文件)**:MainActivity(5 个 MethodChannel:通知/安装 APK/截图监听/日志/图片分享)、LoggerPlugin、ScreenshotObserver、NotificationReceiver/ClickReceiver、7 个小组件 provider + SizedWidgetProviders(5 个尺寸子类)。
- **res**:自适应图标(mipmap-anydpi-v26)、双语小组件预览图、12 个 widget_info XML、RemoteViews 布局。

### 11.2 iOS(`ios/`)

- **Info.plist**:URL Scheme `beecount`、微信查询 Scheme、权限描述(照片/相机/麦克风/Face ID)、iCloud UbiquitousContainer、UIBackgroundModes(fetch/remote-notification)。
- **App Groups**:`group.com.tntlikely.beecount`(主 App + Widget 扩展共享渲染图片)。
- **WidgetKit 扩展**(`ios/BeeCountWidget/`):6 个 widget,TimelineProvider 读 App Group 图片,添加页预览用 bundle 静态资产,30 分钟刷新。
- **AppIntents**(iOS 16+ 条件编译):AutoBillingAppIntent(后台 AI 识别,30 秒硬窗口)+ AppIntentsBridge(Flutter 插件,事件缓存 + 25s 超时兜底)。
- **Podfile**:iOS 15.5,permission_handler 仅开 CAMERA/MICROPHONE/PHOTOS/NOTIFICATIONS。

---

## 12. 测试、脚本与 CI/CD

### 12.1 测试(`test/`,~70 文件)

| 目录 | 覆盖 |
|---|---|
| `test/ai/` | bill_info/prompt_builder/json 容错解析/provider 工厂/语音同步 |
| `test/cloud/sync/` | SyncEngine E2E(854 行,用 FakeBeeCountCloudProvider)、change_tracker、entity_serializer、错误存储 |
| `test/data/` + `test/repositories/` | 迁移 v30、汇率 schema、各仓库、monthStartDay 统计、净值趋势、多币种、exclude 标志、账户隐藏 |
| `test/maintenance/` | 孤儿扫描/清理 |
| `test/services/` | 汇率 6 源链、rate_math、数据导入、种子分类、周期交易、bill_creation、ai_bookkeeper |
| `test/sync/` | 多币种/排除/隐藏账户 apply 规则 |
| `test/styles/` `test/utils/` `test/widget/` `test/widgets/` | 皮肤、工具、小组件全链路(spec 映射/render harness/6 视图)、组件级 |

测试设施:mocktail、内存 Drift(`BeeDatabase.forTesting`)、SharedPreferences mock、ProviderScope override + 真 MaterialApp/L10n 渲染。无 golden、无 integration_test 目录。

### 12.2 脚本与工具

| 文件 | 用途 |
|---|---|
| `scripts/gen_adaptive_icons.py` | 从 logo.svg 生成 adaptive 前景/单色/legacy 图标(PIL) |
| `scripts/gen_store_test_data.py` | 商店截图演示账本数据(中英 CSV + YAML,图标对齐 seed_service) |
| `scripts/tools/generate_android_icons.py` | 图标加白底(5 档 dpi) |
| `scripts/i18n/check_status.dart` | i18n 完整性/多余/未使用 key 检查(zh/en/zh_TW) |
| `tool/generate_android_keystore.sh` | 发布 keystore 一键生成 + 写 key.properties |
| `demo/_generate.py` | 演示数据生成器(fixed seed) |

### 12.3 CI/CD(`.github/workflows/`)

- `release.yml`:push tag → Android job(4 ABI APK + AAB,Play 版动态移除 Play 禁止权限 → Google Play production)→ iOS job(archive + TestFlight)→ 合并生成 GitHub Release + Telegram 通知。
- `issue-lint.yml`:issue 质量门禁(needs-info 标签 + 双语评论)。
- `pullfrog.yml`:第三方 AI agent 工作流。

---

## 13. 构建与发布

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成 db.g.dart / l10n
flutter gen-l10n
flutter run --flavor dev
flutter build apk --flavor prod --release
```

- 版本号:`pubspec.yaml` 为 `0.0.1` 占位,CI 发布时用 tag + run_number 动态覆盖。
- 图标:`flutter_launcher_icons` 已配置(android true;iOS 手工维护);重跑后需恢复 legacy mipmap(`git checkout main -- android/app/src/main/res/mipmap-*/ic_launcher.png`)。
- 签名:`android/key.properties`(不入库),CI 无 key 时自动生成 ci-debug.keystore 兜底。

---

## 附录 A:核心概念速查

| 概念 | 说明 |
|---|---|
| user-global 实体 | account/category/tag/exchange_rate_override,变更挂 ledgerId=0 |
| synthetic id | 共享账本 Editor 视角,远端 syncId 映射的负整数本地 id |
| tick 刷新 | StateProvider<int> 计数器自增 → 派生 provider 重算 |
| LWW | 冲突解决:远端 server_received_at 恒胜 |
| fullPush | 首次同步/账本恢复时的整账本 JSON 导出推送 |
| urgent 模式 | iOS 后台附件同步复制,绕过 platform channel 防进程冻结 |
| monthStartDay | 账本自定义月度起始日(1-28),统计/预算/周期记账共用 |
| ChangeTracker 契约 | user-global 必须显式 ledgerId=0,否则 change 永不推送 |

## 附录 B:常用页面路由入口

| 入口 | 页面 |
|---|---|
| `beecount://voice` / `image` / `camera` / `ai-chat` / `add` / `new` / `open` / `auto-billing` / `quick-billing` | AppLink 9 种动作 |
| 小组件点击 | `beecount://new?type=expense\|income`(快速记账)、`beecount://open?page=assets\|budget\|detail` |
| 快捷操作(长按图标) | 图片 / 拍照 / 语音 / AI 对话 |
