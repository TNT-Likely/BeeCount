# BeeCount 卡片方案 · 设计资源

更新：2026-10-26。当前本地设计为 567 个导出场景、669 个可选交互路由、105 组组件规范（基础 29 / 业务 76）。默认无皮肤，支持主题色、浅深色及两款可选动态皮肤。App 原73页迁移与已确认A–E修订均已按整页基线和固定增量合并接受，独立报告已封存；实现、验收分别见[中文页面进度看板](migration-progress.html)及[整页验收记录](../../development/v4-page-completion.md)。设计场景、组件和局部测试不计为完整页面。

## 查看入口

| 内容 | 入口 |
| --- | --- |
| 可离线打开的完整交互原型 | [prototype/demo.html](prototype/demo.html) |
| 当前记账页（10 个尺寸、币种和异常场景） | [boards/recording-review.html](boards/recording-review.html) / [大图](boards/recording-review.png) |
| 转账长短屏（空账户、未选与已选、备注展开） | [boards/transfer-responsive.html](boards/transfer-responsive.html) / [大图](boards/transfer-responsive.png) |
| 原三行记账版本的交互、源码与截图 | [只读备份](archive/recording-three-row-20261023/index.html) |
| 完整页面与流程大图 | [boards/all-pages.png](boards/all-pages.png) |
| 主要页面 / 交互与皮肤 | [主要页面](boards/main-pages.png) / [交互与皮肤](boards/interactions.png) |
| 紧凑布局 / 反馈状态 | [紧凑布局](boards/compact-pages.png) / [反馈](boards/feedback-pages.png) |
| 完整 UI 组件规范大图 | [浅色](boards/ui-components-light.png) / [深色](boards/ui-components-dark.png) |
| 按基础 / 业务分组的组件规范 | [components/ui-components.html](components/ui-components.html) |
| 组件约定 / 令牌 | [组件说明](components/COMPONENTS.md) / [设计令牌](tokens/design-tokens.json) |
| 所有场景缩略图、平铺 / 分组与搜索 | [index.html](index.html) |
| 现有 Figma 协作文件与导入说明 | [figma/README.md](figma/README.md) |

当前记账页采用两行表单：备注直接修改，附件在右上角；账户 / 日期 / 紧凑标签在下。表单与键盘保留 8px 间距。金额与元信息固定，分类占剩余高度并独立滚动，键盘和保存贴底；小屏金额横排，备注可折叠。折算说明在左，金额与箭头固定靠右，长金额和大字体不改变边界。

账单行采用已确认 C3：普通情况优先两行，复杂情况最多三行；“不计收支 / 不计预算”保留文字，账本名使用标签，有备注时不额外重复分类名，极端密度下可查看完整字段。保留独立分类图标导航、时间、原币/折算、标签、附件、批量和只读。右侧无省略号，长按打开操作菜单；左滑露出 78px 删除区，右滑收回，点击后确认。标签在行内为 16px 视觉色块，详情为 21px 胶囊，选择器为 26px 胶囊加 44px 透明点击区。账户列表、选择器、摘要和类型编辑统一使用原色 SVG，未知类型回退其他账户。普通点击账单保留直接编辑，长按菜单另有账单详情入口。

## 版本控制与目录

```text
prototype/src/          原型布局、交互、样式和业务样例源
prototype/demo.html     当前离线交互稿，随里程碑保存
prototype/scene-presets.js  缩略图对应的交互状态
prototype/assets/       合成图标、附件示例
prototype/vendor/       本地 Lucide 与许可
components/             组件规范、样例、样式和映射
reference/recording/     当前记账评审稿的逐场景设计参考图
boards/                 全量、主要页面、组件等里程碑大图
screens/manifest.json   页面/分组/图片/SVG/场景映射
scripts/                构建、导出、校验和 Figma 导入准备
tokens/                主题令牌、原实现到流程的映射
archive/                只读历史版本；源码不参与 Dart 分析
figma/README.md         线上文件、导入边界及本地重建说明
qa/                     临时检查结果，不进入 Git
```

设计源、离线 HTML、组件规范、关键大图和原三行备份入库。全量逐页 `screens/viewport/`、`screens/full/`、重复 SVG、Figma 导入 HTML/字体和 `qa/` 是本地可重建产物，保持在本机，不删除、不首次批量提交。全量图片生成后，资源索引的缩略图、完整长页和 SVG 链接可用。

备份内 `manifest.json` 校验原文件，后续不覆盖；源代码快照用于比较，不参与 Flutter 编译或分析。

## 修改与重建

依赖 Node.js、本机 Chrome；Playwright 版本锁定在 package-lock.json。命令在本目录执行：

```sh
npm ci
npm run build
npm run export
npm run export:selected -- flow-config flow-config-select flow-config-preview flow-config-import
npm run guide
npm run review:recording
npm run index
npm run check:pinned
npm run check:guide
npm run check:links
npm run check:parity
```

`export:selected -- <route...>` 仅更新指定页面的 PNG/SVG、场景预设、资源索引及总览大图，保留其他场景。传入 `scene:<slug>` 可单独重建命名状态，例如 `scene:home-no-brand`、`scene:home-longpress`，并保留其品牌、皮肤、主题和视口。配置导入导出保持页面内八项范围选择、预览和导入确认弹窗。

`build` 从 prototype/src 生成完整 demo；`export` 生成逐页 PNG/SVG 和页面大图；`guide` 更新组件规范；`review:recording` 更新十个记账参考场景；`index` 更新总入口。输出目录由 npm 的 prebuild/preexport 自动准备。主题、字号或布局改动需要重新生成相应参考图。

导出使用固定合成数据与冻结的动效时间。`screens/manifest.json` 与 `prototype/scene-presets.js` 使缩略图、标题和交互入口对应同一场景。检查结果留在 qa，不作为页面迁移完成的证明。

## 现有功能的设计约定

- 初始化保留语言、币种/默认账本、分类模式、可选云同步、隐私开源，以及配置/附件恢复；品牌和说明居中，选择项左对齐。
- 首页保留品牌/无品牌两版；AI、搜索、标签颜色、原胶囊底栏和长按记账快捷入口均保留。
- 分类预设图标使用中性底/线条，选中使用主题色；一级/二级都有图标，自定义图片保留原色并覆盖加载/失败/裁切。
- 我的展示昵称、紧凑的当前账本累计余额/天数/笔数，以及完整同步/异常状态。余额遵循全局隐私，不能替换为当月结余。
- 分类工具、检查升级、授权、配置、汇率等短任务保持原弹窗；图片预览保留全屏滑动和缩放，添加来源使用底部弹层；日志/附件库/导入等连续浏览流程保持页面。关联菜单、平台条件和选项以原实现核对。
- HTML 汇率是固定示例。真实账本/权限/请求和持久化留在 App binding；基础 UI 与业务 UI 包不直接发起网络或读取数据库。

本地新增组件、紧凑布局及本轮折算修正未同步到在线 Figma。Figma 现有镜像为早先的 159 个场景、32 组组件；详见导入说明，不能把线上镜像视作当前全部页面已落地。

安全页沿用现有四位 PIN：创建需要二次确认，修改先验证旧密码，错误在原有半秒时长后恢复。锁屏没有返回入口，仅在设备能力和用户开关均允许时显示生物识别。`flow-pin`、`flow-pin-change`、`flow-lock`、`flow-lock-bio` 可直接预览；配置失败与完成提示也保留为弹窗场景。

资产页新增单币种、多币种缺失汇率、隐藏与恢复、估值、默认账户选择和设置弹层场景。账户卡整卡进入详情、长按编辑，菜单保持独立；图表保留净值趋势/资产构成。HTML 为固定数据，实际 App 使用原 Repository 和汇率计算；默认账户与账户开关仍写原偏好。

### 首页长短屏与账本弹窗

- [首页长短屏预览](boards/home-responsive.html)：标准屏固定汇总，短屏允许顶部卡片上滑；小屏大字和空态示例可直接进入交互原型。
- [首页布局大图](boards/home-responsive.png)：五种屏幕/状态（含超预算）的同页设计参考。
- 账本选择沿用居中弹窗，使用搜索、币种、真实笔数与当前态的同一业务选择器；保留底部账本管理入口。
- Flutter 的 `BeeHomeLayout` 根据实际可用高度选择布局；低于 620 逻辑像素时允许顶部上滑，并为虚拟账单列表保留至少 280 像素的视口。双击明细入口同时复位整页和列表。


### 本轮追加的组件与正式页面入口

Flutter 业务目录保留原 0–65 索引，追加 66 账单详情、67 备份同步、68 两端自动记账、69 汇总币种状态、70 共享云、71 分享卡。对应 HTML 规范 spec-89–94，全部平铺并支持搜索和快速定位；正式页面入口仍使用真实 App 路由。

目录的真实预览仅读取当前交易、备份缓存、既有自动记账偏好、本地汇率、共享镜像及原海报数据；打开组件目录不生成账单、不切换 provider、不发起原生导出。完整、缺失、陈旧、错误、权限及隐私等受控状态使用合成数据。原生操作只从原正式页面执行。

本轮导出已包含账单详情、备份预览、自动记账两平台、分类/标签跨账本汇总、共享云与分享卡的新场景。567 场景指 `screens/manifest.json` 的实际导出记录，105 组指组件规范实际目录；设计导出和局部测试均不代表整页原生验收完成。

上批保留前 526 个导出场景和 spec-1–94 的语义，追加 41 个 AI高级/支持/维护场景，形成 567 场景、97 组规范。Flutter 原 0–71 索引保持，追加 72 AI记忆权限与活动、73 关于帮助与支持、74 日志存储与维护，对应 spec-95–97。AI/维护目录注入现成只读预览；支持目录为纯受控状态，生产五页仍使用真实 binding。旧 AI/日志/存储/组件入口路由继续使用相同模块。

年度演示按已发生天数/月数计算当前周期平均值，含今天；已完成年度使用完整天数和 12 个月，并覆盖闰年、自定义起始日及未开始周期。静态导出的帮助/隐私文档保留原 URL，但显式显示 QA 占位并阻断外网，另导出真实加载/失败状态；不代表验证真实官网正文、法律文案或原生 WebView。所有新增设计和局部测试仍不计为整页原生验收。

### 已确认的洞察 A 版

[主 demo 洞察](prototype/demo.html?page=report) 已同步 [A 版评审稿](boards/insights-task-a-review.html)：紧凑月／年／全部与支出／收入／结余 Tab、可点选正负柱、同口径平均线、独立单色占比及可展开分类排行。当前演示时间冻结为2026-10-25，当前月平均除25天、当前年度平均除10个月，未开始的日期/月不计入。结余使用收支构成，不计算分类结余百分比。

原渲染与检查源保留在 [A 版前备份](archive/insights-before-a-20261025/README.md)。仅需刷新洞察逐页资源时，可运行 `BEE_DESIGN_SKIP_PAGE_BOARDS=1 npm run export:selected -- report flow-analytics-income flow-analytics-balance flow-analytics-year flow-analytics-all flow-analytics-empty flow-analytics-loading flow-analytics-error flow-analytics-pie flow-analytics-foreign`；该选项跳过无关总览合成图，默认导出行为保持原样。此变更仅为 HTML 设计同步，不代表 Flutter 或真实数据验收完成。

### A–E 资源同步

洞察 A、资产 B、账单行 C3、分享卡 D 与启动页 E 的已确认设计现已同步主 demo 和逐页资源。确认稿同步定向重建 112 个场景，其余 455 个场景的逐页 PNG/SVG/导入 HTML 保持原字节，场景顺序及 567 个交互预设均保留；无品牌首页、两款动态皮肤、长按菜单、左滑、短屏大字反馈和外币小票也随账单行刷新。随后单独修正孤儿清理分组工具按钮挤压标题的问题并重建 6 个维护场景；两批合计更新 118 个场景，其余 449 个保留原字节。

完整页面、主要页面及交互皮肤三张总览大图，以及完整 / 基础 / 业务组件的浅深色六张大图已重新生成。新增规范补齐紧凑 Tab、并列指标、纸张卡片、状态标记、启动动效与安全说明弹层、七类分享海报及同步健康卡，现共 105 组；Flutter 原有目录索引保持，所有样例仍平铺并支持搜索与快速定位。实际原生验收结果继续单独记录，图片导出不作为原生通过依据；在线 Figma 仍是较早镜像。


### 我的 F/A 与本轮资源同步

我的页面采用已确认 F 的 A 方案：头像按单层图像直接展示，默认蜜蜂和自定义照片共用 48px 点击区；轻量昵称行与紧凑账本余额条分层，保留编辑、账本切换、币种、隐私、累计金额、记录统计和同步异常入口。[F 方案记录](boards/profile-task-f-review.md)保留讨论稿，当前效果以[主 demo](prototype/demo.html?page=mine)为准。

本轮按实际 DOM、交易行 consumer 清单及转账场景定向刷新 104 个场景，覆盖 F 资料 / 昵称 / 同步状态、C 所有已列消费者、首页品牌 / 两款既有皮肤 / 反馈与短屏，以及 18 个转账状态。其余 463 个场景的 1852 个逐页 PNG、SVG 和导入 HTML 保持原字节；全部 567 个预设的内容与顺序、清单顺序均保持。首页五种长短屏参考、完整 / 主要 / 交互总览及六张组件规范图同步重建，规范仍为 105 组。首页品牌卡内嵌的账单样例也改为从当前 C 模板捕获。

原转账预设保持原有尺寸，另以[转账长短屏参考](boards/transfer-responsive.html)补充标准屏与 320×568 下的无账户、未选、已选和展开备注，共八个可进入主 demo 的参考画面，不增加 567 场景计数。可运行 `npm run review:transfer` 单独重建。所有导出与浏览器检查仅证明合成 HTML 设计资源，不替代 Flutter、真机或 Cloud 验收；新皮肤探索稿尚未纳入当前主 demo。

资源总入口可在“平铺 / 分组”之间切换：按 12 个中文业务类别归并展示，原分组筛选继续保留；搜索隐藏空组，并使用入口专属 localStorage 保存显示方式。存储被禁用时保留当次切换能力并安全回退；可运行 `node scripts/validate-resource-index.cjs` 检查。
