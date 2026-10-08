# BeeCount 项目 skill

BeeCount 定制的发布与隔离验收流程随项目维护，不再通过 honeycomb 或用户级 skill 分发。

## 一份源码，两个客户端入口

| 内容 | 位置 |
|---|---|
| 发布流程源码 | `.agents/skills/beecount-release/` |
| 隔离验收源码 | `.agents/skills/isolated-app-cloud-qa/` |
| Codex 项目发现 | `.agents/skills/<name>/SKILL.md`，直接读取源码 |
| Claude Code 项目发现 | `.claude/skills/<name>`，相对链接到同一份源码 |

克隆 BeeCount 后，这两个入口随仓库到位。进入该仓启动新会话：Codex 可使用 `$beecount-release`、`$isolated-app-cloud-qa`；Claude Code 可使用 `/beecount-release`、`/isolated-app-cloud-qa`。也可按任务自动选择。旧通用名称 `release` 不再作为本项目入口。

skill 使用标准 `name` / `description` frontmatter、相对 references 和可选 Codex UI 元数据。流程正文不依赖特定客户端的交互工具，不安装 MCP、hook 或 plugin；需要什么授权按当前用户请求决定。读取到 skill 不代表发布或验收已经执行。

Codex 与 Claude Code 均支持项目 skill 目录及目录符号链接，依据：[Codex 官方说明](https://developers.openai.com/codex/skills/)、[Claude Code 官方说明](https://code.claude.com/docs/en/skills)。不支持符号链接的环境需启用 Git/系统的链接支持；不要只复制 SKILL.md 丢掉 references。

## 在 Cloud / Website 使用

这两个技能跨 BeeCount 家族仓库工作；源码仍只维护在 BeeCount。安装器将同一源目录引用到明确指定的项目，不写用户级目录：

```sh
python3 scripts/agents/project_skills.py install --project ../BeeCount-Cloud
python3 scripts/agents/project_skills.py install --project ../BeeCount-Website
```

在 BeeCount 仓之外运行时使用脚本实际路径；自定义 source checkout 可传 `--source-repo <BeeCount目录>`。worktree 安装需要指定真实目标项目路径，不假定 worktree 目录相邻。

Cloud / Website 引用是本地安装，不提交跨仓符号链接。安装器把自身创建的路径加入该仓 `.git/info/exclude`，不修改已有 `.claude` 设置、认证或其他 skill。克隆单独的 Cloud/Website 仓不会自动克隆 BeeCount，也不会自动全局安装；需要这些流程时再执行上述命令。

## 更新、核对与卸载

```sh
python3 scripts/agents/project_skills.py install --project <项目目录> --dry-run
python3 scripts/agents/project_skills.py status --project <项目目录>
python3 scripts/agents/project_skills.py uninstall --project <项目目录>
```

更新同一源 checkout 后，各客户端继续读取最新源码。要切换 source checkout，再执行 `install --source-repo ...`；仅替换安装器确实拥有且未被用户修改的链接。原生目录、用户已有不同链接或内容拒绝覆盖。

安装回执保存在目标项目的 Git 元数据中，不进入提交。`uninstall` 只删除回执中仍匹配的链接，保留源码目录、仓库跟踪的 Claude 桥接以及用户数据；本地 exclude 规则保留。清理跨仓安装后，源 BeeCount 的原生技能仍属于项目源码。

## 从旧全局安装迁移

先完成项目安装，核对两个客户端的项目入口，再显式迁走旧全局副本：

```sh
python3 scripts/agents/project_skills.py migrate-global --project <已安装项目目录> --dry-run
python3 scripts/agents/project_skills.py migrate-global --project <已安装项目目录>
```

只识别 BeeCount 的旧 `beecount-release` / `release` / `isolated-app-cloud-qa`，其他全局 skill 不动。旧目录移动到发现路径外的 `~/.local/share/beecount/project-skill-backups/<时间>/` 并保存回执；可用 `--backup-dir` 指定私有位置。备份包含完整 references，迁移不是永久删除。若曾安装 honeycomb 的旧 plugin，也应卸载对应 plugin，避免继续加载旧版本。

重启客户端刷新列表。Claude Code 中查看 `/skills`，确认路径为当前项目；Codex 在新会话查看 skill 列表。`status` 证明路径和源码一致，不宣称已经运行模型调用或成功发布。

## 发布和验收的来源

发布时查看 App/Cloud 独立版本和各自真实 Release。Cloud 完整发布说明保存在 GitHub Release，待发布草稿留在 BeeCount 忽略的 `.docs/changelogs/cloud-<版本>.md`；官网 App 和 Cloud 分页且中英同步。Cloud 仓库不另维护重复的 `CHANGELOG.md`。

QA runner 默认读取项目 skill 并记录仓库 SHA、目录内容 hash、版本和私有源码快照；显式来源可用 `--skill-dir`，旧 `--skill-repo` 保留兼容。skill 的迁移不改已有 run、数据库、模拟器或正在运行的服务。
