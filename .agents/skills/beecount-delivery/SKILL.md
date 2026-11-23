---
name: beecount-delivery
description: BeeCount 功能开发的默认入口。按任务授权从设计、实现、隔离 QA 串联到 PR 证据、合并和验收回收，支持从任何阶段接续。
---

# BeeCount 开发流程

1. 识别任务范围与本轮授权。用户指定独立阶段时调用相应 Skill。方案确认、仅设计和仅验收各按当前目标交付。创建 PR、发布证据、合并分别使用已有授权。
2. 新页面、布局重组、入口移动或关键交互变化先用 [HTML 设计](../beecount-ui-design/SKILL.md) 出稿，再按授权继续。内部逻辑、CI、单点文案及细微样式调整可直接实现。已有确定设计时以当前稿为准。
3. 实现后按实际范围运行快速回归及 [隔离验收](../isolated-app-cloud-qa/SKILL.md)。在准备时记录轮次和资源。纯 App 默认复用一台隔离模拟器；需要双向联调时才启动 Cloud。将本轮报告和 ZIP 保存到 run 外并登记。
4. 使用 [PR 操作](../beecount-pr/SKILL.md) 创建或复用并立即关联。已授权交付时继续 [验收证据](../beecount-pr-qa-evidence/SKILL.md)。用实测提交和报告哈希区分不同轮次。
5. 用户授权合并或接续网页已合并的 PR 时，按 [PR 操作](../beecount-pr/SKILL.md) 核对合并结果及本次已解决的 Issue，再接续 [回收](../beecount-qa-cleanup/SKILL.md)。回收状态与 PR 证据交付状态分别记录。

同一机器由主 BeeCount checkout 持有登记位置。换会话先按轮次 ID 或 PR URL 查询状态，再继续第一项缺失的阶段。多个 run 使用同一个轮次 ID。具体命令见 [PR 验收交接](../isolated-app-cloud-qa/references/pr-lifecycle.md)。
