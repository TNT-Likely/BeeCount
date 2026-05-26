# AI 多模态记账重构详细计划

> 状态:草稿,待用户拍板
> 起点:`main` 分支,本计划已纳入近期「多笔识别 + categories/accounts 收口」改动
> 关联 issue:[#164](https://github.com/TNT-Likely/BeeCount/issues/164) (批量账单提取)
> 目的:把 AI 记账从「散落在 6+ 个文件夹的样板代码」收口为「多模态底座 + 应用层 + 渠道入口」三层结构

---

## 0. TL;DR

当前 AI 记账代码 **5420 行** 分散在 8 个目录,有 4 大病灶:

1. **数据模型双轨** — `BillInfo`(AI 时代)+ `OcrResult`(legacy)同时存在,5 个渠道都重复做 `BillInfo → OcrResult → Transaction` 转换
2. **底座/业务边界缺失** — `BillExtractionService.forLedger` 自己 query repo,prompt 拼装、JSON 解析、提取调用、上下文加载全在一个类里
3. **5 个渠道样板代码冗余** — chat / image / voice / auto-screenshot / auto-text 都重复实现「调 extract → 转 OcrResult → createTx → 触发同步 → toast/通知/卡片」,改一处漏一处(本月 categories/accounts 漏传就是典型)
4. **目录语义混乱** — UI 入口放在 `lib/utils/`,业务 service 放在 `lib/services/{ai,billing,automation}/`,重复类(`CategoryMatcher` × 2 份)

重构后:

- 单一数据模型 `BillInfo`,`OcrResult` 退场
- 底座 `AiExtractionEngine` 纯函数,不依赖 Repository
- 应用层 `AiBookkeeper` 收口五条渠道的样板代码
- **保持现有顶层目录**(`pages/` / `widgets/` / `services/` / `utils/` / `ai/`),不新增一级目录,只在现有目录下做整理

---

## 1. 现状盘点

### 1.1 文件分布(共 5420 行,18 个文件)

| 文件 | 行数 | 职责 | 问题 |
|---|---:|---|---|
| **底座相关(应该是 Layer 1)** | | | |
| `lib/services/ai/bill_extraction_service.dart` | 506 | Prompt 拼装 + JSON 解析 + `forLedger` 工厂 + 校验/兜底 + speech-to-text | 一个类干 5 件事,且 `forLedger` 把 Repository 拉进了底座 |
| `lib/services/ai/ai_provider_factory.dart` | 627 | 服务商工厂(chat/vision/speech) | OK,只是位置应归入 `ai/` 根 |
| `lib/services/ai/ai_provider_manager.dart` | 432 | Provider 配置存取 | OK |
| `lib/services/ai/ai_provider_config.dart` | 221 | Provider 配置 model | OK |
| `lib/services/ai/ai_constants.dart` | 78 | SharedPrefs key 等常量 | OK |
| `lib/ai/tasks/bill_extraction_task.dart` | 194 | `BillInfo` + `BillType` 数据模型 | OK,位置欠合理 |
| **应用编排(应该是 Layer 2,但目前散落在 Layer 3)** | | | |
| `lib/services/ai/ai_chat_service.dart` | 367 | 对话编排:意图判定 + 多笔保存 + AIResponse | 内嵌了 BillInfo→保存样板代码,与下面 4 处重复 |
| `lib/services/automation/auto_billing_service.dart` | 682 | 后台监听 + 识别 + 多笔保存 + 通知 | 同上,占 100+ 行重复样板 |
| `lib/services/billing/voice_billing_service.dart` | 104 | 语音双步流程(STT → 提取) | API 暴露了 db 参数,实际不需要 |
| `lib/utils/image_billing_helper.dart` | 224 | 图片入口 UI + 保存样板 | 在 `utils/` 完全错位置 |
| `lib/utils/voice_billing_helper.dart` | 553 | 语音录音 UI + 保存样板 | 同上,且包含一个大的 `_VoiceRecordingDialog` 私有 widget |
| **数据/支持** | | | |
| `lib/services/billing/bill_creation_service.dart` | 544 | 接受 `OcrResult` 创建 Transaction | API 不接 `BillInfo`,5 个 caller 都要做转换 |
| `lib/services/billing/bill_recognition_result.dart` | 82 | `OcrResult` legacy model | 字段大量与 `BillInfo` 重复 |
| `lib/services/billing/category_matcher.dart` | 162 | 关键词 → 分类 ID 匹配(被使用) | OK |
| `lib/ai/services/category_matcher.dart` | 97 | **同名,但 dead code(0 caller)** | 必删 |
| `lib/services/billing/post_processor.dart` | 214 | 触发刷新 + 同步 | OK |
| **后台/配置** | | | |
| `lib/services/automation/auto_billing_config.dart` | 42 | timeouts 等常量 | OK |
| `lib/ai/services/category_matcher.dart` | 97 | (重复,见上) | 必删 |

### 1.2 渠道入口现状(5 条路径都自己拼五段样板)

```
[chat]           ai_chat_page → ai_chat_service._handleTransaction
[image]          image_billing_helper._processImageBilling
[voice]          voice_billing_helper._VoiceRecordingDialog._stopAndProcess
[auto-screenshot] auto_billing_service.processScreenshot
[auto-text]      auto_billing_service.processText
```

5 处都在做同样的事:

1. 拿到输入(text / image / audio)
2. 调 `BillExtractionService.forLedger().extractFromXxx()` → `List<BillInfo>`
3. 把 BillInfo 转成 `OcrResult`(字段一一拷贝)
4. 调 `BillCreationService.createBillTransaction(ocrResult, ...)` → `transactionId`
5. `PostProcessor.run/sync(ref, ledgerId)` 刷新+同步
6. 显示结果(toast / 通知 / message 卡片)

**重复代码估算**:每条渠道 30~80 行样板,5 条总计 ~250 行可消除。

### 1.3 已确定要保留的核心模型

- `BillInfo`(`lib/ai/tasks/bill_extraction_task.dart`):AI 提取结果的统一表达
- `BillExtractionService.forLedger` 模式:为渠道做上下文注入(分类/账户/币种)

### 1.4 已确定要淘汰的

- `OcrResult`(`bill_recognition_result.dart`):AI 字段(`aiCategoryName/aiType/aiAccountName/aiEnhanced`)与 `BillInfo` 重复
- `lib/ai/services/category_matcher.dart`:dead code

---

## 2. 目标架构

### 2.1 三层划分

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3 · Channel Entry                                         │
│   • ai_chat_page          (对话 UI + bill 卡片 metadata)        │
│   • image_capture_entry   (相册/相机入口,原 image_billing_helper) │
│   • voice_capture_entry   (语音录音 UI,原 voice_billing_helper) │
│   • auto_billing_service  (后台监听:screenshot/text → bookkeeper)│
│   职责:收输入 → 调 Layer 2 → 展示结果(toast/通知/卡片)         │
│   不允许 import Layer 1                                          │
└────────────────────────────────┬────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│ Layer 2 · AiBookkeeper (Application Service)                    │
│   • fromText(text, ledgerId, billingTypes, l10n)                │
│   • fromImage(file, ledgerId, billingTypes, saveAttachment,...) │
│   • fromAudio(file, ledgerId, billingTypes, l10n)               │
│   职责:                                                         │
│     1. Context.forLedger(repo, ledgerId)  ← 唯一调用点          │
│     2. engine.extractFromXxx(ctx)         ← 拿 List<BillInfo>   │
│     3. 逐笔 BillPersistence.save(bill)    ← 内部转 Transaction   │
│     4. PostProcessor.run(ref, ledgerId)   ← 触发同步             │
│   返回:BookkeepingResult { savedBills, transactionIds, dropped }│
└────────────────────────────────┬────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│ Layer 1 · AiExtractionEngine (Multimodal 底座)                  │
│   • extractFromText(text, AiExtractionContext)                  │
│   • extractFromImage(image, AiExtractionContext)                │
│   • extractFromAudio(audio, AiExtractionContext)                │
│     → ({bills: List<BillInfo>, recognizedText: String?})        │
│   职责:                                                         │
│     1. PromptBuilder.build(ctx)           ← prompt 模板拼装     │
│     2. AIProviderFactory.{chat,vision,..} ← 服务商调用          │
│     3. JsonResponseParser.parse(response) ← 数组/单对象 + JSON5  │
│     4. _sanitize(bill)                    ← amount/time 校验兜底│
│   不依赖:Repository / Riverpod / UI                              │
└─────────────────────────────────────────────────────────────────┘

Context (Layer 2 → Layer 1 的 DTO):
   AiExtractionContext {
     List<String> expenseCategories, incomeCategories, accounts;
     String? currency;
     String? customPromptTemplate;
   }
   static Future<AiExtractionContext> forLedger(BaseRepository, int ledgerId)
```

**强制依赖方向(单向):L3 → L2 → L1**,绝不反向。

### 2.2 目录调整(保持现有顶层目录,只在子目录整理)

**不新增顶层目录**。L1 / L2 / L3 通过现有的 `lib/ai/` / `lib/services/` / `lib/pages/widgets/utils/` 表达:

```
lib/
├── ai/                                          ← Layer 1 底座 (现有顶层目录,做内部整理)
│   ├── core/                                    ← 新建子目录
│   │   ├── bill_info.dart                       ← 原 ai/tasks/bill_extraction_task.dart
│   │   ├── ai_extraction_context.dart           ← 新
│   │   ├── ai_extraction_engine.dart            ← 原 bill_extraction_service.dart 重写
│   │   ├── prompt_builder.dart                  ← 从 bill_extraction_service 拆
│   │   └── json_response_parser.dart            ← 从 bill_extraction_service 拆
│   ├── providers/                               ← 新建子目录,服务商抽象集中
│   │   ├── ai_provider_factory.dart             ← 移自 services/ai/
│   │   ├── ai_provider_manager.dart             ← 移自 services/ai/
│   │   ├── ai_provider_config.dart              ← 移自 services/ai/
│   │   └── ai_constants.dart                    ← 移自 services/ai/
│   └── (旧 ai/tasks/ ai/services/ 删除)
│
├── services/
│   ├── ai/                                      ← Layer 2 应用层 (现有目录,瘦身)
│   │   ├── ai_bookkeeper.dart                   ← 新,fromText/fromImage/fromAudio 入口
│   │   ├── bookkeeping_result.dart              ← 新,结果模型
│   │   ├── ai_chat_service.dart                 ← 瘦身,只剩意图判定 + 自由对话编排
│   │   └── ai_quick_command_service.dart        ← 不动
│   ├── billing/                                 ← 现有目录
│   │   ├── bill_creation_service.dart           ← API 改造,接 BillInfo
│   │   ├── category_matcher.dart                ← 不动
│   │   ├── post_processor.dart                  ← 不动
│   │   └── (bill_recognition_result.dart 删除)
│   │   └── (voice_billing_service.dart 删除,合入 ai/core/ai_extraction_engine)
│   └── automation/                              ← 现有目录,后台监听
│       ├── auto_billing_service.dart            ← 瘦身,只剩监听 + 通知,业务调 ai_bookkeeper
│       └── auto_billing_config.dart             ← 不动
│
├── pages/                                       ← 现有目录,所有页面集中(不动顶层)
│   ├── ai/                                      ← AI 对话 + AI 设置
│   │   ├── ai_chat_page.dart                    ← 瘦身,UI 调 ai_bookkeeper
│   │   ├── ai_settings_page.dart                ← 不动
│   │   ├── ai_provider_manage_page.dart         ← 不动
│   │   ├── ai_model_selection_page.dart         ← 不动
│   │   └── ai_prompt_edit_page.dart             ← 不动
│   └── automation/                              ← 自动记账设置(已存在)
│       └── auto_billing_settings_page.dart      ← 不动
│
├── widgets/
│   └── ai/                                      ← 现有目录
│       ├── bill_card_widget.dart                ← 不动
│       ├── typewriter_text.dart                 ← 不动
│       └── ai_quick_commands_bar.dart           ← 不动
│
└── utils/                                       ← 现有目录,渠道 UI workflow 帮助类
    ├── image_billing_helper.dart                ← 瘦身,调 ai_bookkeeper.fromImage
    └── voice_billing_helper.dart                ← 瘦身,调 ai_bookkeeper.fromAudio
```

**对比变化(纯目录视角):**

| 操作 | 数量 | 详情 |
|---|---:|---|
| 新建子目录 | 2 | `lib/ai/core/` + `lib/ai/providers/` |
| 删除子目录 | 2 | `lib/ai/tasks/` + `lib/ai/services/`(后者本就是 dead code) |
| 文件搬家(同 services/ai/) | 4 | provider_factory/manager/config/constants → `lib/ai/providers/` |
| 文件搬家(bill_extraction_service 拆 4 文件) | 1 | → `lib/ai/core/` |
| 文件改名/拆分 | 0 | 文件名都不变 |
| 新增文件 | 5 | engine + context + parser + builder + bookkeeper + result |
| 删除文件 | 3 | OcrResult + voice_billing_service + ai/services/category_matcher(dead) |

**没有任何一级目录变化**,所有改动都在 `lib/ai/` 和 `lib/services/ai/billing/` 子目录里发生。

### 2.3 关键 API 草案

```dart
// ============================================================
// Layer 1
// ============================================================

class AiExtractionContext {
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final List<String> accounts;
  final String? currency;
  final String? customPromptTemplate;

  const AiExtractionContext({...});

  static Future<AiExtractionContext> forLedger({
    required BaseRepository repository,
    required int ledgerId,
  });

  /// 测试 / 无账本场景的 fallback,用 hardcoded 分类
  static const AiExtractionContext fallback = ...;
}

abstract class AiExtractionEngine {
  Future<List<BillInfo>> extractFromText(String text, AiExtractionContext ctx);
  Future<List<BillInfo>> extractFromImage(File image, AiExtractionContext ctx);
  Future<AudioExtractionResult> extractFromAudio(File audio, AiExtractionContext ctx);
}

class AudioExtractionResult {
  final List<BillInfo> bills;
  final String? recognizedText;
}

// 实现类:DefaultAiExtractionEngine,内部用 PromptBuilder + JsonResponseParser

// ============================================================
// Layer 2
// ============================================================

class BookkeepingResult {
  final List<BillInfo> savedBills;
  final List<int> transactionIds;
  final int droppedCount;
  final List<int> ledgerIdsTouched;

  bool get success => transactionIds.isNotEmpty;
  bool get isMulti => transactionIds.length > 1;
  double get totalAbsAmount => savedBills.fold(0.0, (s, b) => s + b.amount!.abs());
  String? get firstNote => savedBills.isEmpty ? null : savedBills.first.note;
}

class AiBookkeeper {
  final BaseRepository _repo;
  final AiExtractionEngine _engine;
  final BillCreationService _persister;

  AiBookkeeper(this._repo, this._engine, this._persister);

  Future<BookkeepingResult> fromText({
    required String text,
    required int ledgerId,
    required List<String> billingTypes,
    AppLocalizations? l10n,
  });

  Future<BookkeepingResult> fromImage({
    required File image,
    required int ledgerId,
    required List<String> billingTypes,
    bool saveFirstAttachment = false,
    AppLocalizations? l10n,
  });

  Future<({BookkeepingResult result, String? recognizedText})> fromAudio({
    required File audio,
    required int ledgerId,
    required List<String> billingTypes,
    AppLocalizations? l10n,
  });
}

// 通过 Provider 暴露:
final aiBookkeeperProvider = Provider<AiBookkeeper>((ref) => AiBookkeeper(
  ref.watch(repositoryProvider),
  ref.watch(aiExtractionEngineProvider),
  ref.watch(billCreationServiceProvider),
));
```

---

## 3. 实施计划(**单 PR + 单 commit**)

**最终交付:1 个 PR,1 个 commit**。不拆分 PR,不分多 commit,保证 reviewer 看到一个完整且自洽的 diff。

下面的「Step 1~5」是**实施顺序指南**(让开发者头脑清晰、避免改一半挂了),不是 PR 边界。开发期间 working tree 可以分阶段编译通过逐步推进,但最终只产出一个 commit、一个 PR。

### Step 1: 底座抽离

**范围:**

- 新建 `lib/ai/core/` 下 4 个文件
- `BillExtractionService` 保留为 alias,内部委托给 `DefaultAiExtractionEngine`

**步骤:**

1. **新建** `lib/ai/core/bill_info.dart`:
   - 把 `lib/ai/tasks/bill_extraction_task.dart` 全部内容搬过来
   - 删除 `BillExtractionTask` 类(实际未使用,只留 `BillInfo` + `BillType`)

2. **新建** `lib/ai/core/ai_extraction_context.dart`:
   - 定义 `AiExtractionContext` + `forLedger` factory
   - 内部沿用现有 `getUsableCategories('expense'/'income')` + `getAllAccounts` 按 ledger 币种过滤逻辑

3. **新建** `lib/ai/core/prompt_builder.dart`:
   - 把 `BillExtractionService._buildPrompt / _buildCategoryHint / _buildAccountHint / defaultPromptTemplate` 全部搬过来
   - 入参 `(AiExtractionContext, String inputSource, String ocrText)`,出参 `String`
   - 这一层完全无副作用、可单测

4. **新建** `lib/ai/core/json_response_parser.dart`:
   - 搬 `_parseResponse / _extractBalancedBlock / _cleanupJson / _sanitize`
   - 出参 `List<BillInfo>`(已校验,已兜底)
   - 单测覆盖:trailing comma / 数组 / 单对象 / 时间字符串 / 空响应

5. **新建** `lib/ai/core/ai_extraction_engine.dart`:
   - 抽象类 + 默认实现 `DefaultAiExtractionEngine`
   - 内部:`PromptBuilder.build → AIProviderFactory.chat/vision/speech → JsonResponseParser.parse`
   - 暴露 3 个 extract 方法

6. **改造** `lib/services/ai/bill_extraction_service.dart`:
   - 保留 class 名,内部委托给 `DefaultAiExtractionEngine`
   - 旧 `forLedger` 工厂保留,内部构造 context → 委托
   - 标记 `@Deprecated('use AiExtractionEngine + AiExtractionContext')`

**影响面:**

- 调用方暂时不动(`BillExtractionService.forLedger(...).extractFromText(...)` 还能工作)
- 但 import 路径不变,行为不变
- 新增 4 个文件,旧文件保留(后续 P5 删)

**验证:**

- `flutter analyze` 0 error
- 单测覆盖 PromptBuilder + JsonResponseParser
- 5 个 channel 跑一遍冒烟(chat 单笔、chat 多笔、image、voice、auto-screenshot)

### Step 2: 应用层 AiBookkeeper

**范围:**

- 新建 `lib/bookkeeping/` 下 3 个文件
- `BillCreationService` 加 `createFromBill(BillInfo, ...)` 重载

**步骤:**

1. **改造** `BillCreationService`:
   - 新增方法:
     ```dart
     Future<int?> createFromBill({
       required BillInfo bill,
       required int ledgerId,
       required List<String> billingTypes,
       AppLocalizations? l10n,
       bool autoAddTags = true,
     });
     ```
   - 内部:把 `BillInfo` 转 `OcrResult`(临时桥)→ 走原 `createBillTransaction` 路径
   - 旧 `createBillTransaction(OcrResult, ...)` 保留(`@Deprecated`)

2. **新建** `lib/bookkeeping/bookkeeping_result.dart`:
   - `BookkeepingResult` 数据类
   - 提供便捷 getter:`success / isMulti / totalAbsAmount / firstNote`

3. **新建** `lib/bookkeeping/bill_persistence.dart`(内部辅助):
   - `Future<int?> save({BillInfo bill, int ledgerId, List<String> billingTypes, AppLocalizations? l10n, BaseRepository repo, BillCreationService creator})`
   - 包装:`creator.createFromBill(...)` + 异常吞掉 + 日志
   - 返回 txId(null 表示失败)

4. **新建** `lib/bookkeeping/ai_bookkeeper.dart`:
   - `AiBookkeeper` 类,三个 `fromXxx` 方法
   - 内部循环逐笔 `BillPersistence.save`,聚合 `BookkeepingResult`
   - `fromImage` 的 `saveFirstAttachment` 参数:首笔挂图片附件

5. **新增 Provider** `aiBookkeeperProvider`(放 `lib/providers/`)

**影响面:**

- 新增文件,不动 caller
- 验证 `AiBookkeeper` 可单独工作(可以写一个临时测试 page)

**验证:**

- `flutter analyze` 0 error
- 单测覆盖 `AiBookkeeper.fromText`(用 mock engine + mock repo)
- BookkeepingResult getter 正确

### Step 3: 5 个渠道切换到 AiBookkeeper

**这是改动最大的一步,但每个 channel 独立,可在本地工作目录内逐一切完后再统一提交。**

**改造前-改造后对照(以 image_billing_helper 为例):**

改造前(~80 行):
```dart
final service = await BillExtractionService.forLedger(...);
final bills = await service.extractFromImage(imageFile);
if (bills.isEmpty) { ... toast 失败 ... }
final currentLedger = ...;
final autoAddTags = ...;
final autoAddAttachment = ...;
final attachmentService = ...;
final createdIds = <int>[];
double totalAbsAmount = 0;
String? firstTypeText;
for (final bill in bills) {
  final ocrResult = OcrResult(amount: bill.amount, note: ..., aiCategoryName: ..., aiType: ..., ...);
  final txId = await billCreationService.createBillTransaction(...);
  if (txId == null) continue;
  createdIds.add(txId);
  totalAbsAmount += ...;
  if (autoAddAttachment && createdIds.length == 1) await attachmentService.saveAttachment(...);
}
await PostProcessor.run(ref, ...);
showToast(...);
```

改造后(~15 行):
```dart
final bookkeeper = ref.read(aiBookkeeperProvider);
final result = await bookkeeper.fromImage(
  image: imageFile,
  ledgerId: currentLedger.id,
  billingTypes: [source == ImageSource.gallery ? TagSeedService.billingTypeImage : TagSeedService.billingTypeCamera, TagSeedService.billingTypeAi],
  saveFirstAttachment: ref.read(smartBillingAutoAttachmentProvider),
  l10n: l10n,
);
if (!result.success) {
  showToast(context, l10n.aiOcrCheckLog);
  return;
}
await PostProcessor.run(ref, ledgerId: currentLedger.id, tags: true, attachments: result.transactionIds.isNotEmpty);
showToast(context, result.isMulti ? '已记账 ${result.transactionIds.length} 笔' : l10n.aiOcrSuccess(...));
```

**5 个 channel 改造清单(本地推进顺序,**最终合并入唯一 commit**):**

| # | 文件 | 主要改动 | 行数变化 |
|---|---|---|---:|
| 1 | `lib/services/ai/ai_chat_service.dart` | `_handleTransaction` 改调 `_bookkeeper.fromText`,删 `_saveBill` | -80 |
| 2 | `lib/utils/image_billing_helper.dart` | 用 `bookkeeper.fromImage` 替换循环 | -50 |
| 3 | `lib/utils/voice_billing_helper.dart` | 用 `bookkeeper.fromAudio` 替换 `_stopAndProcess` 中段 | -60 |
| 4 | `lib/services/automation/auto_billing_service.dart`(processScreenshot) | 用 `bookkeeper.fromImage`,删本地循环 | -80 |
| 5 | `lib/services/automation/auto_billing_service.dart`(processText) | 用 `bookkeeper.fromText`,删本地循环 | -60 |

**预计删除 330+ 行重复代码,新增 ~50 行 caller 代码,净减 280+ 行。**

**本步骤之内每改完一个 channel 就跑对应回归测试**(见 §10 矩阵),全部通过后才进入 Step 4。

### Step 4: OcrResult 退场

**前提:**Step 3 完成后,5 个 channel 都不再直接构造 `OcrResult`,只在 `BillCreationService.createFromBill` 内部用作临时桥。

**步骤:**

1. **改造** `BillCreationService`:
   - 把 `createFromBill` 内部直接落库(不再调旧 `createBillTransaction`)
   - 删除 `createBillTransaction(OcrResult, ...)` 旧方法

2. **删除** `lib/services/billing/bill_recognition_result.dart`(`OcrResult` 类)

3. **clean up** 残余 `OcrResult` 引用(应该只剩零星几处)

**风险:**`OcrResult` 字段(`aiCategoryName/aiType/aiAccountName/aiEnhanced/aiProvider`)可能被其他地方依赖,需 grep 确认。

### Step 5: 目录搬家 + 文件清理

**步骤:**

1. **删除 dead code**:
   - `lib/ai/services/category_matcher.dart`(0 caller)
   - 整个 `lib/ai/services/` 目录(只有这一个文件)
   - `lib/ai/tasks/` 目录(P1 已搬,这里删空目录)

2. **目录搬家**(按 §2.2 表格执行):

   ```bash
   git mv lib/services/ai/ai_provider_factory.dart       lib/ai/providers/
   git mv lib/services/ai/ai_provider_manager.dart        lib/ai/providers/
   git mv lib/services/ai/ai_provider_config.dart         lib/ai/providers/
   git mv lib/services/ai/ai_constants.dart               lib/ai/providers/
   git mv lib/services/ai/bill_extraction_service.dart    /dev/null  # 已是 alias,删
   git mv lib/services/ai/ai_chat_service.dart            lib/features/ai_chat/
   git mv lib/services/ai/ai_quick_command_service.dart   lib/features/ai_chat/
   git mv lib/pages/ai/ai_chat_page.dart                  lib/features/ai_chat/
   git mv lib/pages/ai/ai_settings_page.dart              lib/features/ai_settings/
   git mv lib/pages/ai/ai_provider_manage_page.dart       lib/features/ai_settings/
   git mv lib/pages/ai/ai_model_selection_page.dart       lib/features/ai_settings/
   git mv lib/pages/ai/ai_prompt_edit_page.dart           lib/features/ai_settings/
   git mv lib/widgets/ai/*.dart                            lib/features/ai_chat/widgets/
   git mv lib/utils/image_billing_helper.dart             lib/features/ocr_capture/image_capture_entry.dart
   git mv lib/utils/voice_billing_helper.dart             lib/features/ocr_capture/voice_capture_entry.dart
   git mv lib/services/automation/auto_billing_service.dart   lib/features/auto_billing/
   git mv lib/services/automation/auto_billing_config.dart    lib/features/auto_billing/
   git mv lib/pages/automation/auto_billing_settings_page.dart lib/features/auto_billing/
   git mv lib/services/billing/category_matcher.dart      lib/bookkeeping/
   git mv lib/services/billing/voice_billing_service.dart /dev/null  # P3 已替换,删
   ```

3. **全局 import path 改写**(VSCode 或 sed 批量替换):
   - `services/ai/ai_provider_factory` → `ai/providers/ai_provider_factory`
   - `services/ai/bill_extraction_service` → `ai/core/ai_extraction_engine`
   - `services/ai/ai_constants` → `ai/providers/ai_constants`
   - 其他位置保持不动(`services/ai/ai_chat_service` / `widgets/ai/...` / `utils/...billing_helper` 都不动)

---

## 4. 单笔/多笔验证矩阵

每个 phase 完成后,跑这个矩阵:

| 渠道 | 单笔 | 多笔 | amount=0 | 网络失败 | 时间字符串异常 |
|---|---|---|---|---|---|
| AI 对话 | ✅ | ✅ | 拒绝并提示 | error response | sanitize 兜底 |
| 相册图片 | ✅ | ✅ 多笔(罕见) | toast 提示 | toast 提示 | sanitize 兜底 |
| 相机拍照 | ✅ | ✅ | 同上 | 同上 | 同上 |
| 录音 | ✅ | ✅ | toast | toast | 同上 |
| 自动截图 | ✅ | ✅ | 通知 | 通知 | 同上 |
| 自动通知文本 | ✅ | ✅ | 通知 | 通知 | 同上 |

**「时间字符串异常」**指 AI 偶发吐出 `"2222 - 2 2 - 2 T 7:17"` 这类不可解析的格式,sanitize 应兜底为 `DateTime.now()`,不丢弃这一笔。

---

## 5. 决策记录

### 5.1 为什么不把 `AiBookkeeper` 也放进 `lib/ai/`?

`lib/ai/` 是「与 LLM 服务商交互的底座」,目标是**可以独立抽出来做 package 的程度**。
`AiBookkeeper` 依赖 `BaseRepository` / `BillCreationService` / `PostProcessor`,这些都是 BeeCount 业务,不可能抽包。
所以应用层放 `lib/bookkeeping/`,跟底座区分开。

### 5.2 为什么保留 `BillCreationService`,不合入 `AiBookkeeper`?

`BillCreationService` 已被**非 AI 渠道**(手动记账编辑器、CSV 导入)使用,职责是「转换为 Transaction 写入数据库」,与 AI 无关。
AI 渠道只是它的 caller 之一。强行合并会让手动记账绕远路。

### 5.3 为什么不复用 `BillExtractionService` 名字,而是新建 `AiExtractionEngine`?

- 名字升级反映职责变化:`Service`(隐含有状态、可注入)→ `Engine`(纯函数、无副作用)
- 旧名字保留为 alias 让 P3 之前的 caller 不挂,P5 才物理删除
- 跟 `lib/cloud/sync-engine` 命名风格统一

### 5.4 OcrResult 是否值得分阶段退场?

值得。直接删会导致 P3 单 commit 改 8+ 个文件,事故面太大。
做法:P2 加 `createFromBill(BillInfo)` 重载,P3 caller 切过去,P4 才删 `OcrResult` 本身。

---

## 6. 工作量估算

| Step | 工作量(行变化) | 预计时长 |
|---|---|---|
| Step 1 底座抽离 | +600 / -50(主要新增) | 1 个工作日 |
| Step 2 应用层 | +200 / -0 | 半个工作日 |
| Step 3 切换 5 channel | +50 / -330 | 1 个工作日 |
| Step 4 OcrResult 退场 | +20 / -200 | 半个工作日 |
| Step 5 目录搬家 + import 改 | 纯机械操作 | 半个工作日 |
| **合计(单 PR 单 commit)** | **+870 / -580 = 净 +290** | **~3.5 工作日** |

> 净增主要在 Step 1 抽出的几个新文件(`PromptBuilder` / `JsonResponseParser` / `Context` / `Engine` 抽象+实现)。代码总行数因消除样板下降到约 5000 行(从 5420)。

---

## 7. 风险与回滚

### 7.1 PR 策略 — 单 PR 单 commit

**只有一个 PR、一个 commit**。reviewer 看到的是一份完整且自洽的 diff:
- 所有新文件 + 所有删除 + 所有 import 路径变更全在同一 commit
- 不留中间状态(没有「P1 合了 P2 没合」这种半 working 状态)
- revert 单个 commit 就能彻底回到改前

### 7.2 风险等级

- **🟡 中等**:整个重构作为一个 commit,如果合入后某条渠道(尤其 auto_billing 后台监听)出现回归,影响所有 AI 记账用户
- **缓解**:
  1. 合入前必须通过 §10 完整回归测试矩阵
  2. 灰度提示用户可在 AI 设置页关闭 AI 记账(已有开关)
  3. 出问题直接 `git revert <sha>` 回滚整个 commit

### 7.3 不做灰度

**不做灰度切换**。理由:

- AI 记账是用户主动触发的本地功能,无服务端协议依赖,无版本协商问题
- 5 个 channel 都有手动记账可 fallback,用户感知影响有限
- 灰度会让两套代码并存,增加维护负担,且与「单 PR 单 commit」冲突

发版后出问题:revert 单个 commit + 下个版本修复重发。

---

## 8. 与近期改动的衔接

**已完成(本计划开始前):**

- ✅ 多笔识别支持(parser 数组化 + 5 channel 循环保存)
- ✅ time 字符串容错 + sanitize 兜底
- ✅ JSON5 trailing comma 兜容
- ✅ `forLedger` 工厂引入(临时收口 categories/accounts 漏传)
- ✅ AIBillService 删除

**本计划的实施会保留这些行为,但重新组织代码位置。** parser、sanitize、forLedger 逻辑在 P1 拆到 `JsonResponseParser` / `AiExtractionContext` 里,行为不变。

---

## 9. 回归测试方案

> **核心原则**:重构不修改可观察行为。任何已工作的场景在重构后必须依然工作,且日志/通知/卡片输出**字符级一致**(除非有意改动)。

### 9.1 现有自动化测试盘点

```
test/
├── cloud/sync/                      ← 同步引擎,与本次重构无关
├── data/repositories/               ← Repository 单测,getUsableCategories 等被本次依赖
└── maintenance/                     ← 孤儿扫描,无关
```

**结论**:项目**当前没有 AI 记账相关的自动化测试**。本次重构必须**补足底座层的单测**,并在合并前完成手动回归矩阵。

### 9.2 必须新增的单元测试(本次 PR 内一并提交)

放在 `test/ai/core/` 下:

| 测试文件 | 覆盖目标 | 关键 case |
|---|---|---|
| `prompt_builder_test.dart` | `PromptBuilder.build(ctx, ...)` | • 注入分类列表正确替换 `{{CATEGORIES}}`<br>• 注入账户列表正确替换 `{{ACCOUNTS}}`<br>• 自定义 prompt 模板优先<br>• 空 context → hardcoded fallback |
| `json_response_parser_test.dart` | `JsonResponseParser.parse(response)` | • 数组格式 `[{...}, {...}]` → N 笔<br>• 单对象 `{...}` → 1 笔<br>• Markdown 包裹 \`\`\`json ... \`\`\`<br>• Trailing comma `,}` `,]` → 清理后解析成功<br>• 无效时间字符串 → 兜底当前时间<br>• 缺 amount / amount=0 → 丢弃<br>• 完全无 JSON → 空列表<br>• 字符串字面量内逗号保留(`"note":"苹果,香蕉"`) |
| `ai_extraction_context_test.dart` | `AiExtractionContext.forLedger(repo, ledgerId)` | • 返回的分类列表包含当前账本可用分类(用 in-memory db)<br>• 账户按账本币种过滤<br>• ledger 不存在时账户为空<br>• 加载用户自定义 prompt 模板 |
| `bill_info_test.dart` | `BillInfo.fromJson` + `copyWith` | • time 字符串内嵌空格 parse(`"2222 - 2 2 - 2T7:17"`)<br>• type 中英文兼容<br>• tags 字符串/数组双兼容<br>• copyWith 字段独立替换 |

放在 `test/services/ai/` 下:

| 测试文件 | 覆盖目标 | 关键 case |
|---|---|---|
| `ai_bookkeeper_test.dart` | `AiBookkeeper.fromText` (用 mock engine + in-memory repo) | • 单笔成功 → savedBills.length=1, txIds.length=1<br>• 多笔成功 → N 笔全保存<br>• 单笔失败不影响其他笔<br>• 全失败 → BookkeepingResult.success=false<br>• 空 list → success=false<br>• billingTypes 正确传递到 BillCreationService |

**目标覆盖率**:底座层(`lib/ai/core/`)代码行覆盖 ≥ 80%,应用层(`lib/services/ai/ai_bookkeeper.dart`)≥ 70%。

### 9.3 手动回归测试矩阵(合并前必跑)

每条渠道 × 5 个场景,共 **30 个手动验证点**。建议在真机(Android + iOS 各一)各跑一遍。

| 渠道 | 单笔 OK | 多笔 OK | amount 缺失/=0 | 网络/API 失败 | time 字符串异常 |
|---|---|---|---|---|---|
| **AI 对话**(`ai_chat_page`) | 输入「买菜30」→ 1 张 bill 卡 | 输入「早地铁5 中饭40 晚水果35」→ 3 张 bill 卡 | 输入「abc」→ 提示「未识别到」 | 关网 → toast「网络连接失败」 | mock AI 返回乱时间 → 卡片显示当前时间 |
| **相册图片** | 选支付截图 → toast 「✅ ¥X 成功」 | 选含多笔的账单页 → toast「× N」 | 选猫图 → toast「未识别到金额」 | 关网 → toast「识别失败」 | mock → 当前时间记入 |
| **相机拍照** | 拍支付码 → 同上 | (同图片,场景罕见) | toast | toast | 同上 |
| **录音** | 说「打车 35 块」→ toast「✅ 语音记账成功」 | 说「早上 X 中午 Y 晚上 Z」→ toast「× 3」 | 静音 → 「未检测到语音」 | 关网 → toast | 当前时间记入 |
| **自动截图监听** | 微信支付截图 → 通知「✅ ¥X 成功」 | 罕见,但应 → 通知「成功 N 笔」 | 非支付截图 → 通知「未识别到支付信息」 | 关网 → 通知「识别失败」 | mock → 当前时间 |
| **自动通知文本监听** | 收到支付推送 → 通知「✅ ¥X 成功」 | (单条推送罕见多笔) | 无金额 → 通知「未识别到金额信息」 | 关网 → 通知失败 | mock → 当前时间 |

**额外的「不变量」验证**(对每一条上面场景都验证):

1. ✅ **prompt 里 categories 是用户自定义,不是 hardcoded 9 项 fallback**(开发者工具/调试日志确认)
2. ✅ **prompt 里 accounts 是当前账本同币种账户列表**(同上)
3. ✅ **多笔保存后,统计页(首页/账本页)余额刷新**
4. ✅ **多笔保存后,云同步触发**(查看 `LocalChanges` 表)
5. ✅ **AI 对话页:撤销单笔不影响其他笔;每张卡的撤销/编辑/换账本按钮独立**
6. ✅ **图片渠道:多笔时,附件只挂到第 1 笔**
7. ✅ **暗黑模式下卡片/通知文字可读**

### 9.4 性能回归(目测,不需要 benchmark)

- AI 对话单笔记账响应时间 ≤ 重构前(开发者工具看 prompt 调用耗时)
- 自动监听截图记账延迟 ≤ 重构前(`AutoBilling AI 识别完成 耗时=Xms` 日志)
- 多笔记账整体耗时 ≈ N × 单笔耗时(不应有 N² 级 query 放大)

### 9.5 静态检查清单

合并前必须通过:

```bash
flutter analyze              # 0 error, warning 数 ≤ 当前(893)
flutter test                 # 所有现有测试通过 + 新增测试通过
dart format --output=none --set-exit-if-changed lib/ai lib/services/ai lib/services/billing  # 格式不偏移
```

### 9.6 回归测试在 PR 描述里的记录格式

PR 描述中附一个 checklist,合入前**逐项打钩**:

```markdown
## 回归测试 (§9 矩阵)

### 单元测试
- [x] `test/ai/core/prompt_builder_test.dart` 通过
- [x] `test/ai/core/json_response_parser_test.dart` 通过
- [x] `test/ai/core/ai_extraction_context_test.dart` 通过
- [x] `test/ai/core/bill_info_test.dart` 通过
- [x] `test/services/ai/ai_bookkeeper_test.dart` 通过

### 手动冒烟(Android 真机)
- [x] AI 对话:单笔 / 多笔 / amount=0 / 网络失败 / 时间异常
- [x] 相册:单笔 / 多笔 / 猫图 / 关网 / 时间异常
- [x] 相机:单笔
- [x] 录音:单笔 / 多笔 / 静音 / 关网
- [x] 自动截图:单笔 / 非支付截图 / 关网
- [x] 自动通知:单笔 / 无金额 / 关网

### 不变量验证
- [x] prompt 注入用户自定义分类(非 hardcoded)
- [x] prompt 注入账本同币种账户
- [x] 统计刷新 / 云同步触发
- [x] 多笔卡片独立撤销 / 编辑 / 换账本
- [x] 图片附件挂在首笔
- [x] 暗黑模式 OK
```

---

## 10. 待用户决策的点

1. **目录命名**:`lib/bookkeeping/` vs `lib/services/bookkeeping/`?
   - 我倾向前者,跟 `lib/ai/` 平级,清晰
2. **`AiBookkeeper` 是否要拆成 3 个独立 service**(`TextBookkeeper / ImageBookkeeper / AudioBookkeeper`)?
   - 我倾向**不拆**,3 个方法共享相同的保存逻辑,拆开反而要重复
3. **`BillCreationService` 是否同步搬到 `lib/bookkeeping/`?**
   - 我倾向**不搬**,它服务手动记账等多个 caller,不仅 AI 用,放 `services/billing/` 更通用
4. **P5 目录搬家是否一定要做?**
   - 我倾向**做**,因为搬家前后导入路径都已经在 P1-P3 改过一遍了,P5 是机械操作收尾
5. **是否给 BillExtractionService 留 deprecated alias,让 1 个版本后再彻底删?**
   - 我倾向**不留**,直接 P5 物理删。理由:这是项目内部 API,无外部依赖
