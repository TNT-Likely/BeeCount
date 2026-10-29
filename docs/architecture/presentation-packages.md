# 展示层与组件职责

页面与应用适配代码按业务域放在 `lib/pages`；纯展示分成 `beecount_ui`、`beecount_business_ui`。组件验收入口在 `lib/dev/component_gallery`。不再增加 `lib/widgets` 或 `lib/presentation/v4` 兼容桶目录。

## 依赖方向

`pages → beecount_business_ui → beecount_ui → Flutter`。App 的 Repository、Riverpod、Drift、HTTP、文件与平台服务不能被展示包反向依赖。

| 位置 | 职责 |
| --- | --- |
| `packages/beecount_ui` | 通用主题、布局、按钮、输入、紧凑 Tab、多选、弹层、反馈、动效。仅接收受控值与回调 |
| `packages/beecount_business_ui` | 账户、分类、交易行、录入、统计、云任务、认证和分享等业务语义布局；接收展示模型、已格式化金额、ImageProvider 与回调 |
| `lib/pages/<domain>/<feature>/bindings` | 原资源查询、身份与权限、默认值、本地化、汇率、格式化、平台操作、原子写入与同步 |
| `lib/pages/<domain>/<feature>/controllers` | 跨事件的页面状态与生命周期；保存重试、防重复、异步请求过期检查 |
| `lib/pages/<domain>/<feature>/widgets` | 当前页面的私有组合、App 资产和主题适配。不作为跨域公共组件入口 |
| `lib/pages/shared` | 确实跨域的应用适配，如账本选择、页面皮肤与品牌资产。仍不承担第二套数据访问 |
| `lib/dev/component_gallery` | 调试组件目录、合成场景与真实数据绑定的显式预览；发布构建不得引用这些入口 |
| `lib/widget` | 桌面与平台现有模块，按实际消费者单独维护，不因目录名相近而删除 |

## 业务包分组

内部 `src` 按 `shared`、`recording`、`transactions`、`resources`、`insights`、`automation`、`assistant`、`cloud_data`、`sharing`、`app_profile` 分组。资源域继续分账户、分类、标签、账本等子目录。公开导出保持稳定；App 使用包的公开 API，不直接 import `src`。

纯布局先抽组件，再由 App 注入真实行为。例如二次验证弹窗由业务包收集输入、显示错误和忙碌态，实际校验仍由 App 请求；年度海报由业务包绘制，日期分母、币种与图片导出仍归 App；推荐卡片不在展示包里打开 URL 或发起支付。

`AgentMarkdownText` 属于 App 的 Markdown 内容适配，现有 `flutter_agent_ui` SDK 明确由宿主提供内容，不为了清空目录向 SDK 添加 Markdown 依赖。皮肤绘制继续使用 App 原有注册表、Painter 和底部 Tab builder，不复制一套皮肤协议进 UI 包。

## 组件与设计维护

设计源、HTML 交互稿与里程碑图在 [BeeCount-Design](https://github.com/TNT-Likely/BeeCount-Design)。App 只保留 `tool/design/contracts`、版本锁、测试 fixture 和自身图标生成 vendor。

`tool/v4/component_coverage.json`、`component_catalog_coverage.json` 与 `foundation_inventory.json` 分别维护样例、HTML 卡与基础 Widget 的映射。新增或拆出组件时，同步真实 Flutter 目录构造、代表状态、设计源和契约；禁止只填索引而无可达样例。

```sh
python3 tool/v4/verify_component_coverage.py
python3 tool/v4/test_verify_component_coverage.py
flutter test --no-pub test/widgets/v4_component_gallery_test.dart
```

组件覆盖、Widget 测试与整页原生验收分别提供证据，不能互相替代。整页完成标准见 [UI 质量与验收](../contributing/ui-quality.md)。
