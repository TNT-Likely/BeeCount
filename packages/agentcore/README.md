# agentcore

`agentcore` 是一个纯 Dart、本地优先的 Agent 运行时底座。它负责把模型回合、
原生 tool-call、工具执行、权限决策和本地记忆契约串起来，但不包含任何记账、
Flutter、数据库或云服务代码。

它适合放在宿主 App 的本地 Agent 之下：没有云端服务的用户仍然可以使用本地
模型、本地工具和本地存储；云同步只是宿主提供的可选适配器。

## 设计目标

- **本地优先**：运行时不依赖云端 Agent 服务或远程记忆服务。
- **协议无关**：核心只依赖抽象的 `AgentModel` 和 `AgentTool`；OpenAI-compatible
  transport 是一个可替换的协议适配器。
- **业务解耦**：工具名称、描述、参数 schema、数据库操作和本地化文案由宿主维护。
- **可控执行**：硬策略、用户权限、单工具限制、最大回合数和最大调用数共同防止
  Agent 失控或越权。
- **可观测**：模型回合、工具目录、工具调用、最终文本和异常均可通过日志 sink
  接入宿主的日志系统。

## 模块边界

```text
宿主 App
├─ 业务工具与 schema                 LocalAgentTools / ToolCatalog
├─ 业务安全策略与用户权限             AgentPolicy / PermissionStore adapter
├─ 本地记忆存储                       Drift / SQLite / 文件适配器
├─ 模型供应商、HTTP/SSE 和日志         Provider adapter
└─ 页面、授权弹窗和响应卡片
             │ 注入纯 Dart 接口
             ▼
agentcore
├─ AgentCore                          有限回合执行循环
├─ contracts.dart                     request / turn / tool / result 契约
├─ AgentPromptSuggestion              业务无关的推荐提问数据契约
├─ NativeToolAgentModel               模型回合与工具结果桥接
├─ OpenAiCompatibleNativeToolTransport 原生 tool-call + SSE 聚合
├─ AgentToolRegistry                  常驻工具 + 请求级工具搜索
├─ AgentModelCapabilityResolver       模型能力报告与缓存解析
├─ AgentTurnParser                    小型 JSON 回合解析器
├─ AgentAuthorizationPolicy           权限门禁组合器
├─ AgentMemoryRepository               本地记忆与审计接口
└─ AgentEvalRunner / AgentEvalReport    业务无关评测与报告
```

agentcore 不知道任何业务工具名。比如 `record_transaction_from_text` 只能存在于
BeeCount 宿主，不应移动到这个包中。

## 一次运行的数据流

```text
AgentRequest
    │
    ▼
AgentModel.nextTurn()
    │
    ├─ AgentFinalTextTurn ────────────────► AgentRunResult.text
    │
    └─ AgentToolCallsTurn
          │
          ├─ AgentPolicy.decide()
          │     ├─ deny ─────────────────► deniedCalls + error tool result
          │     └─ allow
          │
          ├─ AgentTool.execute()
          │                                  executedCalls + tool result
          └─────────────── 回填 AgentRequest.toolData，进入下一模型回合
```

`AgentCore.run()` 在开始时校验工具注册表，然后最多执行
`maximumModelTurns` 个规划回合和 `maximumToolCalls` 个工具调用。规划或调用预算
耗尽后，core 会额外保留一次**仅生成最终文本的收口回合**：该回合的
`AgentRequest.allowToolCalls` 为 `false`，原生 transport 会发送空的 `tools` 数组并显式
使用 `tool_choice: none`，因此模型只能基于已经回填的工具结果作答，不能再次消耗本地
工具调用。收口回合仍受
取消和超时控制；如果自定义模型违反契约继续返回工具调用，运行会以
`AgentRunTerminationReason.modelTurnLimitReached` 或
`AgentRunTerminationReason.toolCallLimitReached` 结束。

## 核心契约

### 自动上下文压缩

`AgentConversationContextCompressor` 在纯 Dart 中清洗历史、按字符和条数预算自动压缩，
保留最近原文。默认超过 16 条或 16000 字符触发，压缩后保留最近 8 条（大段文本还受
12000 字符预算限制），摘要最多 4000 字符。字符预算是保守估算，不是模型精确 token 数。

宿主注入独立的纯文本 `AgentHistorySummarizer` 与 `AgentConversationSummaryStore`；
包不认识模型服务商、账本或数据库。摘要缓存按 conversationId 和 scopeId 隔离，用
SHA-256 验证旧历史前缀，修改/删除后不复用。尾部仍在预算内时不请求摘要模型；再超限
才增量压缩。摘要超时（默认 8 秒）、空结果或失败退回有界原文摘录，不阻断主回答；
取消时立即结束等待且不保存晚到结果。短对话不调用摘要模型。

摘要属于不可信历史上下文，不是显式长期记忆、金额事实或当前用户授权。宿主必须在
系统提示中声明这些边界，金额现状仍通过业务工具重新查询。压缩不修改或删除聊天记录。
历史可提供可选 `id` 与 `scopeId`；显式其他 scope 的消息被排除，旧无 scope 数据仍作为
不可信上下文兼容读取。宿主清空/修改/删除对话时应同步清除派生缓存。

### 推荐提问

`AgentPromptSuggestion` 只包含稳定的 `id`、展示用 `title` 和完整的 `prompt`。
宿主负责本地化和 UI；点击后应原样提交、保存 `prompt`，走正常 Agent 流程。
它不预读数据、不指定工具、不绕过权限，也不引入另一条模型调用路径。

`AgentPromptSuggestionSelector` 从宿主按优先级排列的候选项中去重、排除当前和
近期已提问题，并限制数量（默认 3 个）；禁用时返回空列表。选择过程不调用模型。
`AgentSuggestionEvidence` 承载宿主观察到的成功工具结果，业务规则不能从模型
正文推测工具执行成功。推荐项支持 JSON 编解码，持久化格式和账本/租户隔离由宿主管理。

只读入口可使用 `AgentScope.allowsMutations = false` 表达可信宿主限制。
宿主硬策略必须对此拒绝写工具；不能靠推荐文案或模型承诺保证只读。

### 请求、工具和结果

```dart
final request = AgentRequest(
  text: '查询本月支出',
  scope: const AgentScope(id: 'run-1', ledgerId: 1),
  context: {'currentTime': DateTime.now().toIso8601String()},
);

final cancellation = AgentCancellationToken();

final core = AgentCore(
  model: model,
  tools: {'read_report': readReportTool},
  policy: policy,
  maximumModelTurns: 4,
  maximumToolCalls: 4,
  // 可选：对同一运行中完全相同的只读调用复用结果，避免模型重复查询。
  deduplicatedToolNames: {'read_report'},
  // 可选：宿主的语义校验（不替代权限校验）；无效调用不会执行。
  validateToolCall: validateReadInput,
  maximumToolValidationRetries: 1,
  cancellationToken: cancellation,
);

final result = await core.run(request);
```

`validateToolCall` 在权限放行后、执行或复用缓存前调用。宿主返回
`AgentToolValidationIssue(code: ..., message: ...)` 时，core 为原始 call ID
回填 `error/message/retryable`，记入 `rejectedCalls`，而不是权限 `deniedCalls`。
无效输入不执行、不缓存、不消耗本地动作额度。默认只有一次纠正机会，且不增加
`maximumModelTurns`；再次无效时进入仅文本收口。权限拒绝、单次写入限制和取消
不会因为语义纠正而绕过。宿主仍须检查所需结果是否真正取得，不能把错误反馈
当成空数据或仅凭模型声称“已修复”就放行答案。

`AgentTool.name` 必须和注册表 key 完全一致。工具执行结果是
`Map<String, Object?>`，会被宿主序列化后作为下一轮的 `role: tool` 内容。

工具调用恰好耗尽 `maximumToolCalls` 时，core 仍会给模型一个收口回合来生成最终
文本；这样“查询 → 返回结果”不会被误判为步骤过多。
如果单个原生工具调用批次超过剩余预算，core 会为每个未执行调用回填
`{"error":"tool_call_limit_reached"}`，同时记录为拒绝调用；宿主因此仍能向
OpenAI-compatible 服务回填完整批次的 tool result，而不会触发缺失结果的协议错误。

对需要避免重复读取的工具，可通过 `deduplicatedToolNames` 显式开启调用级去重。core
会按工具名称和规范化后的 JSON 参数生成指纹；命中后复用本次运行中第一次成功执行的
结果，不会再次执行工具，也不会增加工具调用计数。该配置默认关闭，以便保留轮询型工具
对同一参数重复读取变化状态的能力；写工具应使用 `singleUseToolNames` 或宿主权限策略
控制，而不是依赖读取缓存。

### 取消运行

前台宿主可持有一个 `AgentCancellationToken`，并在用户选择停止后调用 `cancel()`：

```dart
final pending = core.run(request);

// 用户点击“停止”时：立刻结束等待中的模型/授权回合。
cancellation.cancel();
final result = await pending;
assert(result.wasCancelled);
```

取消会与等待中的模型或策略决策竞争，避免继续等待网络；它**不会**强行中断已经开始
的工具写入。core 会在每个下一操作前检查 token，使宿主可以保持本地事务一致性。

有状态模型可以实现 `AgentRunFinalizer`。core 会在完成、超限、异常或取消的 `finally`
路径调用 `disposeRun(scope.id)`，释放该次运行的会话资源。原生 transport 还可实现
`AgentNativeToolRunFinalizer`：`OpenAiCompatibleNativeToolTransport` 会取消仍在监听的
SSE 订阅，并以 `AgentNativeToolRunCancelledException` 结束这次底层请求。

### 原生工具描述

给模型的工具定义由宿主注入 `AgentNativeToolDefinition`。每个工具必须包含名称、
自然语言说明和 JSON Schema 参数：

```dart
const definitions = [
  AgentNativeToolDefinition(
    name: 'read_report',
    description: '读取当前账本报告，只读，不会修改数据。',
    parameters: {
      'type': 'object',
      'properties': {
        'start': {
          'type': 'string',
          'description': '查询开始时间，ISO 8601 格式。',
        },
      },
      'required': ['start'],
      'additionalProperties': false,
    },
  ),
];
```

`toOpenAiSchema()` 会生成 OpenAI-compatible 的请求结构：

```json
{
  "type": "function",
  "function": {
    "name": "read_report",
    "description": "读取当前账本报告，只读，不会修改数据。",
    "parameters": {
      "type": "object",
      "properties": { "start": { "type": "string" } },
      "required": ["start"],
      "additionalProperties": false
    }
  }
}
```

推荐宿主把业务工具的执行器和 schema 放在同一个业务目录中，再将 schema 列表
注入 transport。agentcore 只负责传输和聚合，不替宿主推断业务参数。

在 BeeCount 中，这份业务目录位于
`lib/agent/tools/local_agent_tool_catalog.dart`；执行器位于同目录的
`local_agent_tools.dart`。修改工具时应同时更新这两处及对应 schema 测试。

### 常驻工具与请求级工具搜索

工具较多时，可用 `AgentToolRegistry` 把少量高频工具标记为 `isResident`，其余工具
通过宿主提供的 `selectionTerms` 按当前请求选择。注册项同时绑定 schema、执行器、
单次调用和去重元数据，避免业务层维护多份容易漂移的列表：

```dart
final registry = AgentToolRegistry([
  AgentToolDescriptor(
    definition: readOverviewDefinition,
    tool: readOverviewTool,
    isResident: true,
    selectionTerms: const ['概览', '总额'],
    requiresExecutionOnMatch: true,
  ),
  AgentToolDescriptor(
    definition: readBudgetDefinition,
    tool: readBudgetTool,
    selectionTerms: const ['预算', 'budget'],
  ),
]);

final selected = registry.select(
  '$userText\n$recentContext',
  requirementQuery: userText,
  maximumTools: 7,
);
```

将 `selected.names` 写入 `AgentRequest.availableToolNames` 后，原生 transport 只发送
本次可见的 schema。`requiredToolNames` 只是一个通用的落地校验信号：是否拒绝模型
“没有调用工具却直接回答数据”的文本，仍由宿主产品策略决定。
`requirementQuery` 可限制强制执行信号只来自当前消息，避免历史对话中的“记账”等词
误授权或误要求当前回合再次执行写工具。

### 模型能力报告

`AgentModelCapabilities` 分别记录文本、原生工具调用、流式输出和强制工具选择能力，
每项都使用 `supported / unsupported / unknown` 三态，避免把网络错误误判为模型不兼容。
宿主实现 `AgentModelCapabilityStore` 后，可用 `AgentModelCapabilityResolver` 按
服务商、地址和模型组成的指纹缓存探测结果。探测请求和具体 HTTP 协议属于宿主；缓存
中不应包含 API Key 或用户数据。

## OpenAI-compatible tool-call / SSE

`OpenAiCompatibleNativeToolTransport` 接收宿主注入的 `AgentNativeToolStream`：

```dart
final transport = OpenAiCompatibleNativeToolTransport(
  systemPrompt: systemPrompt,
  toolDefinitions: definitions,
  toolStream: provider.chatWithToolsStream,
  logSink: (event, data) => logger(event, data),
);
```

transport 为每个 `runId` 保留一份短生命周期消息状态：

1. 首轮发送 `system` 和 `user` 消息，以及完整 `tools` 数组；
2. 聚合 SSE 中分片的文本和 `delta.tool_calls`；
3. 返回 `AgentNativeFinalTextResponse` 或 `AgentNativeToolCallsResponse`；
4. 宿主执行工具后，把 `AgentNativeToolResult` 传回下一轮；
5. 得到最终文本或发生异常时清理该 `runId` 的状态。

文本增量通过 `AgentNativeEventSink` 立即通知宿主，适合直接渲染真实 SSE 流。工具
参数分片会在 transport 内部聚合完成后才交给 `AgentCore`，避免业务层处理半截 JSON。
收口回合会关闭文本增量，避免供应商把内部 DSML/XML 标记闪现到界面；若网关仍返回
工具标记，transport 会带更强约束重试一次，第二次仍不合规则返回空文本，由宿主使用
自己的安全完成提示。

不支持原生工具调用、流式响应格式错误和回合超时分别对应
`AgentNativeToolUnsupportedException`、`AgentNativeProtocolException` 和
`AgentNativeToolTimeoutException`；运行主动释放时则为
`AgentNativeToolRunCancelledException`。宿主应向用户提示配置或重试建议，不应静默
退回旧的 prompt 协议。

## 权限门禁

agentcore 提供通用的权限模型，但不保存权限数据，也不负责页面：

- `AgentToolPermissionCatalog`：宿主声明工具及默认权限；
- `AgentToolPermissionStore`：宿主实现本地持久化；
- `AgentToolAuthorizationRequester`：宿主显示授权 UI；
- `AgentAuthorizationPolicy`：先执行宿主硬策略，再检查 `alwaysAllow` 或请求一次性
  授权。

授权选择有三种：`deny`、`allowOnce`、`alwaysAllow`。`alwaysAllow` 的落盘失败不会
  撤销本次已经批准的调用，但会通过宿主提供的 `onPersistenceError` 暴露。

未知工具、硬策略拒绝、用户拒绝和授权超时都会进入 `AgentRunResult.deniedCalls`，
并向模型回填结构化错误，便于模型结束当前回合。宿主可以通过
`AgentRunResult.terminationReason` 区分正常完成、工具调用上限、模型回合上限和取消，
但只要 `text` 非空，通常应优先展示模型的最终答复。

## 本地记忆与审计

`AgentMemoryRepository` 只定义接口，宿主可以使用 Drift、SQLite、文件或其他本地
存储实现：

- 显式记忆保存、查询、删除和清空；
- 当前 scope 的活跃记忆列表；
- 运行摘要保存；
- Agent run 的开始/结束状态与最近运行列表；
- 每次工具调用的审计、计数和按 run 查询。

记忆检索、加密、去重、过期清理和云同步不属于 agentcore。实现时应按账本或用户
scope 隔离数据，并限制传入模型的条数和长度。

## 日志事件

传入 `logSink` 后，transport 会发出以下事件：

| 事件 | 主要字段 | 用途 |
| --- | --- | --- |
| `turnStarted` | `runId`、`toolResultCount`、`allowToolCalls`、`toolDefinitions` | 查看本轮是否允许工具，以及发送的工具目录和已有结果 |
| `toolCalls` | `runId`、调用 id、工具名、参数 | 查看模型请求了哪个工具 |
| `finalText` | `runId`、文本长度、文本 | 查看模型最终返回 |
| `turnFinished` | `runId`、响应类型 | 标记回合完成 |
| `turnFailed` | `runId`、错误 | 定位协议、网络或超时错误 |

宿主应根据隐私策略决定是否记录完整用户消息和工具结果；工具 schema 本身通常可
安全记录，用户数据则应脱敏或截断。

## 宿主接入清单

1. 实现 `AgentModel`，或使用 `NativeToolAgentModel` + 自己的 prompt builder。
2. 在业务层定义工具执行器、描述和完整 JSON Schema。
3. 实现 `AgentPolicy`，组合硬安全规则和 `AgentAuthorizationPolicy`。
4. 注入本地 `AgentMemoryRepository`、权限 store、SSE stream 和日志 sink。
5. 为 scope、工具调用上限、超时、取消和错误提示设置产品策略。
6. 为每个工具补 schema/执行器一致性测试，并覆盖授权和存储适配器。

## 测试

agentcore 可以脱离 Flutter 和业务数据库运行：

```bash
cd packages/agentcore
dart test
```

宿主 App 还应至少验证：

1. 发给 provider 的 `tools` payload 同时包含 name、description 和 parameters；
2. SSE 文本增量和分片 tool-call 参数可以正确聚合；
3. 未知工具、硬策略拒绝、用户拒绝和超时不会执行本地写操作；
4. 本地记忆和工具审计按 scope 隔离，重复调用不会产生重复数据；
5. provider 不支持 tool-call/SSE 时给出明确配置提示。

## 通用评测

`AgentEvalCase` 的 `input` / `expected` schema 由宿主决定；包不认识账本、工具名称或模型供应商。宿主注入执行器和检查器：

```dart
final report = await AgentEvalRunner(
  execute: (testCase) async => AgentEvalObservation(
    data: {'value': await myExecutor(testCase.input)},
    metrics: {'requests': 1},
  ),
  evaluate: (testCase, observed) => [
    AgentEvalCheck(
      name: 'result',
      passed: agentEvalMismatches(
        testCase.expected, observed.data, numericTolerance: 1e-9,
      ).isEmpty,
    ),
  ],
).run(cases: myCases, metadata: {'fixtureVersion': 'v1'});
final json = report.toJson();
final markdown = report.toMarkdown();
```

Runner 顺序执行、逐例捕获异常并继续、拒绝空集合和重复 ID；空断言视为失败。报告含逐例检查、tag 汇总、耗时分位数及宿主 metrics 合计。对象断言采用子集匹配，数组严格检查顺序和长度，缺失字段不等于 null；数值仅接受有限值及显式非负容差。

为避免异常对象中的凭证泄露，通用 runner 只记录异常类型。宿主负责超时、取消、隔离数据库、脱敏及提供安全诊断；报告会保留宿主主动提供的 observation/metadata，不自动脱敏。离线 oracle 测试不能解释为模型理解能力测试。BeeCount 接入示例和运行命令见 `test/ai_eval/README.md`。

## 版本与兼容性

这是一个内部纯 Dart 包。新增契约应优先保持向后兼容；变更
`AgentTool`、`AgentModel`、transport 构造参数或记忆/权限接口时，需要同步更新
宿主适配器和 package boundary 测试。业务工具名称和 schema 属于宿主 API，不应被
agentcore 直接依赖。
