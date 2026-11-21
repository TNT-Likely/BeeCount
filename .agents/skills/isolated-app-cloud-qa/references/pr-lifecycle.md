# 隔离验收的 PR 交接

有已授权的目标 PR 时，校验完成即发布证据。所有关联 PR 合并后，在本轮完成环境清理。使用下述本机记录让创建 PR、验收交付和单独的「合并吧」能接续同一批资源。

## 记录轮次

创建私有 run 时记录其所有权信息。确定 PR 后立即绑定，包括后续失败、重试和已被替代的 run。记录放在 BeeCount 源 checkout 的 Git common dir 下，由 [`pr_lifecycle.py`](../../../../scripts/qa/pr_lifecycle.py) 保存。该路径在同一 clone 的 worktree 间共享，Cloud 项目通过项目 skill 的 BeeCount 源 checkout 调用同一脚本。

交接 JSON 只引用私有路径和身份，不写凭证、日志或原始数据。

| 字段 | 内容 |
|---|---|
| `id` | 在同一轮保持不变的唯一 ID |
| `pr_urls` | GitHub 返回的完整关联 PR URL，可先为空 |
| `pending_pr_repos` | 本轮已知关联、尚未拿到 PR URL 的仓库，无则为空 |
| `runs` | 本轮每个 run 的 ID、确切根目录和原始 manifest 路径，包含失败及重试。额外创建的资源也记录其所有权证据 |
| `report` | run 外的 HTML、固定 ZIP、ZIP SHA256 和对应仓库的实测 SHA |
| `delivery_receipts`、`cleanup_receipt` | 按已授权发布的 PR URL 记录 run 外的交付回执路径，并另存本轮清理回执路径 |
| `keep_after_merge` | 仅在用户明确要求继续保留环境时设为真 |

```sh
python3 <BeeCount 源 checkout>/scripts/qa/pr_lifecycle.py save <本轮交接 JSON>
python3 <BeeCount 源 checkout>/scripts/qa/pr_lifecycle.py find <GitHub PR URL>
```

`find` 按完整 PR URL 返回记录文件路径。补充 PR 或重试时读取原记录再更新，保留先前 run。源 checkout 发生变化时从保存记录的 clone 查询。旧轮次可以从已核实的交付回执、原任务创建记录与私有 manifest 找回关联后登记，仅凭目录名或设备名称无法确认归属。

## 验收完成后发布

1. 报告和 ZIP 保存到 run 外并校验。PR 已明确且交付已获授权时，直接使用 [PR 验收证据 skill](../../beecount-pr-qa-evidence/SKILL.md)。同时接受了验收和开 PR 委托时，创建 PR 后立即发布 ZIP 和代表截图，检查线上渲染并从 PR 回下载校验。
2. 仅本地验收、尚无已授权目标 PR 或用户要求不上传时，保留本地证据。目标获得授权后接着交付原报告。跨仓联调按授权目标发布，注明各仓实测 SHA。
3. 如果已发布同一份证据，复用现有链接并核验。附件确有阻碍时记录进度、具体阻碍和本地报告位置，供后续接续。保留同一环境供人工复核。

## 合并后清理

1. 处理 BeeCount PR 合并时先根据实际 URL 查交接记录，有获准但未完成的附件交付时接续缺失步骤。用户授权后完成合并。当前工具确认合并、会话接到合并事件或接续已合并 PR 时，查询记录内所有 PR 的 GitHub 状态，确认均为 `MERGED`、待关联列表为空。有关联 PR 仍在等待时保留共享环境，最后一个合并时接续。
2. 全部合并即在当前会话执行[完整清理](cleanup.md)，无需再次确认。用户明确要求继续保留时记入交接记录并保留；用户提前结束验收或要求清理时，直接核对并回收本轮资源。没有可归属的 QA 记录时按普通 PR 流程完成合并。
3. 从原始 manifest 核实资源，按回执和实际状态跳过已完成项。某项身份不匹配或清理失败时，记录尚存资源和具体原因，并完成其余可核验的清理。最后报告环境状态及保留的独立证据。发布的 ZIP 保持原校验值，附件需要补发时可从 run 外接续。
