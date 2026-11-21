---
name: beecount-pr-qa-evidence
description: 发布并核验 BeeCount 隔离验收报告 ZIP 和截图。处理 BeeCount PR 合并（包括「合并吧」）或确认已合并时，定位关联验收并在合并后回收环境。
metadata:
  version: "0.2.0"
---

# BeeCount PR 验收证据交付

使用 [隔离验收 skill](../isolated-app-cloud-qa/SKILL.md) 交付的独立报告、合成截图与 ZIP。从 [PR 验收交接](../isolated-app-cloud-qa/references/pr-lifecycle.md) 接续同一轮验收。

## 接续发布或合并

- 已获授权交付 PR 的隔离验收，报告校验完成后直接执行本技能的发布步骤。也可独立补发既有报告。缺少可核对的结果时，先找既有报告，按用户授权判断是否补测。
- 处理 BeeCount PR 的合并请求时，根据实际 PR URL 查验收记录。用户授权合并后，确认 GitHub 已显示所有关联 PR 为 `MERGED`，在回复前按[完整清理](../isolated-app-cloud-qa/references/cleanup.md)回收该轮资源并记录结果。用户明确要求保留、关联 PR 尚未合并或无可确认的 QA 资源时，按交接参考处理。

## 核对待交付证据

- 读取目标仓库、PR 编号、最新描述和 head SHA。对照报告中对应仓的源码 SHA；多仓联调时保留各仓分别验过的版本。PR 后续提交应与报告的实测版本区分。
- 预先打开报告和代表性截图，核对公开范围。排除原始日志、凭证、真实用户数据、应用二进制和私人路径。用 `unzip -t` 检查 ZIP，解压到私有临时目录核对 manifest 与 `SHA256SUMS`，计算 ZIP 自身 SHA256。后续上传、复核及回执均引用这份固定文件。
- ZIP 保留完整 HTML、截图和技术附录，证据文件通过附件交付并留在本地忽略目录。按用户指定的范围选择截图，在 PR 正文配简短说明。复用同一实测 SHA 与 ZIP SHA256 对应的已有附件，核验或补齐缺项。

## 在 GitHub 发布

1. 在已有登录且能编辑目标 PR 的浏览器会话中打开描述编辑器，使用「Paste, drop, or click to add files」或页面提供的文件选择入口。通过系统文件选择器提交核验过的文件。支持多选时可将本次待上传文件放在专用目录，再核对选中文件。附件类型或大小有疑问时查看 [GitHub 官方附件说明](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files)。
2. 上传占位符变为真实附件链接时先记入本地交付回执，再整理正文。优先使用 PR 描述编辑器；若使用同一 PR 的评论编辑器暂存链接，发布描述后清理本次临时草稿。使用刚读取的描述，保留原有改动、验收范围、用户编辑、其他附件和 Issue 关联，只补充本次证据。描述包含 ZIP 链接、解压打开 `index.html` 的说明、实测 SHA、ZIP SHA256 与带说明的内嵌截图。
3. 保存并检查实际渲染的描述，确认报告和截图链接都已发布、图片可见。通过已发布的 ZIP 链接回下载，比较大小及 SHA256，再验证 ZIP 可解压。收到上传 URL 仅表明上传成功，交付完成以发布后校验为准。
4. 回执留在 ZIP 外，记录 PR URL、附件 URL、实测 SHA、ZIP SHA256、文件名、回下载结果及交付截图。报告仍是当时的验收快照，回执供后续合并和失败重试接续。

## 异常处理

网页会话未登录时，按当前客户端流程复用已有登录会话或交接登录。GitHub API/CLI 可读取或维护描述，附件经网页选择器上传。上传或回下载受阻时在交接记录中保留已完成的部分、已取得的链接和具体阻碍，交付本地证据。重试只处理缺失步骤，并重新读取 PR 正文和 head。发布和回下载分别记录实际状态。
