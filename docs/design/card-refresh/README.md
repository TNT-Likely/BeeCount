# BeeCount 卡片方案 · 设计资源

更新：2026-10-25。当前本地设计为 567 个页面/交互场景、97 组组件规范。默认无皮肤，支持主题色、浅深色及两款可选动态皮肤。App 当前严格完成 39/73 页；其余实现、部分完成和待确认状态见[中文页面进度看板](migration-progress.html)及[整页验收记录](../../development/v4-page-completion.md)。设计场景、组件和局部测试不计为完整页面。

## 查看入口

| 内容 | 入口 |
| --- | --- |
| 可离线打开的完整交互原型 | [prototype/demo.html](prototype/demo.html) |
| 当前记账页（10 个尺寸、币种和异常场景） | [boards/recording-review.html](boards/recording-review.html) / [大图](boards/recording-review.png) |
| 原三行记账版本的交互、源码与截图 | [只读备份](archive/recording-three-row-20261023/index.html) |
| 完整页面与流程大图 | [boards/all-pages.png](boards/all-pages.png) |
| 主要页面 / 交互与皮肤 | [主要页面](boards/main-pages.png) / [交互与皮肤](boards/interactions.png) |
| 紧凑布局 / 反馈状态 | [紧凑布局](boards/compact-pages.png) / [反馈](boards/feedback-pages.png) |
| 完整 UI 组件规范大图 | [浅色](boards/ui-components-light.png) / [深色](boards/ui-components-dark.png) |
| 按基础 / 业务分组的组件规范 | [components/ui-components.html](components/ui-components.html) |
| 组件约定 / 令牌 | [组件说明](components/COMPONENTS.md) / [设计令牌](tokens/design-tokens.json) |
| 所有场景缩略图与搜索（逐页图片导出后） | [index.html](index.html) |
| 现有 Figma 协作文件与导入说明 | [figma/README.md](figma/README.md) |

当前记账页采用两行表单：备注直接修改，附件在右上角；账户 / 日期 / 紧凑标签在下。表单与键盘保留 8px 间距。金额与元信息固定，分类占剩余高度并独立滚动，键盘和保存贴底；小屏金额横排，备注可折叠。折算说明在左，金额与箭头固定靠右，长金额和大字体不改变边界。

账单行保留独立分类图标导航、时间、原币/折算、标签、附件、批量和只读。右侧无省略号，长按打开操作菜单；左滑露出 78px 删除区，右滑收回，点击后确认。标签在行内为 21px 视觉色块，标签选择器为 44px 选择项。普通点击账单保留直接编辑，长按菜单另有账单详情入口。

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

`export:selected -- <route...>` 仅更新指定页面的 PNG/SVG、场景预设、资源索引及总览大图，保留其他场景。配置导入导出保持页面内八项范围选择、预览和导入确认弹窗。

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

本轮导出已包含账单详情、备份预览、自动记账两平台、分类/标签跨账本汇总、共享云与分享卡的新场景。567 场景指 `screens/manifest.json` 的实际导出记录，97 组指组件规范实际目录；设计导出和局部测试均不代表整页原生验收完成。

本批保留前 526 个导出场景和 spec-1–94 的语义，追加 41 个 AI高级/支持/维护场景，实测共 567 场景、97 组规范。Flutter 原 0–71 索引保持，追加 72 AI记忆权限与活动、73 关于帮助与支持、74 日志存储与维护，对应 spec-95–97。AI/维护目录注入现成只读预览；支持目录为纯受控状态，生产五页仍使用真实 binding。旧 AI/日志/存储/组件入口路由继续使用相同模块。

年度演示按已发生天数/月数计算当前周期平均值，含今天；已完成年度使用完整天数和 12 个月，并覆盖闰年、自定义起始日及未开始周期。静态导出的帮助/隐私文档保留原 URL，但显式显示 QA 占位并阻断外网，另导出真实加载/失败状态；不代表验证真实官网正文、法律文案或原生 WebView。所有新增设计和局部测试仍不计为整页原生验收。
