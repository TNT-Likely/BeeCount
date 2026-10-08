# 发布流程

## 1. 核对发布范围与源码

查明本次是 App、Cloud 还是双端。用户已给出版本号时使用该版本；未指定时根据最近 Release 和实际变更提出建议，在最终发布前取得明确版本与范围。准备工作可以先执行，不因尚未批准 tag 而停在空白方案上。

分别读取当前仓的 workflow、`git status --short`、`git log origin/main..main`、最近已发布 tag 和 `<上一版>..<发布 SHA>`。不得把另一仓的版本序列用于当前仓；检查待发提交是否已合并，发布目标与远端一致且没有混入未审阅的改动。

相关路径可以显式提供。不要把 worktree 父目录当作所有仓库的公共父目录；先从 `git-common-dir` 定位原 checkout，再查找相邻仓并核对 remote。

## 2. 先完成可 review 的发布内容

按 [更新日志规范](changelogs.md) 准备 App 商店文案、Cloud 本地发布说明草稿、官网 App/Cloud 中英日志和功能页。日志项与真实提交区间对应；需要迁移、客户端配置调整或最低服务端版本时单独说明。

尚未发布时 Cloud 新变化留在 BeeCount 忽略的 `.docs/changelogs/cloud-<版本>.md` 草稿，未定版本时使用 `cloud-unreleased.md`，明确标记待发布。官网已发布列表只在相应 Release 成功后纳入该版本。若预先开官网 PR，说明它要等待对应 Release，不能把未发布功能先展示成已发布。

没有新功能的维护版本仍记录 Cloud 的日期、版本和关键修复或兼容性变化。App 官网亮点只增加新功能/行为变化，不为修复版硬凑亮点；App 商店文案和 Cloud 详细记录可包含修复。

准备完成后展示最终仓库、版本、SHA、内容摘要与实际命令。若本次授权已经明确覆盖这些动作，按既有授权执行；需要批准时把批准放在最后一步，不重复申请已有权限。

## 3. 触发发布

命令示例中的路径、版本和 SHA 都替换成本次核对值：

```sh
git -C <Cloud checkout> tag <Cloud-X.Y.Z> <已确认的Cloud-SHA>
git -C <Cloud checkout> push origin refs/tags/<Cloud-X.Y.Z>
git -C <App checkout> tag <App-X.Y.Z> <已确认的App-SHA>
git -C <App checkout> push origin refs/tags/<App-X.Y.Z>
```

只发布一端时仅执行该端。双端先确认 Cloud CI 和镜像可用，再触发 App。Cloud CI 产出 `sunxiao0721/beecount-cloud:<版本>`；App CI 注入版本并生成 Android/iOS 产物。是否自动发布 `latest`、tag 前缀和构建目标以当前 workflow 为准。

## 4. 核对 CI、Release 和官网

- 按确切 tag/工作流核对 Actions，不能以列表中某个无关绿色任务判断成功。
- 确认 GitHub Release 与镜像/安装包实际存在，版本和发布 SHA 正确。
- Cloud Release 若由 CI 自动生成提交列表，从本地发布说明草稿补入用户可读摘要及升级说明，保留已有 Docker、提交和贡献者记录；自动列表不替代发布说明。
- 相应版本发布成功后完成官网中英日志；功能页、侧栏和相关链接同步。官网按当前用户授权提交 PR 或合并发布，不默认直推 main。
- CI 失败时保留失败记录，修复后重跑对应任务；不删除、改写已经公开的 tag，不自动改发另一个版本。

## 5. 收尾

交付 App/Cloud 版本与 Release 链接、官网更新状态及日志文件。商店提审、生产 `docker compose pull` / `up -d` 由本次授权决定，数据库迁移提示以实际迁移为依据。宣传视频、社媒文案、issue 回复只在用户要求时执行。

双端新能力依赖 Cloud 时，在升级说明写清先服务端、后 App；服务端部署成功、CI 成功与商店审核通过分别记录，不混为同一状态。
