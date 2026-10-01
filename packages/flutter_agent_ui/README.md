# flutter_agent_ui

可复用的 Flutter Agent 对话 UI。只依赖 Flutter 和纯 Dart `agentcore`，不依赖 BeeCount、Riverpod、数据库、账本模型或本地化生成器。

- `AgentAnswerView`：无头像侧栏、无固定留白的通栏回答；宿主提供 Markdown、卡片和操作。
- `AgentActivityView` / `AgentActivityStep`：默认折叠的真实执行状态与安全展示模型；宿主提供本地化状态、工具标题和白名单摘要。正文应放在组件外，收起详情不会隐藏正文。
- `AgentFollowUpSection`：主题色浅底、标题细标记和行间分隔，默认两条上下文问题；模板和追问共同参与本地轮换。点击通过回调返回完整 `AgentPromptSuggestion`，换一组不请求模型。
- `AgentScrollToLatestButton`：可定位到输入框上方的悬浮回到底部操作；显示条件与滚动控制由宿主负责。
- `AgentConversationScrollCoordinator`：等待消息布局后定位、首屏延迟重试；宿主在手动滚动开始时调用 `onUserScroll()`，以取消自动定位。

颜色和字号继承 Flutter `Theme` / `MediaQuery`。窄屏或大字号时标题栏自动换行；交互目标至少 44px。

宿主可开启 `AgentActivityView.expandWhileActive`：执行中自动展开，即使本地工具很快完成，等待模型或生成正文时也继续显示明细；状态变为 `completed` / `failed` 后自动收起。用户手动展开/折叠优先，不随模型状态变化强制打开。新一轮运行应使用独立的 widget key，避免继承上一轮的手动选择。

`awaitingModel`、`thinking` 和 `generating` 分别表示等待模型、收到真实思考信号和生成回答；`waiting` 用于等待用户授权，不显示忙碌转圈。宿主应根据真实事件映射状态，不用计时器虚构思考步骤，也不向组件传入模型推理原文。

`AgentFollowUpStyle` 可注入宿主的背景、主题色、正文、次级文字与分隔线颜色。默认从 `ColorScheme.primary` 和 `surface` 合成浅底（亮色 8%、暗色 15%），不依赖未被宿主覆盖的 Material 默认容器色。宿主修改主题时会实时重绘，轮换进度不会重置。

宿主必须在构造展示模型之前筛选敏感数据。不要向 `details` 传入原始参数、任意 JSON、交易备注、提示词或异常栈。`tryFromJson` 提供长度与形状校验，不承担业务脱敏。

```dart
AgentAnswerView(
  activity: AgentActivityView(
    summary: localizedExecutionSummary,
    status: AgentActivityStatus.completed,
    steps: safeLocalizedSteps,
  ),
  content: markdownAnswer,
  actions: answerActions,
)
```

验证：在此目录运行 `flutter pub get`、`flutter analyze --no-pub`、`flutter test --no-pub`。
