---
name: beecount-pr
description: 创建、复用或合并 BeeCount 家族仓库的 PR，关联已有验收轮次，并在合并后核对已解决的 Issue。可独立处理普通 PR。
---

# BeeCount PR

按用户请求选择创建、更新或合并。PR 标题及正文遵循项目的中文 Conventional Commits 规则。

## 创建或关联

- 核对目标 remote、head 分支与提交、base。创建前查同一仓库、base 和 head 的现有 PR。请求超时时向 GitHub 查证后再重试。
- 已有验收轮次时，拿到规范 PR URL 即执行 `python3 scripts/qa/pr_lifecycle.py bind <轮次> <URL>`。跨仓工作从 BeeCount 的共同登记位置调用。提前通过 `start <轮次> --expect-pr OWNER/REPO` 写入明确的待关联仓库。
- 跨仓 PR 相互链接，分别描述本仓改动、依赖和验证。
- 已授权交付证据时，接续 [验收证据](../beecount-pr-qa-evidence/SKILL.md)。同一轮联调报告由一条 PR 发布、其余 PR 引用。无运行时验收的任务按实际检查结果交付。

## 关联 Issue

- 逐条核对 Issue 的需求与本次交付范围。对完整解决的 Issue，在以默认分支为 base 的 PR 正文逐条写关闭关键词。同仓用 `Closes #123`，跨仓用 `Closes OWNER/REPO#123`。部分完成、背景或依赖用普通链接。[GitHub 关闭关键词](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue)
- 需要多条 PR 才能完整交付时，由最后完成交付的 PR 使用关闭关键词，前置 PR 普通引用。合并顺序未确定时，待所需 PR 均合并后核对交付并关闭。
- 创建或复用后，以及合并前，核对 GitHub 识别的关闭关联，可用 `gh pr view <PR> --json closingIssuesReferences`。预期关闭的 Issue 缺失时，先核对目标分支和正文语法。

## 合并

- 由用户授权，核对实际 head SHA、分支规则及本轮约定的验收结果。使用可校验预期 head 的合并入口，回读 GitHub 的 MERGED 状态和合并 SHA。网络失败后先查询远端。
- 合并成功或接续网页合并时，逐条回读本次应关闭的 Issue。若 Issue 已完整解决、所需 PR 均合入各自默认分支，且 Issue 仍打开，将它标为 `completed` 并回读确认。
- 调用 beecount-qa-cleanup 查相同 PR 的已登记轮次。共用资源由该轮全部关联 PR 的合并状态决定。
