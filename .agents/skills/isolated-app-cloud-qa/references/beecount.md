# BeeCount 项目适配

App 仓维护 `scripts/qa/isolated_app_cloud.py`、`scripts/qa/test_isolation.py`、`integration_test/*_live_test.dart` 和 `docs/contributing/ISOLATED_APP_CLOUD_QA_ZH.md`。执行前读项目 guide 与当前 runner，以下命令中的路径和 ref 按本次 checkout 替换。

```sh
python3 -m unittest discover -s scripts/qa -p 'test_*.py' -v
python3 scripts/qa/isolated_app_cloud.py prepare \
  --cloud-repo ../BeeCount-Cloud --cloud-ref <已提交的分支或SHA> \
  --flutter <Flutter可执行文件>
```

`prepare` 打印本次私有 run 路径、新 UDID 和 loopback Cloud origin。使用实际打印路径，不复制以前运行的值。

```sh
qa_run_dir='<本次打印的run目录>'
python3 scripts/qa/isolated_app_cloud.py build --run "$qa_run_dir" --flutter <Flutter可执行文件>
python3 scripts/qa/isolated_app_cloud.py preflight --run "$qa_run_dir"
python3 scripts/qa/isolated_app_cloud.py run --run "$qa_run_dir" --flutter <Flutter可执行文件>
python3 scripts/qa/isolated_app_cloud.py restart-check --run "$qa_run_dir" --flutter <Flutter可执行文件>
python3 scripts/qa/isolated_app_cloud.py review --run "$qa_run_dir"
```

默认 Cloud ref 为 `origin/main`，本地 checkout 分支不切换。联调修复时显式指定 ref，manifest 记录实际 SHA。Cloud checkout 的 `.venv/bin/python` 只读复用；数据库迁移在新目录执行。runtime 参数取本机已安装版本，默认值不代表本机一定可用。

runner 默认从本 App 仓 `.agents/skills/isolated-app-cloud-qa` 记录 skill 的仓库 SHA、完整目录内容 hash 和 metadata.version，并保存私有源码副本。显式使用另一份项目 skill 时传 `--skill-dir <skill目录>`。旧 `--skill-repo` 仅保留历史命令兼容；新环境无需 honeycomb checkout。安装位置、客户端目录与 skill 的版本证据分别记录实际值。

按当前 runner 的 `--scenario` 选择验收场景：默认首页复制 `transaction-copy`，支持时可选分类父子关系 `category-parent` 、网页图片 `web-transaction-images` 或 MCP 小票 `mcp-receipt-attachments`。图片场景由 `web_transaction_images_live_test.dart` 与真实 Web UI 配合；看到 `QA_STAGE_READY_<阶段>` 后完成对应网页操作，再等待下一阶段。等待操作超时仍是该次驱动失败；保留原始退出码，并将后续独立复核结果分开报告。合成 App 图片 fixture 不代表系统相册选择器已验收。

MCP 场景使用 `prepare --scenario mcp-receipt-attachments --cloud-ref <功能 SHA>`，由 `mcp_receipt_attachments_live_test.dart` 使用本次私有 PAT 经真实 Streamable HTTP 的 initialize、tools/list、tools/call 上传合成小票，再创建/编辑交易。不能用直接调用 Python tool 函数或 JWT 写 API 替代 MCP 协议验收。核对 MCP→App 的有序文件身份、SHA 与生产预览，以及 App 实际预览删除→MCP 查询；覆盖省略/null 保留、空列表清空、替换和只读 PAT 拒绝。客户端文件上传脚本也应在同一私有环境实跑，远程 Cloud 不读取客户端路径。Web 图片查看与正常入口重启独立核对；MCP 审计日志排除 Base64 与文件名，公开验收包排除 PAT、Base64 和私人文件名，仅保留合成数据与可公开元数据。

本地文件入口还需独立运行 `scripts/mcp_local_files.py` 的真实 stdio MCP 客户端链路：`upload_attachment(file_path=...)` 的工具 schema 不暴露 Base64；使用大于 680KB 的合成原图，核对本地文件、Cloud 实际存储与 App 下载文件的字节数及 SHA256 全部相同，禁止为适应模型参数而缩放、转码或拆分图片。验证目录外文件、符号链接越界和空文件拒绝，其余读写工具及原始 Cloud 错误结果仍能转发。Claude Code 安装与 health-check 单独记录，具体模型会话内的手工验收交给用户；不把 SDK 验收写成 LLM 客户端 UI 验收。

`review` 启动或复用同一 run 的 Cloud，恢复已核验的正常入口 QA App 并打开模拟器；不迁移、重装或重新生成 fixture。旧 run 缺少 Python 路径时加 `--cloud-repo <原 checkout>`。交付后保持运行，待用户明确验收完成或要求关闭再执行 `stop --run "$qa_run_dir"`。报告记录自动验收快照，另列当前环境运行状态；打包、开 PR 和结束聊天不触发清理。

人工 Cloud 验收需要 Node.js/pnpm，在本次固定 SHA 的源码副本构建 web，产物进入本次静态目录并使用同源 QA API。准备阶段创建静态目录，QA 身份路由优先于 SPA fallback。用浏览器打开本次 origin，登录与 App 相同的私有 QA 账号，选中同一账本并保留交易列表；不打印密码或 token。页面可查看不等于完整 web UI 回归通过。

## 本适配的身份和证据

QA 主包 `com.tntlikely.beecount.qa`，扩展 `.qa.BeeCountWidgetExtension`，App Group `group.com.tntlikely.beecount.qa`；所有已有模拟器受保护。产物身份不符时不可安装。

`restart-check` 用项目 CocoaPods 已使用的 Ruby `xcodeproj` 生成原生 UI 测试工程。构建后的 `.qa.smoke.xctrunner` / `.qa.smoke` ID 先核验，再在同一新 UDID 处理首次通知权限弹窗、断言复制交易与金额可见；不启用并行模拟器克隆。

`evidence/` 下：逐项 `acceptance.json`、真实 Cloud `cloud-projection.json`、`environment.json`、正常入口 `restart-persistence.json` 和合成数据截图。environment 还记录原生 UI 测试退出码；不能仅凭进程存活和数据库有数据判定正常入口完成。原始日志、credentials/env、构建产物、原生 xcresult 及 `private-backups/` 留在私有 run，不复制到 PR。

首页复制用例覆盖：实际长按菜单与预填、取消后再次复制、独立新身份、编辑备注与重复保存、当前日期、标签/账户/标记/币种、收入/转账余额/外币、原附件及周期关系不继承、首页切换账本、服务 503 后恢复、真实 owner/editor 邀请与共享资源引用、Cloud web 写 API 修改后拉回、多次同步及正常入口持久化。

权限阻断用例修改的是 QA 本地已知角色与资源镜像。先启用 QA 503 并等待已有同步结束，避免后台刷新恢复实际 editor 角色或资源；finally 恢复服务及镜像。Cloud 当前支持 owner/editor，不得宣称已测服务端 viewer 或撤销成员。服务 503 不能宣称已测飞行模式。Android、真机和 web 前端需要独立适配，当前 iOS 用例不能替代。

## 报告交付

完整验收结果在忽略目录或仓库外制作离线 HTML 与 ZIP，不提交到功能分支。用界面截图、操作流程和 App/Cloud 对照展示结论，按场景分组列实际断言，技术元数据与 JSON 放折叠附录。包内加入打开说明、manifest 与 SHA256 校验表；不得复制包含私人路径的原始 run manifest。

PR 保留简短结论、覆盖边界、跨仓依赖和报告下载链接。已授权上传时按 [GitHub PR 附件交付](github-pr-attachments.md)，通过网页文件选择器上传独立 ZIP，链接直接放进 PR 描述并回下载核对 SHA256。上传失败则给出本地完整包及限制，不创建应用发版或提交报告文件。
