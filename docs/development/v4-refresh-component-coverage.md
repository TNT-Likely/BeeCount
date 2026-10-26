# A–E 翻新组件的目录覆盖

本轮补齐现有 App 内「基础组件验收 / 业务组件验收」，不创建新应用。新增组仍然平铺，快速定位只滚动到锚点，不替换其他示例。既有组索引不变。

| 来源 | 组件 | Flutter 位置（从 1 开始） | HTML 对应 |
| --- | --- | --- | --- |
| A / B | `BeeCompactTabs`、`BeeUnderlineTabs`、`BeeColumnChart` | 基础 23「紧凑页签与柱状图」；洞察组合仍在业务 53 | 新增 `spec-2001`；原洞察样例不变 |
| D | `BeePaper`、`BeePaperRule`、`BeeCardFrame`、`BeeStatusPill` | 基础 24「纸面、卡框与状态胶囊」 | 新增 `spec-2002` |
| E | `BeeTrailBackdrop`、`BeeActivityIndicator`、`BeeLocalSheet` | 基础 25「启动描线、活动与局部弹层」 | 新增 `spec-2003` |
| 系统栏修复 | `BeeSystemBars` | 基础 26「主题与系统状态栏」 | 新增 `spec-2004` |
| E | `BeeSplashLayout`、`BeeSplashSecurityContent` 与安全说明模型 | 业务 76「启动品牌、状态与安全说明」 | 新增 `spec-2005`，保留 B 启动稿链接 |
| D | 档案、应用、月、年、账本、年度长图、小票；对应 `BeeProfileSharePoster`、`BeeAppSharePoster`、`BeeFinancialSharePoster`、`BeeReceiptPoster` | 业务 77「七类分享海报平铺」；原分享交互仍在业务 72 | 新增 `spec-2006`，直接使用已批准 D 评审稿的纸面内容和作用域隔离样式 |
| D | `BeePosterCanvas`、`BeePosterBrand`、`BeePosterHeader`、`BeePosterFooter`、`BeePosterAmount`、`BeePosterMetricPair`、`BeePosterRanking`、`BeePosterChapter`、`BeePosterTrend`、`BeePosterMoment` 及其纯数据模型 | 业务 77 的七类海报和高光/未解锁片段 | 同上；不是另画一套简化纸面 |
| D | `BeeSyncHealthHeader` | 业务 78「云同步健康状态」，成功/检查/差异/错误同时显示 | 新增 `spec-2007` |
| B | `BeeAssetAccountToolbar` | 补入原业务 41「资产总览与账户设置」 | 新增 `spec-2008`，映射同一原组 |
| A | `BeeAnalyticsSummary`、`BeeAnalyticsShare`、`BeeAnalyticsProportion`、`BeeAnalyticsRankingList`、`BeeAnalyticsComposition` | 原业务 53 已覆盖，保留支出/收入/结余交互 | 原洞察分区，未替换 |
| B | `BeeAssetOverviewCard`、`BeeAssetTypeGroup`、`BeeCompactAccountRow`、`BeeAssetAllocation`、`BeeAssetComposition`、`BeeAssetTrendPreview` | 原业务 41 已覆盖（汇总通过 `BeeAssetSummary(compact:true)` 使用新卡），只补缺失工具栏 | 原资产分区，未替换 |
| C | 三行交易行及组合状态 | 原业务 30「交易行状态全集」继续使用更新后的公共组件/样例；本轮未改样例源 | 原交易行分区，未替换 |
| D 相关卡片 | 更新后的预算概览、年度概览、开源/支持品牌卡、分享预览选择与动作 | 原业务 50 / 64 / 74 / 72 已覆盖，不重复创建另一套 | 原相关分区保留 |

当前 Flutter 目录为基础 26 组、业务 78 组。HTML 对一个 Flutter 组可以有多个规范卡，数量不应当作页面迁移进度，也不要求一对一。

## 数据边界

组件包继续只接参数和回调。新增目录展示沿用原目录的内存样例值，不创建数据库、账号、Cloud 或设备 fixture，不写金融数据，不执行保存/分享平台操作。海报「放大查看」是普通只读弹窗，收入开关只改目录局部状态。

真实数据继续使用已有的当前账本绑定：业务 72 的 `ShareCardPreview(previewOnly:true)`、业务 64 的 `LiveAnnualReportPreview`、原洞察/资产等读取入口。本轮不复制一组 Provider 或重复发起真实数据请求。启动样例不 watch 初始化 Provider，也不修改真实路由。

## HTML 源与重建

追加源是 `docs/design/card-refresh/prototype/src/refresh-component-catalog.cjs`，由 `scripts/build-guide.cjs` 的小型 hook 追加样例/CSS/交互。新卡使用 `2001–2008`，避开原 A/B/C/D 目标卡和原样例编号。不要直接改生成的 `components/ui-components.html`、`catalog.json` 或规范 PNG/SVG。

D 的规范快照源于已批准的 `boards/share-cards-task-d-review.html`，保留源 SHA。`scripts/build-refresh-poster-samples.cjs` 可以在 D 稿明确改变后重建 `refresh-poster-snapshots.json/.css`：只读取合成评审 DOM，默认头像，不读取用户头像，不请求外网。样式全部前缀隔离；全局主题色仍能传入纸面品牌色。

主线合入其他 HTML 变动后统一运行原 `npm run guide` / `npm run index` 等重建流程即可。主线已统一重建本地 HTML 与 PNG/SVG；在线 Figma 仍是较早镜像。

## 验证范围

系统栏修复单独提交，通过真实渲染后平台通道断言深浅切换、保留输入、内层覆盖和导航栏字段不被写入。组件目录通过新增组的 320 小屏/140% 大字/深浅渲染、关闭局部弹层、快速定位、七类海报放大和收入开关；原两页全部目录的四组尺寸也回归。HTML 在 1440 / 398 / 320 的深浅、定位、主题和局部交互中检查。

这些是 Widget 与浏览器证据。设备正常入口仍由主任务复用统一隔离环境验收，不据此新增整页真机完成数。

基础索引13另补真实 `BeeMultiSelect` 受控/禁用与 `BeeInlineLabel` 紧凑、省略/提示、局部点击样例，保持26/78目录不变，属于R117候选而非R116原生通过。当前精确清单与数据边界统一见 [组件包说明](v4-component-packages.md)，工具同时核对99个样例key、105张规范卡及57个基础Widget，避免重复维护另一套索引。
