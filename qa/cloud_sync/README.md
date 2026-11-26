# BeeCount Cloud 双向同步基线

同步引擎、账本写入、附件、Cloud 投影或数据库迁移变更时，从 App 仓库运行这套验收。它通过真实 HTTP 在临时 SQLite 和 PostgreSQL 上迁移并启动指定版本的 Cloud，使用正式 Flutter 同步引擎、独立 App 数据库和合成文件。宿主测试覆盖设置控制器、Web 写 API 与文件下载。设备 UI 和浏览器表单另走项目的隔离验收流程。

## 本地和 CI

需要 Flutter 3.27.3、Python 3.12 或更新版本、安装了 Cloud requirements 的虚拟环境，以及 PostgreSQL 的 `initdb` 和 `pg_ctl`。Cloud checkout 的 `.venv` 可直接复用，也可指定 `--cloud-python`、`--postgres-bin`。脚本为每轮创建数据库、私有文件目录、账号与服务，不连接已有 Cloud。

```sh
python3 scripts/qa/cloud_sync_baseline.py run --database both \
  --cloud-repo ../BeeCount-Cloud --cloud-ref <Cloud提交> --output /tmp/beecount-sync-result
```

输出目录必须是新的。每轮记录两仓提交、App 工作区状态、数据库实际版本与时区、样本数量、种子和各组耗时。结束后打开 `index.html`，或者解压 `cloud-sync-results.zip`。测试失败时命令仍继续其他组，返回非零并保留相应私有日志目录。修复后可用同一 `--seed`，加 `--case upload`、`pull`、`relations`、`contracts` 或 `mode` 重跑。原始数据库、凭证和运行日志留在私有目录。GitHub Actions 的「Cloud 双向同步基础 QA」仅手动触发，两种数据库各自出具结果。

## 核心用例

| 用例 | 初始状态与校验 |
|---|---|
| 全量上传 | 从待传队列为空的历史账本开始。按同步 ID 将本地 A、Cloud 网页读接口、完整快照和空设备 B 与独立业务预期逐笔比较；再同步检查重复事件。 |
| 增量上传 | 已有共同基线后增删改交易、层级、预算和标签，核对受影响的事件、余额、预算用量和未编辑交易。 |
| 全量拉取 | 通过网页写接口准备两本个人账和全部交易；从空库、未选当前账本、有其他账本及待传修改的本地状态恢复。 |
| 增量拉取 | 每个规模使用独立账号，依次验证 499、500、501、1,001 个可见事件，检查跨页依赖、删除和显式清空。第 1,000 项应用失败时整页回滚，再从已提交游标恢复。 |
| 附件与断线 | 12 张合成原图、24 处引用，网页给父分类改名，A 离线移除标签和一处小票引用。服务器提交后丢失一次响应，由 A 重试；B 冷恢复并清缓存，从 Cloud 重下原件后离线按 SHA-256 核对。 |
| 共享与恢复 | 编辑成员与拥有者有同名分类和标签，按拥有者的资源 ID 核对交易。覆盖同设备重装、独立旧操作晚于删除到达、全量快照游标、切换本地存储后切回 Cloud。当前邀请入口只提供编辑者角色。 |

固定账本包含 48 笔代表交易，其余按种子补足到 1,200 笔，含 8 个父类、16 个子类、12 枚标签、6 个账户、3 种货币，以及总预算和分类预算。另用独立账号覆盖共享角色、文件和故障时序。新增真实缺陷时，用原始操作恢复问题，留下修复前后结果；用最小回归锁定根因，再放入相应的四向或组合用例。

## 发版前专项

容量使用同一套逐笔业务断言，记录全量上传和空设备恢复耗时，分别选择 `--transactions 10000` 和 `50000`。跨版本探针可编译上一发行版 App 与当前 Cloud 配对，也可让当前 App 连接上一发行版 Cloud。

```sh
python3 scripts/qa/cloud_sync_baseline.py run --suite capacity --transactions 10000 --cloud-repo ../BeeCount-Cloud
python3 scripts/qa/cloud_sync_baseline.py run --suite compatibility --app-ref 4.0.1 --cloud-repo ../BeeCount-Cloud
python3 scripts/qa/cloud_sync_baseline.py run --suite compatibility --cloud-ref 1.10.1 --cloud-repo ../BeeCount-Cloud
```

发版验收时另登记 iOS、Android 和网页实际操作过的入口、包和设备。宿主结果可与设备报告一起链接到 PR。

旧版 Cloud 若在空库迁移失败，应保留失败报告。另起一轮，加 `--suite compatibility --cloud-ref 1.10.1 --provisioning-ref <已修复迁移的提交>`，可模拟已经安装的旧服务。脚本从旧版代码读取其最后一个 Alembic 版本，只建到该版本，然后启动指定的旧版服务。报告分别记录运行代码、建库代码和实际数据库版本，便于区分首次部署和已有实例的升级兼容性。
