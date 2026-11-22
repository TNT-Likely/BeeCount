---
name: beecount-pr
description: 创建、复用或合并 BeeCount 家族仓库的 PR，并在实际 PR 创建后立即关联已有验收轮次。可独立处理普通 PR。
---

# BeeCount PR

按用户请求选择创建、更新或合并。PR 标题及正文遵循项目的中文 Conventional Commits 规则。

## 创建或关联

- 核对目标 remote、head 分支与提交、base。创建前查同一仓库、base 和 head 的现有 PR。请求超时时向 GitHub 查证后再重试。
- 已有验收轮次时，拿到规范 PR URL 即执行 `python3 scripts/qa/pr_lifecycle.py bind <轮次> <URL>`。跨仓工作从 BeeCount 的共同登记位置调用。提前通过 `start <轮次> --expect-pr OWNER/REPO` 写入明确的待关联仓库。
- 已授权交付证据时接续 beecount-pr-qa-evidence。有 PR 但无运行时验收的任务可按实际检查结果交付。

## 合并

- 由用户授权，核对实际 head SHA、分支规则及本轮约定的验收结果。使用可校验预期 head 的合并入口，回读 GitHub 的 MERGED 状态和合并 SHA。网络失败后先查询远端。
- 合并成功、或用户在其他入口完成合并并返回本项目时，调用 beecount-qa-cleanup 查相同 PR 的已登记轮次。共用资源由该轮全部关联 PR 的合并状态决定。
