---
name: beecount-release
description: "准备和发布 BeeCount App、BeeCount-Cloud 的版本，维护商店文案、Cloud 发布记录及官网中英更新日志。用于 BeeCount 发版、发布准备或历史日志补录；不用于其他项目或日常 PR 合并。"
metadata:
  version: "0.2.0"
---

# BeeCount 发布

本 skill 与 BeeCount 仓库一起维护；Codex 和 Claude Code 使用同一份内容。相关仓库按本次实际 checkout 定位，不假定用户的主目录或工作路径。

## 按请求选择流程

- **准备或执行发版**：读取 [发布流程](references/publishing.md)。先完成版本内容和文档准备，再确认实际发布动作。用户已明确授权的版本、范围和动作沿用，不重复询问。
- **编写或补录日志**：读取 [更新日志规范](references/changelogs.md)。以真实 Release/tag 为依据，仅完成日志与文档；补录不触发发版。
- **官网涉及新行为**：同步对应功能页及英文镜像，必要时补充最低 Cloud 版本和升级顺序。

## 项目约束

1. 操作前核对 `origin` 对应 `TNT-Likely/BeeCount`、`BeeCount-Cloud` 或 `BeeCount-Website`，记录实际路径和提交 SHA。相关仓库通常相邻；worktree 的原仓位置可用 `git rev-parse --path-format=absolute --git-common-dir` 定位。路径不符合预期时查明实际 checkout，再继续。
2. 打 tag、触发发布 workflow、更新公开 Release 或合并官网 PR，遵循本次用户授权。单纯要求设计、日志补录或 PR 实现不授权这些发布动作。最终发布确认应展示已经准备好的内容、仓库、版本、SHA 和确切命令。
3. 双端发版时 Cloud 先于 App。App 的 `pubspec.yaml` 版本由 CI 从 tag 注入，不手动改；Cloud tag 使用三段版本号，具体触发规则以当前 workflow 为准。
4. App 商店文案保存在忽略的 `.docs/changelogs/`，不提交。Google Play 文案剔除纯 iOS 条目；App 商店文案不包含服务端部署和运维内容。
5. Cloud 的版本说明维护在 `BeeCount-Cloud/CHANGELOG.md`。官网 App 日志是 `docs/changelog.md`，Cloud 日志是 `docs/cloud-changelog.md`，两者各有英文镜像。Cloud 单独发布也要检查自己的日志，不以 App 未发版为由跳过。
6. 已合并但未发布的变化归入 `Unreleased`。版本号、日期和功能归属从真实 Release 与 tag 区间核对，不能按 App 版本或当前 main 推测 Cloud 已发布内容。

## 完成时交付

列出已完成的准备、发布/部署实际状态、更新的日志入口和仍需用户完成的商店或生产升级步骤。设计文档、截图和执行报告只留在忽略目录；不要默认对外发送宣传或 issue 回复。项目级安装与使用见仓库的 [安装说明](../../../docs/contributing/PROJECT_SKILLS_ZH.md)。
