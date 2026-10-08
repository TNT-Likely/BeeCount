# App 与 Cloud 隔离验收

用于需要真实 iOS App UI、真实 Cloud 数据持久化和双向同步的验收。当前支持首页复制交易、父子分类改名同步和 Web 交易图片三种场景。单元/widget 测试与 fake-provider 同步测试仍是快速回归层，实服同步另行执行。

## 环境要求

- macOS、Xcode、已安装的 iOS runtime（默认 iOS 26.5）、项目支持的 Flutter；不得安装到现用模拟器。
- Python 3.12+；Cloud checkout 已 fetch `origin/main`，其 `.venv/bin/python` 包含兼容该版本的依赖。验收只读取这套 Python 运行时，不切换 Cloud 当前分支，不修改已有环境文件。
- Ruby 的 `xcodeproj`（项目 CocoaPods 已使用）：用于生成独立的 QA 原生 UI 测试工程，处理正常入口首次系统权限弹窗并断言主页交易可见。
- Node.js 20+ 与 pnpm：人工 Cloud 验收前在本次源码副本构建 web 前端，API 使用同一 QA origin，不能连接默认开发端口或现用 Cloud。
- QA 资源写入新建的系统临时目录，至少留出两个 App 构建及容器备份的空间。

## 执行

先运行不接触设备/服务端数据的脚本保护测试及功能回归：

```sh
python3 -m unittest discover -s scripts/qa -p 'test_*.py' -v
flutter test test/utils/transaction_copy_test.dart test/widgets/transaction_copy_gesture_test.dart
```

准备环境（以下为参数示例，按实际 checkout 路径替换）：

```sh
git -C ../BeeCount-Cloud fetch origin main
python3 scripts/qa/isolated_app_cloud.py prepare --cloud-repo ../BeeCount-Cloud
```

默认场景为 `transaction-copy`；分类关联修复使用 `prepare --scenario category-parent`。分类场景在真实 App 分类管理页改名父分类，等待浏览器在同一 QA 账本将父分类改为「QA Web伙食」、子分类「QA早餐」改为「QA早饭」，再通过实际同步引擎拉回并核对父子身份。网页操作由浏览器实际执行，不能以直接写 API 替代这两项 Web UI 验收。

图片场景使用 `prepare --scenario web-transaction-images --cloud-ref <Cloud 功能提交 SHA>`。先通过 App 的实际附件服务保存合成图片并由真实引擎上传，再在同源 QA 网页完成新建、追加、单张移除后再追加、替换、删除全部和重新上传；每个阶段由 App 引擎拉回，核对附件身份、顺序和文件 SHA256，并打开生产预览页确认显示。App 预览页实际删除后，再核对 Web 附件为空。最终通过网页留下两张图片供人工验收，正常入口重启时再次核对元数据和文件内容。

测试在日志中输出 `QA_STAGE_READY_WEB_*` 等待实际浏览器操作。禁止用直接写 API 替代 Web 上传、移除和替换的前端验收。初始 App 图片是通过实际附件服务建立的合成 fixture，不代表系统相册选择器已经测试；该范围必须在报告中明确。Web 的取消、非法文件、失败重试、重复图片及窄屏预览另由浏览器实际执行，证据进入本次独立报告。

分类场景的正常入口检查断言主页合成交易可见，并读取 QA 数据库核对父分类名称、子分类稳定身份与本地 `parent_id` 关系。两种场景共用隔离措施，执行结果与截图仍只进入独立报告包。

Cloud 默认取 `origin/main`；需要联调独立修复分支时，通过 `--cloud-ref <分支或 SHA>` 指定已提交的版本。manifest 记录解析后的实际 SHA，Cloud 当前 checkout 不切换。

命令打印本次私有 run 路径、新模拟器 UDID 和本地 Cloud origin。将打印的实际路径赋值给 `qa_run_dir`，不要引用旧 run：

```sh
qa_run_dir='/实际打印的/beecount-qa-随机目录'
python3 scripts/qa/isolated_app_cloud.py build --run "$qa_run_dir"
python3 scripts/qa/isolated_app_cloud.py preflight --run "$qa_run_dir"
python3 scripts/qa/isolated_app_cloud.py run --run "$qa_run_dir"
python3 scripts/qa/isolated_app_cloud.py restart-check --run "$qa_run_dir"
python3 scripts/qa/isolated_app_cloud.py review --run "$qa_run_dir"
```

`build` 对当前 tracked 文件与 QA 入口生成源码副本，构建后核验实际主包和扩展的 ID / 签名 entitlement。改代码后创建新 run，再构建；不要将旧 artifact 当作新代码已通过。

`run` 用 `flutter drive --use-application-binary` 安装已经检查的同一产物，并明确指定新 UDID。测试使用生产首页、编辑器、真实 Repository、真实运行时 provider、SyncEngine 和鉴权，fixture 为合成数据。测试用例不得在普通 `flutter test -d <现用设备>` 下运行。

`restart-check` 构建正常 `lib/main.dart` 入口，先私密备份 QA 容器，核验新产物后只在本次 QA 设备安装/启动。独立 `.qa.smoke.xctrunner` / `.qa.smoke` 原生测试产物先核验身份，再在同一新 UDID 处理系统权限弹窗、断言主页修改后的复制交易和 55.5 金额可见；读取 QA sandbox 确认持久化并截取实际 App 画面。原生测试不启用并行设备克隆，结果包仍为私有证据。

`review` 是自动验收后的人工验收交接：核验当前安装的正常入口产物，启动本次 Cloud 和模拟器，打开 QA App，保持环境运行。复用同一数据库、凭证、origin 和现有 App；不执行迁移、重装、重新准备 fixture 或自动用例，不覆盖用户手工验收数据。旧 run 没有记录 Python 路径时加 `--cloud-repo <原 Cloud checkout>`。

交接前构建同一 Cloud SHA 的 web 前端，静态产物仅放到本次 `cloud-data/static`。构建子进程使用明确环境与同源 `/api/v1`，不继承现用 Vite API 设置。新环境启动 API 前就创建静态目录，保证网页路由已注册；QA 身份路由优先于 SPA fallback。已经交接的环境复用原网页产物，不重复安装或构建。

打开 QA Cloud 的浏览器页面，使用本次私有凭证登录和 App 相同的 QA 账号，选中同一账本并展示交易列表。凭证只在内存与授权的 QA 登录表单中使用，不打印到聊天、日志或公开报告。保留登录页面供用户继续操作；自动验收、浏览器页面查看与用户人工验收分开记录。

自动验收或报告打包完成后不要关闭本地服务和模拟器。交付时说明 App 入口、Cloud 地址、run 身份及版本，标记等待用户验收；用户明确确认验收完成或要求关闭后，才执行：

```sh
python3 scripts/qa/isolated_app_cloud.py stop --run "$qa_run_dir"
```

`stop` 只停止 manifest 中 PID/启动时间/命令匹配的 QA 服务以及对应 QA 模拟器，保留数据和证据。结束聊天、开 PR 或输出报告都不代表用户验收完成。禁止使用全局 shutdown、默认 compose volume 清理或按进程名批量 kill。

## 隔离保证

- 新模拟器名含 run ID，创建前全部已有 UDID 写入保护名单；所有设备操作都显式使用本次新 UDID。
- QA 源码副本使用 `com.tntlikely.beecount.qa`、独立 extension、`group.com.tntlikely.beecount.qa`，移除正式 iCloud entitlements 与 Info 配置。正式 checkout 的 iOS 配置和 widget 代码不改写。
- Cloud 固定为指定 ref 的源码快照；独立 cwd 无 `.env` / `.env.local`，子进程使用明确环境变量，新数据库、附件、备份、restore、RAG 与 rclone 路径都在 run 内。
- Cloud 绑定随机 loopback 端口，App 测试先核对 QA 服务标记和真实 provider origin。凭证随机生成，管理员凭证预设，避免服务默认打印管理员密码。
- 备份调度与 RAG 定时刷新关闭，汇率代理关闭；外币验收使用明确折算快照。
- 集成测试前后备份 QA data 和 App Group 容器；原始日志、测试数据库、凭证及构建产物仅留在权限 `0700` 的 run 中。

## 验收与证据

`evidence/acceptance.json` 记录实际执行的逐项结果与源/新交易 syncId；截图由 integration driver 生成。`cloud-projection.json` 读取新 Cloud 数据库的真实 projection；`environment.json` 记录源码/产物 hash 和环境身份；`restart-persistence.json` 与正常入口截图补充持久化结果。

核心流程：首页长按 → 预填 → 取消/编辑保存 → App 上传 → Cloud snapshot 与数据库核对 → 真实 web 写 API 修改 → App 拉回 → 多次同步不增笔数。补充收入、转账余额、外币和标记、附件/周期不继承、首页切换账本、共享 editor 身份及资源引用。

服务不可用场景由私有 QA wrapper 对 `/api/*` 返回 503，再恢复实际服务；这是 Cloud 故障模拟，不宣称设备飞行模式已测试。现用宿主机网络不受影响。

权限阻断用例只修改 QA 本地已知角色与资源镜像。先让 QA 服务返回 503，并等待已有同步结束，再构造缓存，避免背景刷新覆盖 fixture；用例结束后恢复真实服务与本地镜像。Cloud 当前支持 owner/editor，不得将本地 viewer 阻断写成服务端 viewer 或撤销成员验收。

### 独立报告交付

执行结果、截图和 JSON 留在忽略目录或仓库外；不加入功能分支的提交。项目维护测试源码、runner 和本流程说明。

将检查后的证据整理为离线 HTML 报告，按“界面效果 → 操作闭环 → App/Cloud 数据对照 → 场景分组结果 → 范围与限制”组织。默认展示人能读懂的结论、关键数值与截图；SHA、设备身份、命令及完整 JSON 放在折叠技术附录中。截图可查看原图，手机宽度下仍可阅读。

报告逐项标记 `PASS / FAIL / 未执行`，注明实际 App/Cloud/skill SHA、命令和退出码。不能将计划、fake 测试或接口 200 当作实服同步通过；需要核对交易身份、笔数、业务字段与原交易未改变。区分真实权限与本地缓存 fixture、Cloud 写 API 与 web 前端、503 与实际断网。

完整包包含 `index.html`、打开说明、合成数据截图、脱敏 JSON、文件 manifest 与 SHA256 校验表，压缩为独立 ZIP。打包前检查凭证、token、私人绝对路径与文件清单，解压后核验校验表并检查报告布局。不要将原始 run manifest 直接复制到公开包，其中包含私有路径。

报告是自动验收时的证据快照，人工验收后的数据可能变化。报告中单列当前环境交接状态；生成 ZIP 不要求先停止服务，也不能将正在运行的环境写成已清理。

PR 只保留简短验收摘要、范围限制、相关仓依赖和报告下载链接。用户授权上传时，使用独立附件保存 ZIP；附件不进入 Git 历史，也不为报告创建应用发版。上传后核对下载文件与本地 ZIP 的 SHA256；上传受限时交付本地包并说明实际限制。

原始 credential/env 文件、完整日志、App 二进制、数据库和私人备份不得提交。公开报告不含测试密码、token 或私人绝对路径；截图只含本次合成数据。
