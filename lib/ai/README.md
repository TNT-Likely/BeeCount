# AI 多模态记账 · 代码导览

> 单一入口:`AiBookkeeper.fromText / fromImage / fromAudio`
> 单一数据模型:`BillInfo`
> 三层架构:**渠道入口** → **应用层** → **底座**

5 个调用渠道(对话/相册/相机/语音/自动截图/自动通知文本)共享同一套流水线。
本文档帮你**3 分钟搞清楚一段代码应该改哪个文件**。

---

## 1. 三层架构

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 3 · Channel Entry                                              │
│                                                                      │
│  ai_chat_page          利用 ai_chat_service ─┐                       │
│  image_billing_helper                        │                       │
│  voice_billing_helper                        │  调用                  │
│  auto_billing_service                        ▼                       │
└────────────────────────────────────────────┬─────────────────────────┘
                                             │
┌────────────────────────────────────────────▼─────────────────────────┐
│ Layer 2 · AiBookkeeper (services/ai/ai_bookkeeper.dart)              │
│                                                                      │
│  fromText / fromImage / fromAudio                                    │
│   ↓ 1. AiExtractionContext.forLedger     (查分类 + 账户 + 自定义模板)   │
│   ↓ 2. AiExtractionEngine.extractFromX   (拿到 List<BillInfo>)        │
│   ↓ 3. BillCreationService.createFromBill(每笔落库 + 匹配分类账户标签)  │
│   ↓ 4. 聚合返回 BookkeepingResult        (savedBills/txIds/failedCount)│
└────────────────────────────────────────────┬─────────────────────────┘
                                             │ 调用
┌────────────────────────────────────────────▼─────────────────────────┐
│ Layer 1 · AI 底座(ai/core/)无业务依赖                                 │
│                                                                      │
│  AiExtractionEngine.extractFromText/Image/Audio                      │
│   ↓ PromptBuilder.build       (拼装 prompt,注入分类/账户/时间)         │
│   ↓ AIProviderFactory.chat/vision/speechToText  (调服务商 API)        │
│   ↓ JsonResponseParser.parse  (JSON5 容错,sanitize 兜底)              │
│   ↓ List<BillInfo>            (amount 已校验,time 已兜底)             │
└──────────────────────────────────────────────────────────────────────┘
```

**强制依赖方向(单向)**:L3 → L2 → L1,绝不反向。
**L1 / L2 之间通过纯数据 `AiExtractionContext` + `BillInfo` 通信,无 Riverpod / Repository 反向耦合**。

---

## 2. 文件清单

### Layer 1 · 底座(`lib/ai/`)

| 文件 | 职责 | 何时改 |
|---|---|---|
| `core/bill_info.dart` | `BillInfo` + `BillType` 数据模型 | 加字段、调 JSON 兼容性 |
| `core/ai_extraction_context.dart` | 上下文 DTO + `forLedger` 工厂 | 改要传给 AI 的用户上下文 |
| `core/prompt_builder.dart` | Prompt 拼装(默认模板 + 占位符替换) | 调 prompt 文本 |
| `core/json_response_parser.dart` | JSON 解析、JSON5 容错、`_sanitize` 校验 | AI 偶发返回新的奇怪格式 |
| `core/ai_extraction_engine.dart` | 抽象 + `DefaultAiExtractionEngine` | 加新模态(如视频)或换服务商集成方式 |
| `providers/ai_provider_factory.dart` | 服务商 SDK 工厂(chat/vision/speech) | 加新服务商、调超时 |
| `providers/ai_provider_manager.dart` | Provider 配置存取(SharedPrefs) | 改配置存储格式 |
| `providers/ai_provider_config.dart` | 服务商配置 model | 加新配置字段 |
| `providers/ai_constants.dart` | SharedPrefs key 常量 | 加新本地存储 key |

### Layer 2 · 应用层(`lib/services/ai/`)

| 文件 | 职责 | 何时改 |
|---|---|---|
| `ai_bookkeeper.dart` | **唯一对外入口**,5 个渠道都调它 | 加新渠道、调整落库前后处理 |
| `bookkeeping_result.dart` | 统一结果模型 | 加汇总字段(如总金额) |
| `ai_chat_service.dart` | 对话编排(意图判定 + 自由对话) | 调对话意图判断、自由对话 prompt |
| `ai_quick_command_service.dart` | 快捷指令模板 | 加新快捷指令 |

### Layer 2 · 落库(`lib/services/billing/`)

| 文件 | 职责 | 何时改 |
|---|---|---|
| `bill_creation_service.dart` | `BillInfo` → `transactions` 表 + 分类账户标签匹配 | 改匹配逻辑、改类型推断 |
| `category_matcher.dart` | 关键词字典 → 分类 ID | 调字典 |
| `post_processor.dart` | 落库后刷统计 + 触发同步 | 改后处理时机 |

### Layer 3 · 渠道入口

| 文件 | 渠道 | 何时改 |
|---|---|---|
| `lib/pages/ai/ai_chat_page.dart` | AI 对话 UI + 多笔卡片 | 改对话页 UI / 卡片交互 |
| `lib/services/ai/ai_chat_service.dart` | 对话编排 | 已在 Layer 2(同时担两职) |
| `lib/utils/image_billing_helper.dart` | 相册/相机 | 改图片记账流程 / toast 文案 |
| `lib/utils/voice_billing_helper.dart` | 录音 | 改录音 UI / 静音检测 |
| `lib/services/automation/auto_billing_service.dart` | 后台监听(截图 + 通知文本) | 改文件等待 / 通知格式 |

---

## 3. 五个渠道时序

### 3.1 AI 对话(文本)

```
User 输入 → ai_chat_page._sendMessageText
              ↓
            chatService.processMessage  (意图判定)
              ↓ 是记账意图
            chatService._handleTransaction
              ↓
            bookkeeper.fromText(text, ledgerId, billingTypes=['ai'])
              ↓
            (Layer 2 三步:context → engine.extractFromText → 逐笔 createFromBill)
              ↓
            AIResponse.billCards(bills, txIds)
              ↓
            ai_chat_page 把多笔渲染成 N 张 BillCardWidget
```

### 3.2 相册/相机

```
User 选图 → image_billing_helper.pickImageForBilling
              ↓ AI vision 配置检查 + 取当前账本
            bookkeeper.fromImage(image, ledgerId, billingTypes=['image','ai'],
                                 onSaved: attachmentService.saveAttachment)
              ↓
            (Layer 2 三步;onSaved 每笔回调挂图片附件)
              ↓
            PostProcessor.run + toast 「成功 × N」
```

### 3.3 录音

```
User 长按麦克风 → voice_billing_helper 录音 + 静音检测
              ↓ 停止录音
            bookkeeper.fromAudio(audio, ledgerId, billingTypes=['voice','ai'])
              ↓ (内部先 STT → 文本再走 fromText 流水线)
            返回 ({result, recognizedText})
              ↓
            UI 立即显示 recognizedText 给用户看
              ↓ + PostProcessor.run + toast
```

### 3.4 自动截图(后台监听)

```
ScreenshotMonitorService 检测到新截图
              ↓
            auto_billing_service.processScreenshot
              ↓ 文件就绪 + 防重复 + AI vision 配置检查
            bookkeeper.fromImage(...)  ← 同 3.2
              ↓
            通知中心展示「✅ 自动记账成功」
```

### 3.5 自动通知文本(快捷指令)

```
iOS 快捷指令 / Android 通知监听 → text payload
              ↓
            auto_billing_service.processText
              ↓ AI text 配置检查
            bookkeeper.fromText(...)  ← 同 3.1
              ↓
            通知中心展示
```

---

## 4. 「我想改 X,应该改哪个文件」

| 我想改… | 改这个文件 |
|---|---|
| AI prompt 模板 | `lib/ai/core/prompt_builder.dart` `defaultTemplate` |
| Prompt 占位符(如新增 `{{LEDGER_NAME}}`) | `prompt_builder.dart` + `ai_extraction_context.dart` |
| AI 返回的 JSON 解析容错(新格式异常) | `lib/ai/core/json_response_parser.dart` |
| amount/time 校验规则 | `json_response_parser.dart` `_sanitize` |
| BillInfo 字段(新增 currency 等) | `lib/ai/core/bill_info.dart` |
| AI 服务商接入 | `lib/ai/providers/ai_provider_factory.dart` |
| AI 请求超时 | `ai_provider_factory.dart` `_getDio` |
| 分类匹配算法 | `lib/services/billing/category_matcher.dart` + `bill_creation_service.dart` `_matchCategory` |
| 账户匹配算法 | `bill_creation_service.dart` `_matchAccountByName` |
| 落库后的标签自动挂上 | `bill_creation_service.dart` `_addTags` |
| 对话意图判定 | `ai_chat_service.dart` `_isTransactionIntent` |
| 多笔卡片 UI | `ai_chat_page.dart` `_buildMultiBillBubble` |
| 单笔卡片 UI | `lib/widgets/ai/bill_card_widget.dart` |
| 撤销/编辑/换账本 | `ai_chat_page.dart` `_handleUndoOne / _handleEdit / _handleChangeLedger` |
| 图片附件挂法(全笔/首笔) | `image_billing_helper.dart` 的 `onSaved` 回调 |
| 后台监听通知文案 | `auto_billing_service.dart` `_successTitle / _successBody` |

---

## 5. 关键决策

### 5.1 为什么 `AiExtractionEngine` 接受 `AiExtractionContext` 而不是 `Repository`?

底座要可以**独立单测、独立 package**,不该依赖 Drift / Riverpod / SharedPrefs。
`AiExtractionContext.forLedger(repo, ledgerId)` 是 Layer 2 把所有上下文一次性查好,
塞成 value object 喂给 Layer 1。

### 5.2 为什么 5 个渠道不直接调 `BillExtractionService`,要走 `AiBookkeeper`?

直接调底座只能拿到 `List<BillInfo>`,还要自己:
- 逐笔调 `BillCreationService.createFromBill`
- 处理单笔失败不影响其他笔
- 回填实际入库的分类/账户名(给 UI 卡片显示)
- 聚合统计(成功 N 笔、合计金额)

这些样板代码以前每个渠道都写一遍,改一处漏一处。
现在 `AiBookkeeper._persistAll` 一处实现,5 渠道复用。

### 5.3 为什么 `JsonResponseParser._sanitize` 把 time 缺失兜底成 `DateTime.now()`?

AI 偶发吐出不可解析的时间(`"2222 - 2 2 - 2T18:08:00"`)。如果丢弃这笔,
用户明明输入了「买菜30」却被告知失败,体感差。
amount 是硬要求(没有就丢);time 软兜底,记到当前时间。

### 5.4 为什么 `BillCreationService.createBillTransaction(OcrResult)` 被删了?

`OcrResult` 是 OCR 时代的遗留模型,字段与 `BillInfo` 大量重复。
重构后所有 AI 渠道都走 `BillInfo`,`OcrResult` 没有 caller。
保留唯一公开 API `createFromBill(BillInfo)`。

### 5.5 图片附件为什么多笔时每笔都挂?

之前设计是「只挂首笔」省存储。但用户期望从任意一笔都能溯源到原图(查账单时
不需要"先找姐妹笔"),改成每笔都挂。代价是几百 KB × N 的复制,可接受。

---

## 6. 测试

| 测试文件 | 覆盖 |
|---|---|
| `test/ai/core/prompt_builder_test.dart` | Prompt 占位符替换 / 自定义模板 / fallback |
| `test/ai/core/json_response_parser_test.dart` | 数组/单对象/Markdown/Trailing comma/sanitize |
| `test/ai/core/bill_info_test.dart` | fromJson 字段兼容 / copyWith / 时间 strip |
| `test/ai/core/ai_extraction_context_test.dart` | forLedger 真 DB 集成 / 币种过滤 |
| `test/services/ai/ai_bookkeeper_test.dart` | 单笔 / 多笔 / 失败 / ledgerId 注入 / recognizedText |

跑全部:`flutter test test/ai/ test/services/ai/`

---

## 7. 常见调试技巧

### 7.1 看 AI 实际收到的 prompt

`logger.debug('AiExtraction', '完整 prompt:\n$prompt')` — 调试模式下控制台可见。
搜「`AiExtraction`」标签。

### 7.2 看 AI 原始响应

`logger.debug('JsonResponseParser', '原始响应: $response')` — 同上。
搜「`JsonResponseParser`」标签。

### 7.3 看落库时实际匹配到的分类/账户

`logger.info('BillCreation', '[自动记账] 成功 | ID:X | ...')` 会列出完整字段。

### 7.4 reasoning 模型(DeepSeek-R1 / o1)超时

`receiveTimeout` 默认 60s。reasoning 模型推理常 60-180s,会断流。
解决:换非 reasoning 模型(GLM-4-Flash / DeepSeek-V3 / Qwen-Turbo),
对结构化抽取任务准确率不输 R1,且 1-3 秒出结果。

