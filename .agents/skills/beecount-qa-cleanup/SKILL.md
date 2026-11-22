---
name: beecount-qa-cleanup
description: 按 BeeCount QA 轮次或 PR 核对并回收已登记的隔离验收环境，适用于 Agent 合并成功、接续网页合并或用户明确结束验收。
---

# BeeCount 验收回收

使用主 BeeCount checkout 的 `scripts/qa/pr_lifecycle.py cleanup <轮次或规范 PR URL>` 查看当前清理清单。已确认合并后自动回收本轮时使用 `--apply`。只有用户明确结束验收时使用 `--end-review`。明确保留用 `keep <轮次> on`。网页合并后的项目接续可用 `reconcile --apply` 核对登记的待回收轮次。

脚本只针对已登记的私有 run。保持 run 标记及 manifest，记录准确的 UDID / AVD、受保护设备和服务 PID 身份。合并条件使用各关联 PR 的 GitHub 实际状态。独立的验收 HTML、ZIP 和回执保存在运行目录外。准备失败的轮次允许清理已确认归属的资源。

引用 [完整清理规则](../isolated-app-cloud-qa/references/cleanup.md) 处理脚本尚未覆盖的已登记资源。只关闭本轮专用浏览器 profile 或明确属于本轮的标签页。保留正式账本、真机、其他项目设备及共享缓存。逐项回读，报告已移除和待处理。目录不存在或端口被复用时，根据运行标记和已记录结果核验，禁止按设备名或目录前缀批量删除。
