# agentcore

`agentcore` 是一个纯 Dart、本地优先的 Agent 运行时底座。它只负责通用
契约、有限回合编排、原生工具调用协议、SSE 片段聚合、权限门禁和记忆接口，
不依赖 Flutter、Drift、网络客户端或任何具体业务。

## 边界

包内保留：

- `AgentCore`：在模型回合、工具执行和策略决策之间编排有限状态机；
- `AgentRequest`、`AgentTurn`、`AgentTool`、`AgentPolicy` 等纯 Dart 契约；
- `AgentTurnParser`：可注入工具白名单的 JSON 解析器；
- `NativeToolAgentModel` 与 `OpenAiCompatibleNativeToolTransport`：原生
  tool-call/SSE 的通用协议实现，支持流式文本增量和工具参数分片；
- `AgentToolPermissionCatalog`、授权 broker、授权策略和本地记忆接口。

包外（宿主 App）负责：

- 业务工具实现、工具 schema、业务安全策略和本地化文案；
- HTTP/SSE 客户端、模型供应商配置、日志系统；
- Drift/SharedPreferences 等本地存储适配器；
- 页面、授权弹窗和业务响应卡片。

因此没有配置云服务的用户仍可只使用宿主 App 注入的本地工具和存储；云端
同步是可选适配器，不是运行时前置条件。

## 最小接入

```dart
final catalog = AgentToolPermissionCatalog(
  descriptors: const [
    AgentToolPermissionDescriptor(
      toolName: 'read_report',
      defaultPermission: AgentToolPermission.alwaysAllow,
      mutatesLocalData: false,
    ),
  ],
);

final core = AgentCore(
  model: model,
  tools: {'read_report': readTool},
  policy: policy,
  singleUseToolNames: const {'write_report'},
);
```

原生模型需要宿主注入 `promptBuilder`、`toolDefinitions`、实际 SSE stream
和错误分类器。`OpenAiCompatibleNativeToolTransport` 会维护一个 run 的
assistant tool-call 消息，并把每个 `role: tool` 结果追加到同一会话；最终
文本或工具调用后会清理该 run 的状态。

## 安全和可观测性

- 工具是否允许由宿主的硬策略和用户权限策略共同决定；
- 单次运行的最大工具调用数、模型回合数可配置，避免失控循环；
- 单次工具约束通过 `singleUseToolNames` 注入，不包含具体业务名称；
- SSE transport 只聚合协议数据，宿主可通过 `AgentNativeLogSink` 接入日志；
- 记忆接口只定义本地数据契约，宿主决定加密、索引、清理和同步策略。

## 测试

包本身可以在不加载 Flutter 或业务数据库的情况下测试。宿主应额外覆盖：

1. 工具 schema 与业务实现的一致性；
2. 硬策略、用户授权和取消流程的组合；
3. 本地存储适配器的隔离、去重和迁移。
