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
├─ NativeToolAgentModel               模型回合与工具结果桥接
├─ OpenAiCompatibleNativeToolTransport 原生 tool-call + SSE 聚合
├─ AgentTurnParser                    小型 JSON 回合解析器
├─ AgentAuthorizationPolicy           权限门禁组合器
└─ AgentMemoryRepository               本地记忆与审计接口
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
`maximumModelTurns` 个模型回合和 `maximumToolCalls` 个工具调用。达到上限时返回
空文本和已有的调用审计，宿主应将其转换成可理解的“需要简化操作”提示。

## 核心契约

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
  cancellationToken: cancellation,
);

final result = await core.run(request);
```

`AgentTool.name` 必须和注册表 key 完全一致。工具执行结果是
`Map<String, Object?>`，会被宿主序列化后作为下一轮的 `role: tool` 内容。

工具调用恰好耗尽 `maximumToolCalls` 时，core 仍会给模型一个剩余回合来生成最终
文本；只有模型再次请求工具时才会停止。这样“查询 → 返回结果”不会被误判为步骤过多。
如果单个原生工具调用批次超过剩余预算，core 会为每个未执行调用回填
`{"error":"tool_call_limit_reached"}`，同时记录为拒绝调用；宿主因此仍能向
OpenAI-compatible 服务回填完整批次的 tool result，而不会触发缺失结果的协议错误。

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
并向模型回填结构化错误，便于模型结束当前回合。

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
| `turnStarted` | `runId`、`toolResultCount`、`toolDefinitions` | 查看本轮发送的工具目录和已有结果 |
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
flutter test
```

宿主 App 还应至少验证：

1. 发给 provider 的 `tools` payload 同时包含 name、description 和 parameters；
2. SSE 文本增量和分片 tool-call 参数可以正确聚合；
3. 未知工具、硬策略拒绝、用户拒绝和超时不会执行本地写操作；
4. 本地记忆和工具审计按 scope 隔离，重复调用不会产生重复数据；
5. provider 不支持 tool-call/SSE 时给出明确配置提示。

## 版本与兼容性

这是一个内部纯 Dart 包。新增契约应优先保持向后兼容；变更
`AgentTool`、`AgentModel`、transport 构造参数或记忆/权限接口时，需要同步更新
宿主适配器和 package boundary 测试。业务工具名称和 schema 属于宿主 API，不应被
agentcore 直接依赖。
