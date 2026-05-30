# 分类「跨类型同名」策略改造方案

> 让收入「红包」与支出「红包」这类**跨 kind 同名分类**共存。关联 [#118](https://github.com/TNT-Likely/BeeCount/issues/118)。
> 生成于 2026-05-30 · 范围:BeeCount(app) + BeeCount-Cloud(web/后端)。所有 file:line 已人工核实。

---

## 一、背景与目标

当前 **app 的分类是「name 全局唯一」**(一个名字只能属一个 kind),建不出收入「红包」+ 支出「红包」。而「红包 / 利息 / 报销 / 退款 / 借还」天然既能收又能支;主流记账软件(钱迹、随手记、MoneyWiz、YNAB)都按 `(name, kind)` 维度、允许跨类型同名。BeeCount 比行业更严,既是能力短板,也是 #118 的根因。

**目标策略:`(name, kind)` 联合唯一**(一级、二级统一,**不引入 parentId**)—— 同 kind 内禁止重名、跨 kind 允许同名。本质是在现有「name 全局唯一」上**只放开 kind**,改动最小。

> ⚠️ **硬约束**:seed 有 4 对跨父同名子类(见第二节),靠直接 insert 共存。因此**绝不能加 `UNIQUE(name,kind)` DB 约束**(会崩 seed 初始化),只保留应用层查重。手动建子类不能跨父同名(= 当前现状,零新增限制)。

**关键背景事实:**

- app `categories` 表**无唯一约束**(`lib/data/db.dart`),name 全局唯一仅由**应用层代码**保证 → 改造**不需要 schema 破坏性迁移**。
- 跨端同步靠 **`sync_id`**(name 仅显示) → 改 name 维度**不影响同步主链路**。
- **cloud 端早已是 `(name, kind)` 维度**(详见第三节 B) → 本质是**让 app 对齐 cloud**。
- app 同步 apply 建分类直接按 syncId insert、**绕过 name 校验** → cloud 建的跨 kind 同名分类**同步到 app 本地其实早就能并存**,name 全局唯一只是 app「主动建 / 导入」这几条路的遗留限制。

---

## 二、设计:目标行为

| 操作 | 改造前 | 改造后 |
|---|---|---|
| 同 kind 建重名 | 拒绝 | 拒绝(不变) |
| 跨 kind 建同名(收入红包 + 支出红包) | **拒绝** | **允许** |
| 导入 / 同步遇跨 kind 同名 | 复用错 / 跳过丢失 | 各自归位 |
| AI 记账匹配同名分类 | 只有一个可选 | 按交易 type 命中正确 kind |

判重维度:**全表 `(name, kind)` 唯一**(一级、二级同口径,不带 parentId)。

> **一个必须记住的坑(已核实 seed)** —— 那些 `_other` 子类显示名其实都带父后缀(「其他水果 / 其他娱乐 / 其他奖金…」),**各不相同、不冲突**(先前误判成同名「其他」,已更正)。但逐条数下来,seed 确有 **4 对跨父同名子类**(同 kind):
>
> - 支出:**饼干**(零食 / 糕点)、**配饰**(购物 / 服饰)
> - 收入:**年终奖**(工资 / 奖金)、**基金收益**(理财 / 投资收益)
>
> 它们靠 seed **直接 `db.insert` 绕过 name 校验**共存(从不报错、肉眼也看不出)。在全表 `(name, kind)` 唯一下:
>
> - **绝不能加 `UNIQUE(name, kind)` DB 约束** —— 这 4 对会让全新用户 seed 初始化崩溃。只保留应用层查重。
> - 用户手动建子类**不能跨父同名**(如已有「零食/饼干」就不能再建「糕点/饼干」)—— 但这 = 当前 name 全局唯一的现状(现状更严),**零新增限制**。
> - 想更干净可顺手把这 4 对 seed 改名区分(如「基金分红收益」),非必须。

---

## 三、场景全景与影响分析

> 逐个列出**所有**涉及「创建 / 查找 / 匹配 / 映射分类」的场景,标注 **❗需改** 或 **✅未受影响(排除)**,附关联代码与理由。

### A. App 端(BeeCount)

#### ❗ A1. 分类查重(主动建 / 撤销建 / get-or-create)— 核心改造

`lib/data/repositories/local/local_category_repository.dart`

| 方法 | 行 | 现状 | 改造 |
|---|---|---|---|
| `createCategory` | 38-47 | `c.name.equals(name)` 全局查重 | 加 `& c.kind.equals(kind)` |
| `createSubCategory` | 70-79 | 只按 name | 加 `& c.kind.equals(kind)`(与一级同口径,不带 parentId) |
| `upsertCategory` ⭐#118 根因 | 200-218 | 按 name get-or-create | 查重加 `& c.kind.equals(kind)` |
| `isCategoryNameDuplicate` | 253-266 | 只按 name | **新增 `kind` 参数**,按 `(name,kind)` |

```dart
// createCategory / upsertCategory 查重(示例)
// before
..where((c) => c.name.equals(name))
// after
..where((c) => c.name.equals(name) & c.kind.equals(kind))
```

连带:接口 `category_repository.dart`(`isCategoryNameDuplicate` 签名加 `kind`)、委托 `local_repository.dart`(透传 `kind`)、UI `category_edit_page.dart:~151`(`_checkNameDuplicate` 传当前 kind)。

#### ❗ A2. config YAML 导入 / 恢复 — 独立路径(举一反三发现)

`lib/services/export/config_export_service.dart` —— **自己 `batchInsertCategories` 建分类、不走 createCategory**:

| 点 | 行 | 现状 | 改造 |
|---|---|---|---|
| 一 / 二级分类去重集合 | 2470 / 2475 | `existingNames`(`c.name.toLowerCase()`)按 **name** 去重 → 跨 kind 同名第二个被当"已存在"**跳过丢失** | 去重集合 key 改 `(name.toLowerCase, kind)` |
| 父分类映射 `nameToIdMap` | 2465-2467 | `{c.name: c.id}` 按 name | key 改 `(name, kind)`(或 `(parentName, kind)`) |
| 周期账单 / 预算关联 `categoryNameToId` | 2599-2620 | `{c.name: c.id}` 按 name 关联 → 跨 kind 同名**关联到错的那个** | key 改 `(name, kind)`,关联项需带上 kind |

> 注:关联项(周期账单 / 预算)若导出数据里没带分类 kind,需补一并导出 kind 才能精确关联。

#### ❗ A3. 分类包导入 / 分享 — 独立路径(举一反三发现)

`lib/services/category_package_service.dart` —— 同样**自己 insert、按 name 去重**:

| 点 | 行 | 现状 | 改造 |
|---|---|---|---|
| 去重集合 `existingNames` | 187 / 238 / 270 | `c.name.toLowerCase()` 按 name | 改 `(name, kind)` |
| 直接建分类 `insertCategory` | 248 / 289 | 直接 insert(带 kind 字段,但去重按 name) | 去重改 `(name,kind)` 后即正确 |
| 父分类映射 `nameToId` | 265 | `{c.name.toLowerCase: c.id}` | 改 `(name, kind)` |

#### ✅ A4. CSV 导入 — 未受影响(底层修即覆盖)

`lib/services/data_import_service.dart` `importCategories`(263-360)**已按 `kind|name` 去重**;创建调 `repo.createCategory`。→ A1 改完即正确,**本身不用动**。`importTransactions`(478-489)用 `upsertCategory(name,kind)`,同样随 A1 修复。

#### ✅ A5. cloud 全量拉取(fullPull / diff)— 未受影响(底层修即覆盖,且修隐藏 bug)

`lib/cloud/transactions_sync_manager.dart`(`parseJsonToImportData`)→ `lib/cloud/sync_diff_service.dart:290` **复用 `DataImportService.importCategories`** → `createCategory`。→ 随 A1 修复。

> ⚠️ **隐藏 bug**:cloud 端已能有跨 kind 同名分类,旧 app fullPull 时 `createCategory` 会撞 name 抛 `DuplicateNameException`,可能导致拉取不全 —— A1 改完即修复。列为重点回归项。

#### ✅ A6. AI 记账匹配 — 未受影响(排除)

`bill_creation_service.dart:_matchCategory`(176-221)+ `category_matcher.dart`。入参 `categories` 来自 `_loadUsableCategories(transactionType)`(50 / 166-173,`getTopLevelCategories(kind)` 已按 kind 过滤),**只在当前 kind 内匹配**;匹配不到走 `_fallbackCategoryId`(224+)兜底"其他",**全程不创建分类**。→ 跨 kind 同名各自被对应 type 命中,改造后反而更准。

#### ✅ A7. 同步增量 apply — 未受影响(排除)

`lib/cloud/sync/sync_engine_apply.dart` 建分类直接按 `syncId` insert(绕过 name);`sync_engine_resolvers.dart` / `apply` 解析分类 syncId 优先、fallback 已带 kind。

#### ✅ A8. seed 默认分类 / orphan_seeder — 未受影响(排除)

`seed_service.dart`、`maintenance/orphan_seeder.dart` 直接 insert;默认分类名不重复 / 后者为维护工具,不涉同名冲突。

#### ✅ A9. 统计 / 分类迁移 — 未受影响(排除)

`watchCategoriesWithCount` 等按 `category_id` 聚合;`migrateCategoryTransactions`(469-474)已按 `(parentId, name, kind)`。

#### ✅ A10. DB schema — 无需迁移

`Categories` 表无唯一约束,放开 name 限制不改表结构。⚠️ **千万不要加 `UNIQUE(name, kind)` 约束** —— seed 有 4 对跨父同名子类(饼干 / 配饰 / 年终奖 / 基金收益)会直接违反、导致全新用户初始化崩溃。**保持现状不加 DB 约束**,由应用层查重保证。

---

### B. Cloud 端(BeeCount-Cloud)—— 基本已是目标状态

| # | 场景 | 代码 | 现状 | 影响 |
|---|---|---|---|---|
| B1 | 分类数据模型 | `src/models.py` `UserCategoryProjection` | PK=`(user_id, sync_id)`,**无 name 唯一约束** | ✅ 未受影响 |
| B2 | 创建 / 更新 API | `src/routers/write/categories.py` | 重名校验由 snapshot 按 `(name, kind)` | ✅ 未受影响 |
| B3 | 数据导入 | `src/services/import_data/stats.py:153` | 已按 `(name, kind)` 去重 | ✅ 未受影响 |
| B4 | 同步 applier | `src/sync_applier.py` `upsert_category` | 按 `sync_id` upsert;rename 按 syncId | ✅ 未受影响 |
| B5 | 前端重名校验 | `CategoriesPanel.tsx:570-579` | `if (row.kind !== form.kind) continue` 已按 `(name,kind)` | ✅ 未受影响 |
| B6 | 前端导入映射 | `TransactionsPanel.tsx` | 分类按 `(name,kind)` 分组、复用 / 新建按 `(name,kind)` | ✅ 未受影响 |
| B7 | AI 分类匹配 | `frontend/packages/api-client/src/ai.ts` | 疑似按 name 跨 kind 模糊匹配 | ⚠️ **待核对**(选做,影响小) |

**结论:cloud 端无需改动**(B1–B6 已支持),仅 B7 待核对。

---

## 四、改造清单汇总(只列需改)

| 端 | 文件 | 位置 | 改动 |
|---|---|---|---|
| app | `local_category_repository.dart` | createCategory / createSubCategory / upsertCategory / isCategoryNameDuplicate | 查重加 `kind` / 加 `kind` 参数 |
| app | `category_repository.dart` | isCategoryNameDuplicate 接口 | 签名加 `required String kind` |
| app | `local_repository.dart` | 委托 | 透传 `kind` |
| app | `category_edit_page.dart` | ~151 | 调用传 kind |
| app | `config_export_service.dart` | 2465 / 2470-2475 / 2599-2620 | 去重集合 + 两处 name→id 映射改 `(name,kind)` |
| app | `category_package_service.dart` | 187 / 238 / 265 / 270 | 去重 + 父映射改 `(name,kind)` |
| cloud | `ai.ts`(选做) | AI 匹配 | 收敛到 `(name,kind)` |

---

## 五、改造成本

| 项 | 量 | 说明 |
|---|---|---|
| app A1 核心查重 + 接口 + 委托 + UI | S | 集中、机械加 kind |
| app A2 config 导入 | S | 去重 + 2 处 name→id 映射(注意关联项要带 kind) |
| app A3 分类包 | S | 去重 + 父映射 |
| cloud | XS | 仅 B7 核对 |
| **回归测试** | **M** | 成本大头(尤其同步 / 导入) |

**合计:app S–M、cloud XS、测试 M。无 schema 迁移,存量零冲突。**

---

## 六、回归测试范围

### 分类 CRUD

- [ ] 同 kind 建重名 → 拒绝
- [ ] **跨 kind 建同名 → 允许**(支出红包 + 收入红包)
- [ ] 编辑「改图标不改名」→ 不误报(excludeId)
- [ ] 二级:同父同 kind 重名拒绝、跨 kind / 跨父允许

### 导入(覆盖 A2 / A3 / A4 / A5)

- [ ] **CSV** 含收 / 支同名分类 → 各自归位、方向正确(直接验 #118)
- [ ] **YAML 配置导入 / 恢复** 含跨 kind 同名 → 都建出、周期账单 / 预算关联到正确 kind(A2)
- [ ] **分类包导入** 含跨 kind 同名 → 都建出(A3)
- [ ] **cloud fullPull**:cloud 先有跨 kind 同名 → app 全量拉取正确并存、不撞名报错(A5 隐藏 bug)

### AI 记账

- [ ] 同名分类下,交易按 type 命中正确 kind

### 同步(最高风险)

- [ ] web 建跨 kind 同名 → 同步到 app 正确并存
- [ ] app 建跨 kind 同名 → 同步到 web 正确并存
- [ ] rename:只改目标 syncId 那条,不误伤同名异 kind
- [ ] 多设备:各建一个同名异 kind → 双向同步两端各两条、不互覆盖

### 统计 / 迁移

- [ ] 同名跨 kind 分类报表**分别统计**
- [ ] 老版本升级(无同名存量)→ 数据无变化

---

## 七、风险与数据迁移

| 风险 | 评估 | 缓解 |
|---|---|---|
| 同步串号 | 低(跨端靠 sync_id) | 重点测「同步」 |
| `upsertCategory` 影响导入 / AI 复用 | 中(#118 根因点) | 测「CSV / AI」 |
| config / 分类包关联项缺 kind | 中(A2 关联需导出数据带 kind) | 测「YAML / 分类包」,必要时补导出字段 |
| 存量数据冲突 | **零**(app 当前无同名存量) | 无需迁移 |
| cloud 已有同名 → 旧 app fullPull 撞名 | 已存在隐患,A5 改完即修 | 测「cloud fullPull」 |
| 误改"已正确"的点 | 低 | 第三节已逐个标 ✅ 排除 |

---

## 八、实施步骤

1. app A1(查重 4 方法 + 接口 + 委托 + UI)
2. app A2 / A3(config 导入、分类包:去重 + name→id 映射改 `(name,kind)`;按需补导出 kind)
3. 补单测:`local_category_repository_test`(跨 kind 同名建 / 查重)、`data_import_service_test`(#118 收支同名 CSV 分流)、config / 分类包导入测试
4. `flutter analyze` + 跑单测
5. cloud 核对 B7(ai.ts)
6. 按第六节回归(重点同步真机双端 + 各导入路径)
7. app 开 PR(关联 #118);cloud 如需改单独 PR
8. 合并后回 #118 说明已支持跨 kind 同名
