# UI 令牌与受控组件

通用卡片、文字、分隔、选中和状态色使用 `beecount_ui` 的主题与语义令牌；App 兼容主题适配在 `lib/styles/tokens.dart`。不要在页面重复硬编码一套明暗颜色。

页面顶部单选使用基础包 `BeeSegmented`，调用方持有值、数据筛选和持久化。采用已批准的紧凑高度，选中/长按不出现超出控件的水波纹。底部常驻导航使用自己的原入口与皮肤 builder，不按顶部 Tab 密度统一缩小。

多选使用基础包 `BeeMultiSelect` 或业务标签选择器。色块尺寸与触控目标分开：交易行/详情内标签紧凑，选择器仍提供可用的点击区域。标签业务色不被选中色覆盖。

金额、统计排除和错误使用语义色，支持明暗模式与用户收支色反转。账户图标保留原资产颜色，自定义分类图片填满图标。隐私模式必须同步遮蔽原币、折算和完整字段层。

App 保留的小型设计值在 `tool/design/contracts`；每次批准设计变化同步契约、Flutter 实现和独立设计仓，并更新 `tool/design/design.lock.json`。完整 HTML、探索稿、导出大图在 [BeeCount-Design](https://github.com/TNT-Likely/BeeCount-Design)。
