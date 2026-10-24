# V4 完整页面迁移清单与优先级

更新：2026-10-24。分支：`v4`。由 `tool/v4/build_migration_inventory.py` 扫描生成，人工决策保存在 [migration-status.json](../../tool/v4/migration-status.json)。

现有 **71 个产品页面源文件**（P0 16 页、P1 42 页、P2 13 页），另有 **2 个新设计页面待新增**、6 个页面旁辅助文件和下方关联弹窗/表单。三个开发验收页不计入产品迁移进度。每个源文件均有设计入口，设计场景与代码页面不是一对一关系。

当前完整完成页面为 **16**（账户详情、新增与编辑账户、资产与账户列表、账单附件大图预览、应用锁解锁、PIN 设置与确认、启动页、欢迎与初始化全流程、新增与编辑分类、分类管理与工具、首页明细、账本管理与切换、我的、昵称与当前账本、配置导入导出与恢复、新增与编辑标签、标签管理）。记账/转账、首页/我的/账户/账本、分类管理/账户编辑和初始化/安全页已部分接入新组件，仍需设计对齐和完整功能验收。其余页面待逐页迁移；全局主题变化不计为页面完成。判定条件见 [页面完成标准](v4-page-completion.md)。

## 优先级与顺序

| 优先级 | 范围 | 完成条件 |
| --- | --- | --- |
| P0 | 记账/转账、首页/我的/账本、明细与搜索、启动/初始化/恢复及直接依赖 | 主路径与关联弹窗一致、真实数据读写和返回正常，先交人工验收 |
| P1 | 统计/资产详情/预算/日历、资源管理、导入导出、云共享、AI/自动化和常用设置 | 按完整流程复用组件，覆盖权限、取消、错误与恢复 |
| P2 | 低频诊断、帮助、支持和高级配置 | 保留原有菜单和选项，关联 P0/P1 的弹窗提前随消费者迁移 |

优先级表示内部实施顺序，不代表 4.0 可以丢弃 P2。对外仍按一个完整 4.0 发布，Beta/RC 前核对全部原有能力及平台入口。M1–M8 是领域批次，与 P0–P2 独立；涉及多个领域的 P0 先跨批次完成。

每页的组件依赖及关键验收写在表中。每批开工先核对原字段、默认值、菜单、平台条件和弹窗，再确定可复用 Section；不要按文件名机械重画。

## P0 · 16 个现有页面

| 页面 / 源码 | 状态 | 批次 | 组件与关联流程 | 必须保留 / 验收 |
| --- | --- | --- | --- | --- |
| **新增与编辑账户**<br>[lib/pages/account/account_edit_page.dart](../../lib/pages/account/account_edit_page.dart) | 已完成 | M3 | 账户类型选择、规范表单、余额调整双模式、信用卡日期与提醒、币种选择和确认弹窗 | 211 项相关回归（27 文件）通过；相同逻辑尺寸的 HTML/真机关键几何对齐。本页 18 项含美元小数、信用卡、估值负数、并发余额、回滚和小屏。R37 实际保存现金/USD/信用卡/贷款、余额三分支、币种锁、隐藏/恢复、删除取消/确认和正常重启通过。原 51 笔与 5 附件不变，保留四个新合成账户及一笔收入 10 供继续验收；当前总 52 笔/当前账本 48。原生 iOS、真实 Cloud 与 OS 还款提醒送达未执行。<br>设计：`flow-account-edit`、`flow-balance-adjust`、`flow-account-new`、`flow-account-credit`、`flow-account-valuation`<br>优先理由：P0 账户依赖已完成：整卡表单、原类型/币种/余额和信用卡流程保留；R37 生产 UI、独立 SQL/文件和正常重启闭环通过。 |
| **资产与账户列表**<br>[lib/pages/account/accounts_page.dart](../../lib/pages/account/accounts_page.dart) | 已完成 | M3 | 资产汇总、账户卡、类型分组与操作菜单 | 239项相关回归（32文件）通过，HTML205场景/59组规范与交互链接、三宽度通过。R42实际验证汇总551814.48、隐私、图表偏好、折算明细、默认美元/现金账户、功能开关、整卡详情/长按编辑、隐藏取消/确认/菜单恢复、汇率/产品入口与正常重启。52笔/当前账本48/5附件/2自定义图片及全部原业务行保持；R41图片语义吞菜单问题已修复并在R42复验。Cloud/iOS和目标P1/P2页迁移未包含。<br>设计：`assets`、`flow-assets-single`、`flow-assets-missing`、`flow-assets-empty`、`flow-assets-hidden`、`flow-assets-valuation`、`flow-account-settings`、`flow-asset-default`、`flow-asset-conversion`<br>优先理由：原全币种统计、净值/构成、隐藏恢复、默认账户与外链入口保留；受控组件与125行页面编排完成。R42生产UI、独立SQL/文件与正常入口重启闭环通过。 |
| **账单附件大图预览**<br>[lib/pages/attachment/attachment_preview_page.dart](../../lib/pages/attachment/attachment_preview_page.dart) | 已完成 | M7 | 附件网格、大图、缩略图与状态 | 7 项真实文件/数据库 widget 回归及冻结 HTML 尺寸通过；真机预览/切换/缩略图、保存附件删除与重新添加、文件 SHA256 和重启持久化通过。双指缩放通过实际 widget 手势；原生拍照及原生双指手势未执行，作为设备覆盖边界记录。<br>设计：`flow-attachment-viewer`、`flow-attachments`<br>优先理由：已对齐 HTML 全屏留白、文件名、计数和缩略图；R13 在同一隔离包完成删除取消、实际删除/系统相册重加与正常入口重启，50 笔交易及其余附件保持不变。 |
| **应用锁解锁**<br>[lib/pages/auth/app_lock_screen.dart](../../lib/pages/auth/app_lock_screen.dart) | 已完成 | M7 | 安全输入、错误反馈与解锁状态 | 四位 PIN、原哈希与生物识别可用性条件不变；398/320 HTML 冻结键盘、浅深色 140% 字体和相关 184 项回归通过。R35 真实 UI 与独立偏好/业务表/文件核对、正常重启通过；原生 iOS、真实设备生物识别未执行。关闭锁前私有验证页仍单独列为设置关联迁移。<br>设计：`flow-lock`、`flow-lock-bio`<br>优先理由：R35 当前独立 Android 产物已完成真实 PIN 创建取消/不一致/保存、旧密码验证/修改、正常重启锁定/解锁、验证关闭锁与移除验收 PIN；原认证规则与所有业务数据保持。 |
| **PIN 设置与确认**<br>[lib/pages/auth/pin_setup_page.dart](../../lib/pages/auth/pin_setup_page.dart) | 已完成 | M7 | PIN 输入、确认步骤与错误状态 | 四位 PIN、原哈希与生物识别可用性条件不变；398/320 HTML 冻结键盘、浅深色 140% 字体和相关 184 项回归通过。R35 真实 UI 与独立偏好/业务表/文件核对、正常重启通过；原生 iOS、真实设备生物识别未执行。关闭锁前私有验证页仍单独列为设置关联迁移。<br>设计：`flow-pin`、`flow-pin-change`<br>优先理由：R35 当前独立 Android 产物已完成真实 PIN 创建取消/不一致/保存、旧密码验证/修改、正常重启锁定/解锁、验证关闭锁与移除验收 PIN；原认证规则与所有业务数据保持。 |
| **启动页**<br>[lib/pages/auth/splash_page.dart](../../lib/pages/auth/splash_page.dart) | 已完成 | M7 | 品牌底座、原安全说明、卡片与初始化进度 | 214 项相关回归（28 文件）与静态检查通过，保留原本地/开源/可选同步三项说明和原自动初始化边界。HTML 398/320、140% 和深色检查通过；R38 原 App 实际生产页面预览、76dp 像素边界及正常入口冷启动/当前账本/52 笔与 5 附件核对通过。无额外欢迎按钮，无初始化耗时声明；欢迎完整流程、真实 Cloud 和原生 iOS 单列。<br>设计：`flow-splash`<br>优先理由：P0 原启动界面已对齐自动初始化展示与安全说明；初始化控制仍在原 MainApp/provider，R38 原 App 页面和正常启动复核通过。 |
| **欢迎与初始化全流程**<br>[lib/pages/auth/welcome_page.dart](../../lib/pages/auth/welcome_page.dart) | 已完成 | M7 | 居中欢迎步骤、语言/币种/分类选择、恢复与云同步说明 | 250项相关回归（33文件）通过；R44最终文案变更后本页11项重跑通过。实际五语言/English偏好、USD/全部151币种搜索THB、三模式草稿、真实系统选择取消/无效YAML拒绝/有效标签导入、无效TAR.GZ拒绝/有效v3零条目包导入与正常重启通过。原52笔/当前48/5附件/2自定义图片保持，仅新增合成标签74581443。首次种子三模式/无账本/失败回滚/防重复及320深色140%由真实仓库widget覆盖；Cloud/iOS和首次空数据包冷启未执行。<br>设计：`welcome`、`welcomeCurrency`、`welcomeCategories`、`welcomeCloud`、`welcomePrivacy`、`welcomeImport`、`welcomeAttachments`、`welcomeDone`、`flow-welcome-currency-picker`、`flow-welcome-bridge`<br>优先理由：原五步和两步恢复保留，受控组件、真实种子/导入服务与失败事务防重完成；R44同一隔离包生产UI、独立SQL/文件及正常重启闭环通过。 |
| **新增与编辑分类**<br>[lib/pages/category/category_edit_page.dart](../../lib/pages/category/category_edit_page.dart) | 已完成 | M3 | 名称与类型、原 237 图标目录、自定义图片草稿、父分类选择与删除保护 | 原 237 图标与分组、收支同名规则、转账类型、父分类禁用和层级、原生相册/裁剪/图片草稿取消、名称图标原子保存与失败回滚、删除保护均已核对。R30/R31 同一 QA 包实际创建/编辑二级分类、图片保存/替换取消、删除取消/确认及原转账入口，正常重启后原 51 笔、5 附件、业务表及图标文件保持。176 项相关回归通过；原生 iOS 与真实 Cloud 未执行。<br>设计：`flow-category-edit`、`flow-category-icons`、`flow-transfer-icon`、`flow-category-new`、`flow-category-parent-picker`<br>优先理由：日常记账闭环、明细导航或启动/恢复入口，必须先保证可用且连贯。 |
| **分类管理与工具**<br>[lib/pages/category/category_manage_page.dart](../../lib/pages/category/category_manage_page.dart) | 已完成 | M3 | 分类层级、图标/图片、表单、排序与工具弹窗 | 228 项相关回归（30 文件）及本页 11 项通过；真实排序、默认两模式、清理保护、ZIP 合并/覆盖、异常重试、空态和短屏深色大字覆盖。R39 真机实际父子编辑/添加、收入类型、转账入口、五项工具取消、支出/全部 ZIP 独立核对、系统选择取消与实际合并导入三分类/自定义 PNG、正常重启通过。原 52 笔/当前账本 48、5 附件和既有图标字节保持，新增三分类保留。独立 HTML/ZIP 验证通过；Cloud/iOS 未执行，真机破坏性默认/覆盖/清理采用取消，确认由真实仓库 widget 测试覆盖。<br>设计：`flow-category-management`、`flow-category-children`、`flow-category-tools`、`flow-category-share`、`flow-taxonomy-import`、`flow-category-defaults`、`flow-category-clear`、`flow-category-empty`、`flow-category-order`<br>优先理由：P0 分类依赖完成：原分类层级、图标和五项工具、文件路径保留；R39 同一隔离包实际导出/导入、自定义图片、导航及正常重启闭环通过。 |
| **首页明细**<br>[lib/pages/main/home_page.dart](../../lib/pages/main/home_page.dart) | 已完成 | M2 | BeeHomeLayout、身份/月汇总/预算、真实账本选择、虚拟账单流、受控扇形菜单与原底部栏 | 280项相关回归/36文件通过；R50品牌重启、隐私、滚轮取消、分类/标签/附件目标、批量48/筛选/日历、复制取消、小票实际关闭、空USD切换/缓存、左滑删除取消、原长按动作取消和正常重启通过。独立SQL核对支出3421.56/收入264.27及预算已用3220.72；原52笔/当前48/5附件/2分类图片及全部原业务行不变。报告home-r50，22图/三宽度/ZIP通过。Cloud/iOS/付费AI和独立目的页不计本页范围；Q01/Q07保留原规则。<br>设计：`home`、`flow-empty`<br>优先理由：R50实际生产UI、独立SQL/文件、原数据保持、正常launcher重启与独立报告闭环；Q01行点击保留原编辑，新增独立详情另列。 |
| **账本管理与切换**<br>[lib/pages/main/ledgers_page_new.dart](../../lib/pages/main/ledgers_page_new.dart) | 已完成 | M2 | 受控账本卡/编辑草稿/28日起始日格/上下文菜单，原真实统计、权限、服务和Repository在App binding | 267项相关回归（35文件）通过；R46本月标题变更后14项重跑与静态通过。真机实际统计/刷新、当前状态、独立更多/长按、新建USD/28日、改名/8日、币种重算确认取消、切换/预算、专用空账本清空/两种删除的取消与确认、当前账本删除回退及正常重启通过。原52笔/当前48/5附件/2图片保持，仅保留UI创建USD账本id4；临时id5/id6已UI删除。非空清理及跨账本文件保护由真实Repo/widget覆盖，Cloud实服/iOS及Q12远端删除未包含。<br>设计：`ledgers`、`flow-ledger-edit`、`flow-ledger-actions`、`flow-ledger-create`、`flow-ledger-period`、`flow-ledger-currencies`、`flow-ledger-remote-actions`、`flow-ledgers-empty`、`flow-ledgers-remote`、`flow-ledgers-loading`、`flow-ledgers-error`、`flow-ledgers-editor`、`flow-ledger-conflict`<br>优先理由：90行页面编排与受控业务组件完成，保留原本地/远端和权限/财务口径；R46生产UI、独立SQL/文件与正常入口重启闭环通过。原云端删除适配遗留Q12单列。 |
| **我的、昵称与当前账本**<br>[lib/pages/main/mine_page.dart](../../lib/pages/main/mine_page.dart) | 已完成 | M2 | 昵称、紧凑账本余额、同步状态与分组菜单 | R22/R23 昵称保存/取消、隐私、账本切换和全部菜单入口有独立版本证据；菜单/云 binding 与 R35 相同。R35 当前产物实际头像、文件/偏好、负数币种与紧凑统计、两款皮肤/深色和恢复默认后重启通过。398/320 冻结尺寸与相关 184 项回归通过。原生拍照/iOS/真实 Cloud 未执行，关联目标页仍按各自清单迁移。<br>设计：`mine`、`flow-sync-states`、`flow-nickname-edit`、`flow-profile-edit`<br>优先理由：已对齐紧凑资料与累计结余、全部原菜单、同步状态及整页皮肤；R35 实际头像系统相册/文件保存/删除恢复、笔数导航和正常重启通过，原 51 笔与 5 附件保持。 |
| **配置导入导出与恢复**<br>[lib/pages/settings/config_import_export_page.dart](../../lib/pages/settings/config_import_export_page.dart) | 已完成 | M7 | 配置范围选择、文件读取/预览、导入导出状态 | 页面、范围选择/预览/确认和完成错误均使用新版卡片与规范弹窗；四项真实 Repository/文件 widget 及 R35 184 项相关回归通过。同一隔离包实际导出文件、剪贴板内容逐字核对与重启，原 51 笔/5 附件和全部业务表/文件保持。iOS 系统分享未执行；Cloud 不适用（仅 App）。<br>设计：`flow-config`、`flow-config-preview`、`flow-export-scope`、`flow-config-select`、`flow-config-import`、`flow-config-error`、`flow-config-done`<br>优先理由：R35 当前产物完成八项范围、真实仅标签 YAML/SQL 字段核对、实际复制粘贴与正常重启；R24/R25 真实系统导入、取消、无效 YAML 拒绝与合成标签保存有固定版本证据，生产数据 binding 与 R35 相同。 |
| **分类详情**<br>[lib/pages/transaction/category_detail_page.dart](../../lib/pages/transaction/category_detail_page.dart) | 部分迁移·R55当前产物复核通过，Q10/Q11待确认 | M3 | 分类信息/父子展开、统计、日期筛选与账单行 | 一级与二级分类图标、跨账本标记、收入/支出、日期/时间、备注/标签与详情导航。<br>设计：`categoryDetail`<br>优先理由：R55同一产物复核父子自定义图标、独立SQL两笔/15.50、月年全部、滚轮取消、排序、编辑/迁移预填取消、父子范围搜索、记账预填取消及正常launcher重启；56笔/5附件SHA保持。逻辑除整页Scaffold外与R21一致，R21实际新增/删除保留对应版本证据，Q10/Q11不擅自改口径。 |
| **账单搜索与批量操作**<br>[lib/pages/transaction/search_page.dart](../../lib/pages/transaction/search_page.dart) | 部分迁移·App可执行范围R55通过，Q08待确认 | M2 | 搜索、筛选/日期范围、账单行和批量操作栏 | 保留当前账本的关键词、分类含二级、金额和日期筛选；对齐设计扩展项。批量备注/分类/删除需保留币种快照、转账目标、共享分类与账户引用、标签和附件；检查取消、合计与空态。<br>设计：`search`、`batch`<br>优先理由：R54/R55同一隔离App实际搜索/完整时间、组合筛选草稿取消、全选反选、批量备注/标签/同类型分类、混合转账分类守卫、独占新建目标删除取消/确认及正常launcher重启通过；逐字段SQL保留原52笔、四笔增量及5附件SHA。302项相关回归和22图脱敏离线报告通过；Q08成功后撤销仍跳过，不计严格新增整页。 |
| **记账、新增、编辑与复制**<br>[lib/pages/transaction/transaction_editor_page.dart](../../lib/pages/transaction/transaction_editor_page.dart) | 部分迁移·App可执行范围R53通过，Q09待确认 | M1 | 金额/折算、计算器、两行元信息、分类/资源选择器与转账账户组合 | 293项相关回归/37文件及R8冻结几何通过。原52笔/5附件保持，保留4笔本轮UI新增数据，总56/当前52；金额/元信息/键盘固定，历史快照、身份、标签和标记独立核对。真实完整IME遮挡因设备最小化未执行，长短屏140%由widget验证。通用分类弹窗正在另行统一。<br>设计：`editor`、`flow-foreign-editor`、`flow-recognition-result`<br>优先理由：R52/R53真实录入、行内备注返回、完整选中二级、自定义图片、历史汇率1、收入及转账、独立SQL/文件和正常重启已通过；23图检查点已封存。转账同屏/弹层Q09保留旧流程待确认，不计整页完成。 |

## P1 · 42 个现有页面

| 页面 / 源码 | 状态 | 批次 | 组件与关联流程 | 必须保留 / 验收 |
| --- | --- | --- | --- | --- |
| **账户详情**<br>[lib/pages/account/account_detail_page.dart](../../lib/pages/account/account_detail_page.dart) | 已完成 | M3 | 账户信息、余额、统计与过滤账单列表 | 323项/42文件相关回归、4文件静态检查及18组HTML通过；398/320关键几何独立冻结对照。R56实际CNY/USD、编辑取消、资金流向、1元信用卡还款和两类估值取消保存；R59实际投资+50、欠款减少10后父页SQL一致，图例中心及正常重启57笔/24账户/5附件保持。20图离线报告account-r59三宽度通过，ZIP SHA256 1ddceb4cf99b7f0831e2e1167de6743cdf9f6db1812448a3b1279ffb107aa1ef。Cloud/iOS及提醒送达未执行。<br>设计：`accountDetail`、`flow-account-credit-detail`、`flow-account-overpayment-detail`、`flow-account-no-limit-detail`、`flow-account-valuation-detail`、`flow-account-loan-detail`、`flow-account-empty-detail`、`flow-valuation`<br>优先理由：266行组合页，原分页/统计/资金流向、信用卡/估值及完整原币字段保留；R56/R59同一QA真实UI、独立SQL/文件和正常重启完成。R56发现父页缓存未刷新，R59已实际再次修改投资/贷款并确认无需重启两次立即更新。 |
| **净资产趋势**<br>[lib/pages/account/net_worth_trend_page.dart](../../lib/pages/account/net_worth_trend_page.dart) | 待迁移 | M4 | 净资产汇总、趋势图、时间范围与明细 | 资产/负债/净资产和折算口径、范围切换、无数据与历史点选择。<br>设计：`flow-networth`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **AI 助手设置**<br>[lib/pages/ai/agent_assistant_settings_page.dart](../../lib/pages/ai/agent_assistant_settings_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`flow-assistant-settings`、`flow-execution-depth`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **AI 对话与执行**<br>[lib/pages/ai/ai_chat_page.dart](../../lib/pages/ai/ai_chat_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`ai`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **AI 提示词编辑**<br>[lib/pages/ai/ai_prompt_edit_page.dart](../../lib/pages/ai/ai_prompt_edit_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`flow-prompt`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **AI 服务商管理**<br>[lib/pages/ai/ai_provider_manage_page.dart](../../lib/pages/ai/ai_provider_manage_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`flow-providers`、`flow-provider-edit`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **AI 设置**<br>[lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`flow-ai-settings`、`flow-capabilities`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **云账号登录**<br>[lib/pages/auth/login_page.dart](../../lib/pages/auth/login_page.dart) | 待迁移 | M7 | 登录表单、安全输入、验证码与错误反馈 | 原账号/验证方式、合法输入、加载防重、取消、登录失败/恢复和实际鉴权。<br>设计：`flow-login`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **Android 自动记账设置**<br>[lib/pages/automation/auto_billing_settings_page.dart](../../lib/pages/automation/auto_billing_settings_page.dart) | 待迁移 | M6 | 平台引导、开关、选择项与配置表单 | 保留 Android/iOS/渠道条件、权限检查、设置跳转、默认值与失败反馈。<br>设计：`flow-android-auto`、`flow-auto-platform`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **iOS 自动记账设置**<br>[lib/pages/automation/ios_auto_billing_page.dart](../../lib/pages/automation/ios_auto_billing_page.dart) | 待迁移 | M6 | 平台引导、开关、选择项与配置表单 | 保留 Android/iOS/渠道条件、权限检查、设置跳转、默认值与失败反馈。<br>设计：`flow-ios-auto`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **预算编辑**<br>[lib/pages/budget/budget_edit_page.dart](../../lib/pages/budget/budget_edit_page.dart) | 待迁移 | M4 | 预算汇总、分类额度、进度与编辑表单 | 总预算/分类预算、周期、超支与剩余口径，取消/保存及统计数据一致。<br>设计：`flow-budget-edit`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **预算总览**<br>[lib/pages/budget/budget_page.dart](../../lib/pages/budget/budget_page.dart) | 待迁移 | M4 | 预算汇总、分类额度、进度与编辑表单 | 总预算/分类预算、周期、超支与剩余口径，取消/保存及统计数据一致。<br>设计：`budget`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **账单日历**<br>[lib/pages/calendar/calendar_page.dart](../../lib/pages/calendar/calendar_page.dart) | 待迁移 | M4 | 月历、日期选择、金额汇总与账单行 | 月切换、日期格/选中/账单标记、当天明细与币种统计，保留查看和编辑入口。<br>设计：`calendar`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **分类迁移**<br>[lib/pages/category/category_migration_page.dart](../../lib/pages/category/category_migration_page.dart) | 待迁移 | M3 | 源/目标分类选择、预览、确认与结果 | 父子分类、账单迁移范围/数量、目标约束、取消/防重和关联标签规则。<br>设计：`flow-category-migration`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **BeeCount Cloud 同步**<br>[lib/pages/cloud/beecount_cloud_sync_page.dart](../../lib/pages/cloud/beecount_cloud_sync_page.dart) | 待迁移 | M5 | 同步状态、配置、成员列表与权限操作 | 沿用实际同步引擎与角色；保留配置/备份/邀请、异常重试和本地/远端删除差别。<br>设计：`flow-cloud-sync`、`flow-sync-health`、`flow-twofa`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **云服务配置与账号**<br>[lib/pages/cloud/cloud_service_page.dart](../../lib/pages/cloud/cloud_service_page.dart) | 待迁移 | M5 | 同步状态、配置、成员列表与权限操作 | 沿用实际同步引擎与角色；保留配置/备份/邀请、异常重试和本地/远端删除差别。<br>设计：`flow-cloud-config`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **云端备份与同步**<br>[lib/pages/cloud/cloud_sync_page.dart](../../lib/pages/cloud/cloud_sync_page.dart) | 待迁移 | M5 | 同步状态、配置、成员列表与权限操作 | 沿用实际同步引擎与角色；保留配置/备份/邀请、异常重试和本地/远端删除差别。<br>设计：`flow-backup`、`flow-failure`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **共享账本邀请**<br>[lib/pages/cloud/invite_page.dart](../../lib/pages/cloud/invite_page.dart) | 待迁移 | M5 | 同步状态、配置、成员列表与权限操作 | 沿用实际同步引擎与角色；保留配置/备份/邀请、异常重试和本地/远端删除差别。<br>设计：`flow-invite`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **加入共享账本**<br>[lib/pages/cloud/join_shared_ledger_page.dart](../../lib/pages/cloud/join_shared_ledger_page.dart) | 待迁移 | M5 | 同步状态、配置、成员列表与权限操作 | 沿用实际同步引擎与角色；保留配置/备份/邀请、异常重试和本地/远端删除差别。<br>设计：`flow-join`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **共享成员管理**<br>[lib/pages/cloud/member_list_page.dart](../../lib/pages/cloud/member_list_page.dart) | 待迁移 | M5 | 同步状态、配置、成员列表与权限操作 | 沿用实际同步引擎与角色；保留配置/备份/邀请、异常重试和本地/远端删除差别。<br>设计：`flow-members`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **汇率管理**<br>[lib/pages/currency/exchange_rate_page.dart](../../lib/pages/currency/exchange_rate_page.dart) | 待迁移 | M3 | 币种列表、汇率表单、校验与更新状态 | 保留账本本位币、自定义汇率/来源、正数校验和当前历史快照规则。<br>设计：`flow-rates`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **账单导出**<br>[lib/pages/data/export_page.dart](../../lib/pages/data/export_page.dart) | 待迁移 | M7 | 导入选择、字段映射、预览、任务状态与结果 | 原格式和字段、分类映射、错误/部分成功、进度取消、恢复与导出范围。<br>设计：`flow-export`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **导入映射、预览与结果**<br>[lib/pages/data/import_confirm_page.dart](../../lib/pages/data/import_confirm_page.dart) | 待迁移 | M7 | 导入选择、字段映射、预览、任务状态与结果 | 原格式和字段、分类映射、错误/部分成功、进度取消、恢复与导出范围。<br>设计：`flow-mapping`、`flow-category-map`、`flow-import-preview`、`flow-import-progress`、`flow-result`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **账单导入入口**<br>[lib/pages/data/import_page.dart](../../lib/pages/data/import_page.dart) | 待迁移 | M7 | 导入选择、字段映射、预览、任务状态与结果 | 原格式和字段、分类映射、错误/部分成功、进度取消、恢复与导出范围。<br>设计：`flow-import`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **统计与洞察**<br>[lib/pages/main/analytics_page.dart](../../lib/pages/main/analytics_page.dart) | 待迁移 | M4 | 日期范围、统计汇总、趋势/环图/排行与分类展开 | 月份/范围、本位币合计、一级/二级排行图标、分类详情、统计开关与空数据。<br>设计：`report`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **年度账单**<br>[lib/pages/report/annual_report_page.dart](../../lib/pages/report/annual_report_page.dart) | 待迁移 | M4 | 年度汇总、趋势、排行与分享内容 | 年度选择、金额/笔数统计口径、隐私、分享卡与真实图片导出。<br>设计：`annual`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **应用锁设置**<br>[lib/pages/settings/app_lock_settings_page.dart](../../lib/pages/settings/app_lock_settings_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-lock-settings`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **显示与外观设置**<br>[lib/pages/settings/appearance_settings_page.dart](../../lib/pages/settings/appearance_settings_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`appearance`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **全局附件库**<br>[lib/pages/settings/attachment_preview_page.dart](../../lib/pages/settings/attachment_preview_page.dart) | 待迁移 | M7 | 附件库网格、筛选/选择、预览和任务状态 | 完整附件入口、筛选、来源关联、空态、加载失败、批量选择和导入导出。<br>设计：`flow-attachment-library`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **自动化功能入口**<br>[lib/pages/settings/automation_page.dart](../../lib/pages/settings/automation_page.dart) | 待迁移 | M6 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`automation`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **数据管理入口**<br>[lib/pages/settings/data_management_page.dart](../../lib/pages/settings/data_management_page.dart) | 待迁移 | M7 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`data`、`flow-attachment-transfer`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **字体设置**<br>[lib/pages/settings/font_settings_page.dart](../../lib/pages/settings/font_settings_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-font`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **皮肤选择与预览**<br>[lib/pages/settings/header_skin_page.dart](../../lib/pages/settings/header_skin_page.dart) | 待迁移 | M8 | 皮肤预览、选择与主题适配 | 默认无皮肤，两款动态皮肤浅深色、主题色、预览、应用/取消、减少动画。<br>设计：`skins`<br>优先理由：承接本轮两款动态皮肤与主题预览；默认无皮肤，保留旧主题迁移。 |
| **语言设置**<br>[lib/pages/settings/language_settings_page.dart](../../lib/pages/settings/language_settings_page.dart) | 迁移中·原五项与语言/地区偏好保留，规范选择卡片和刷新检查收口 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-language`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **个性化设置入口**<br>[lib/pages/settings/personalize_page.dart](../../lib/pages/settings/personalize_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`appearance`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **记账提醒**<br>[lib/pages/settings/reminder_settings_page.dart](../../lib/pages/settings/reminder_settings_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-reminder`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **智能记账入口与识别偏好**<br>[lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) | 待迁移 | M6 | 智能记账入口、功能引导弹窗、默认行为开关与语音设置 | 平台/渠道入口、原三个默认开关、自动/按住语音、静音时长、配置弹窗与识别入口。<br>设计：`smart`、`flow-capture`、`flow-feature-guide`、`flow-voice-trigger`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **标签详情**<br>[lib/pages/tag/tag_detail_page.dart](../../lib/pages/tag/tag_detail_page.dart) | 部分迁移·R60可执行范围闭环完成，Q11待确认 | M3 | 语义标签、关联分类、统计/筛选和账单行 | 14图独立报告tag-r60三宽度及17文件/ZIP校验通过，SHA256 4a89da66479ba71deef351711289fa187e849ad7916a56a51b3e93346009e3ee。原57笔/当前53/24账户/5附件及全部原表保持。实际保留标签只关联账本1，不冒充原生多账本聚合；两个账本与synthetic共享字段由真实DB/widget覆盖。Cloud/iOS未执行。<br>设计：`tagDetail`、`flow-tag-foreign-detail`、`flow-tag-all-ledgers-detail`、`flow-tag-empty-detail`<br>优先理由：原567行备份保持，新213行页面接入真实统计/流/批量元信息/共享账户水合，保留全部默认、月年与自定义周期。R60同一QA当前范围、滚轮/编辑/删除取消、带标签记账取消、专属空标签创建与确认删除、原31笔标签全范围及正常重启通过。340项/46文件、12组HTML及独立几何通过，跨本位币合计沿用旧口径，Q11不擅自改。 |
| **新增与编辑标签**<br>[lib/pages/tag/tag_edit_page.dart](../../lib/pages/tag/tag_edit_page.dart) | 已完成 | M3 | 规范表单、语义标签实时预览、受控20色选择与真实保存结果 | 九图独立报告tag-edit-r61，三宽度及12文件/ZIP校验通过，SHA256 d0fa699ae10b111fc5c924ff69df3c68b67da48d66f27fe7b878da93ffe7e7d1。原57笔/当前53/24账户/5附件和全部原标签关系保持。长标签20字素320深色140%回归通过，颜色44触控/36色块。Cloud/iOS及共享负身份写入不属于本地编辑已通过范围，旧服务缺口Q13保留。<br>设计：`flow-tag-edit`、`flow-tag-new`<br>优先理由：原308行备份保持，新137行页与真实保存绑定完成，20色/旧自定义色/查重/返回值保留。350项主回归与最终样式10项、6组HTML通过；R61同一QA实际必填/重名拒绝、新建选色、同身份改名换色、取消/专属目标删除和正常重启闭环通过。 |
| **标签管理**<br>[lib/pages/tag/tag_manage_page.dart](../../lib/pages/tag/tag_manage_page.dart) | 已完成 | M3 | 受控BeeTagLibrary、真实标签预览、上下文工具菜单、确认/模式弹窗、原子标签导入与平台文件适配 | 361项/51文件主回归、最终9项目标检查、12组HTML与独立网格几何通过；10文件主静态检查及最终测试复核0问题。R62实际23标签仅标签YAML导出、系统/模式取消、两标签合并、原同名颜色保持、新增入口取消、专属删除取消/确认及正常重启通过。原57笔/当前53/24账户/5附件与全部旧行保持，只保留橙色合成标签26。15图/18文件独立报告tag-library-r62三宽度与ZIP校验通过，SHA256 4bb4871bdc0f1854919b2f06beb64e901e9e1e2e6c2f86021ccbefab8941870b。Cloud/iOS未执行；清理/覆盖实际写入由真实Repository/widget覆盖。<br>设计：`flow-tag-management`、`flow-tag-management-empty`、`flow-tag-management-error`、`flow-tag-management-loading`、`flow-tag-tools`<br>优先理由：原633行备份保持，新170行编排真实标签网格和四项工具；原生成/导入/清理/分享与全局计数保留。R62同一QA实际UI、独立SQL/文件和正常重启闭环完成。 |
| **周期账单编辑**<br>[lib/pages/transaction/recurring_transaction_edit_page.dart](../../lib/pages/transaction/recurring_transaction_edit_page.dart) | 待迁移 | M1 | 周期编辑表单、金额/币种/账户、日期与频率选择 | 周期/频率/起止/下次执行、币种/账户/标签/备注、取消和调度更新。<br>设计：`flow-recurring-edit`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |
| **周期账单列表**<br>[lib/pages/transaction/recurring_transaction_page.dart](../../lib/pages/transaction/recurring_transaction_page.dart) | 待迁移 | M1 | 周期任务列表、状态、菜单与空态 | 周期/下一次、启用停用、编辑/删除和已有任务状态，调度与执行服务不变。<br>设计：`flow-recurring`<br>优先理由：常用扩展业务与资产/统计/管理，核心闭环稳定后按整条流程迁移。 |

## P2 · 13 个现有页面

| 页面 / 源码 | 状态 | 批次 | 组件与关联流程 | 必须保留 / 验收 |
| --- | --- | --- | --- | --- |
| **AI 活动记录**<br>[lib/pages/ai/agent_activity_page.dart](../../lib/pages/ai/agent_activity_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`flow-activity`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **AI 记忆管理**<br>[lib/pages/ai/agent_memory_page.dart](../../lib/pages/ai/agent_memory_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`flow-memory`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **AI 权限管理**<br>[lib/pages/ai/agent_permissions_page.dart](../../lib/pages/ai/agent_permissions_page.dart) | 待迁移 | M6 | 消息、配置表单、授权、任务状态与列表 | 沿用原 AI 服务与权限，保留配置草稿、能力绑定、执行反馈、失败重试和取消。<br>设计：`flow-permissions`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **共享成员统计**<br>[lib/pages/cloud/member_stats_page.dart](../../lib/pages/cloud/member_stats_page.dart) | 待迁移 | M5 | 同步状态、配置、成员列表与权限操作 | 沿用实际同步引擎与角色；保留配置/备份/邀请、异常重试和本地/远端删除差别。<br>设计：`flow-member-stats`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **打赏支持**<br>[lib/pages/donation/donation_page.dart](../../lib/pages/donation/donation_page.dart) | 待迁移 | M8 | 支持选项、支付入口和说明 | 原支持选项、平台入口、复制/跳转与返回，沿用实际服务。<br>设计：`flow-donation`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **孤儿数据清理**<br>[lib/pages/maintenance/orphan_cleanup_page.dart](../../lib/pages/maintenance/orphan_cleanup_page.dart) | 待迁移 | M7 | 清理概览、选择、确认与结果状态 | 沿用实际孤儿数据判断，预览/取消/确认、数量、失败反馈和数据安全。<br>设计：`flow-orphan`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **关于与检查更新**<br>[lib/pages/settings/about_page.dart](../../lib/pages/settings/about_page.dart) | 待迁移 | M8 | 版本/链接/分组菜单与升级弹窗 | 完整原菜单、检查升级的检查中/最新/可升级/错误、平台入口；调试组件入口不计页面迁移完成。<br>设计：`about`、`flow-update-check`<br>优先理由：仅新增了调试验收入口，关于页本身未翻新；检查更新保持弹窗。 |
| **帮助中心**<br>[lib/pages/settings/help_center_page.dart](../../lib/pages/settings/help_center_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-help`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **日志中心**<br>[lib/pages/settings/log_center_page.dart](../../lib/pages/settings/log_center_page.dart) | 待迁移 | M8 | 级别/来源多选、搜索、统计、日志行与堆栈详情 | 保留 DEBUG/INFO/WARN/ERROR、Flutter/当前平台、多选/搜索、详情/复制、导出与清空确认。<br>设计：`flow-logs`、`flow-log-detail`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **隐私政策**<br>[lib/pages/settings/privacy_policy_page.dart](../../lib/pages/settings/privacy_policy_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`leaf:隐私政策`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **快捷指令引导**<br>[lib/pages/settings/shortcuts_guide_page.dart](../../lib/pages/settings/shortcuts_guide_page.dart) | 待迁移 | M6 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-shortcuts`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **存储空间管理**<br>[lib/pages/settings/storage_management_page.dart](../../lib/pages/settings/storage_management_page.dart) | 待迁移 | M7 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-storage`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |
| **桌面小组件管理**<br>[lib/pages/settings/widget_management_page.dart](../../lib/pages/settings/widget_management_page.dart) | 待迁移 | M8 | 分组菜单、输入/选择/开关、弹窗与状态 | 逐项核对原字段/默认值/选项、平台条件、保存/取消/返回；原弹窗保持弹窗。<br>设计：`flow-widgets`<br>优先理由：低频配置、诊断、引导或支持内容，后置迁移并保留原入口。 |

## 待新增页面（不与现有 71 页重复计数）

| 页面 | 优先级 / 状态 | 计划位置 | 原代码与新稿差别 |
| --- | --- | --- | --- |
| 账单详情 | P0 / 待新增 | `lib/pages/transaction/transaction_detail_page.dart` | 原列表点击进入编辑，原代码没有独立详情 Page；新版需落地已设计的详情入口、附件、复制、编辑和小票。<br>设计：`detail`、`flow-foreign-detail`、`flow-attachment-grid` |
| 分享卡片 | P1 / 待新增 | `lib/pages/report/share_card_page.dart` | 新稿有独立卡片预览与样式切换；原分享服务继续复用，页面只组合内容与导出。<br>设计：`poster` |

## 必须随页面迁移的关联表单与弹窗

这些不是独立 Page，不能从清单遗漏，也不能为了换皮把原弹窗改成新页面。P2 所属的检查升级弹窗可以随关于页后置；若上游提前消费，弹窗随上游一批交付。

| 流程 / 源码 | 优先级 / 状态 | 验收要求 |
| --- | --- | --- |
| **转账表单（同币种/跨币种）**<br>[lib/widgets/transaction/transfer_form.dart](../../lib/widgets/transaction/transfer_form.dart) | P0 / 部分接入·待完整验收 | 转出/转入账户、币种与汇率、金额、备注、标签、统计、余额与保存防重；先提取账户组合组件。 |
| **金额与元信息表单**<br>[lib/widgets/biz/amount_editor_sheet.dart](../../lib/widgets/biz/amount_editor_sheet.dart) | P0 / 部分迁移·完整验收中 | 键盘贴底、8px 间距、备注直接修改、附件右上角、分类独立滚动、折算右对齐。 |
| **账单行、长按与滑动菜单**<br>[lib/widgets/biz/transaction_list.dart](../../lib/widgets/biz/transaction_list.dart) | P0 / 部分接入·待完整验收 | 真实列表绑定、分类图标导航、时间/折算/标签/附件、批量与只读、长按菜单和删除确认。 |
| **分类选择弹窗**<br>[lib/widgets/biz/category_selector_dialog.dart](../../lib/widgets/biz/category_selector_dialog.dart) | P0 / 新版组件就绪·旧消费者待迁移 | 二级图标、自定义图片、搜索、更多分类、取消不提交。 |
| **账户选择弹窗**<br>[lib/widgets/biz/account_selector.dart](../../lib/widgets/biz/account_selector.dart) | P0 / 部分接入·待完整验收 | 按币种筛选、未设置、隐藏历史账户、共享权限、搜索和草稿。 |
| **账本选择弹层**<br>[lib/widgets/biz/ledger_picker_sheet.dart](../../lib/widgets/biz/ledger_picker_sheet.dart) | P0 / 已完成·本地真实选择与原管理入口 | 当前态、个人/共享、币种与搜索、切换账本不丢草稿。 |
| **币种选择弹层与汇率编辑**<br>[lib/widgets/currency/currency_picker_sheet.dart](../../lib/widgets/currency/currency_picker_sheet.dart) | P0 / 真实业务组件已接入·待完整验收 | 搜索、同币种账户联动、历史快照、汇率缺失和正数校验。 |
| **标签横排选择**<br>[lib/pages/tag/widgets/tag_selector.dart](../../lib/pages/tag/widgets/tag_selector.dart) | P0 / 真实业务组件已接入·待完整验收 | 多选、搜索、取消不提交、新建标签、长标签与 +N。 |
| **日期与时间滚轮**<br>[lib/widgets/ui/wheel_date_picker.dart](../../lib/widgets/ui/wheel_date_picker.dart) | P0 / 已复用·待全消费者核对 | 月末/闰年、时间开关、取消和系统安全区。 |
| **历史备注选择**<br>[lib/widgets/biz/note_picker_dialog.dart](../../lib/widgets/biz/note_picker_dialog.dart) | P1 / 待迁移 | 常用备注筛选/排序、直接输入与选择后的草稿一致性。 |
| **账单小票弹窗**<br>[lib/widgets/biz/transaction_receipt_dialog.dart](../../lib/widgets/biz/transaction_receipt_dialog.dart) | P1 / 待迁移 | 原币与折算、标签/附件、隐私、图片生成和系统分享，沿用弹窗。 |
| **AI 授权弹窗**<br>[lib/widgets/ai/agent_tool_authorization_dialog.dart](../../lib/widgets/ai/agent_tool_authorization_dialog.dart) | P1 / 样式就绪·真实消费者待迁移 | 实际动作、权限、金额与上下文，拒绝和允许不丢任务。 |
| **检查升级弹窗**<br>[lib/services/update/update_dialogs.dart](../../lib/services/update/update_dialogs.dart) | P2 / 待迁移 | 保持原弹窗，检查中/最新/可升级/错误与下载入口。 |
| **关闭应用锁前的私有密码验证页**<br>[lib/pages/settings/app_lock_settings_page.dart](../../lib/pages/settings/app_lock_settings_page.dart) | P1 / 待迁移 | 保留四位旧密码验证、失败半秒恢复、取消返回 false；只在验证成功后清除 PIN 和关闭生物识别，不改变锁定策略。 |

## 页面旁辅助文件

- [lib/pages/ai/agent_message_visibility.dart](../../lib/pages/ai/agent_message_visibility.dart)：随直接消费者迁移，不重复计为 Page。
- [lib/pages/ai/agent_tool_presentation.dart](../../lib/pages/ai/agent_tool_presentation.dart)：随直接消费者迁移，不重复计为 Page。
- [lib/pages/budget/widgets/budget_progress_bar.dart](../../lib/pages/budget/widgets/budget_progress_bar.dart)：随直接消费者迁移，不重复计为 Page。
- [lib/pages/budget/widgets/category_budget_tile.dart](../../lib/pages/budget/widgets/category_budget_tile.dart)：随直接消费者迁移，不重复计为 Page。
- [lib/pages/cloud/sync_preview_dialog.dart](../../lib/pages/cloud/sync_preview_dialog.dart)：随直接消费者迁移，不重复计为 Page。
- [lib/pages/tag/widgets/tag_selector.dart](../../lib/pages/tag/widgets/tag_selector.dart)：随直接消费者迁移，不重复计为 Page。

## 备份、拆分与交付

活跃页面继续在原路径修改，开工前将相关文件复制到 `.docs/v4-ui-migration/backup/checkpoint-日期-流程/lib/...`，记录 SHA256；旧代码只读，不放进 `lib/backup` 参与编译。旧提交基线固定为 `6616066247a8738a42996c496e1b99106820e59f`，新增提交后不重新定义“旧版”。原三行记账稿另有 [设计与源码快照](../design/card-refresh/archive/recording-three-row-20261023/index.html)。

Page 负责参数、状态、导航与 Section 组合；App binding 复用当前 Provider/Repository、权限与提交控制器；基础和业务 UI 包接收数据/回调，不直接请求网络或依赖数据库。普通页 150–250 行、复杂页 250–400 行作为评审信号，不为行数拆文件。

每批交付：原行为对照、HTML/Flutter 状态对应、相关测试、独立 App 正常入口验证和人工验收。不得以截图、目录覆盖或代码变短直接标记完成。全量状态见 [机器可读清单](v4-page-inventory.json)，组件契约见 [组件包说明](v4-component-packages.md)，记账试点见 [录入说明](v4-recording-flow.md)。

更新命令：

```sh
python3 tool/v4/build_migration_inventory.py
```

生成器会拒绝未登记的新页面，确保优先级和状态不会悄悄遗漏。
