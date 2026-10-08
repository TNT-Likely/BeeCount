# App / Cloud 更新日志

## 文件职责

| 内容 | 位置 | 是否提交 |
|---|---|---|
| App Store / Google Play 可粘贴文案 | BeeCount `.docs/changelogs/<App版本>.txt` | 否 |
| Cloud 版本摘要及升级说明 | BeeCount-Cloud `CHANGELOG.md` | 是 |
| App 官网亮点 | BeeCount-Website `docs/changelog.md` | 是 |
| Cloud 官网发布历史 | BeeCount-Website `docs/cloud-changelog.md` | 是 |
| 官网英文镜像 | `i18n/en/docusaurus-plugin-content-docs/current/` 下同名页面 | 是 |

App 与 Cloud 使用独立版本序列。App 页面可以说明某项 App 能力最低需要哪个 Cloud 版本，但不要把 Cloud 发布条目写成 App 版本亮点。

## Cloud 每次发布

1. 根据上一个已发布 tag 到本次目标 SHA 的提交，归纳用户可感知变化和升级影响。
2. 在 `CHANGELOG.md` 的 `Unreleased` 准备内容；确定版本后形成对应版本记录。写明新功能、关键修复、兼容性/配置/迁移影响，不把开发工具调整包装成用户能力。
3. 核对真实 Release 成功后，记录 GitHub `publishedAt` 的 UTC 日期和确切 Release 链接。CI 自动提交列表与此版本的摘要都要保留。
4. 官网中文和英文 Cloud 页面同步对应版本；纯修复版本可以是一句维护摘要，不强行写功能亮点。
5. 若涉及 App 升级顺序或最低版本，同步相关功能/部署页面；核对来源，无法确认时不推测数字。

官网格式建议：`## <版本> · <YYYY-MM-DD>`，下方 1–4 条变化和一个版本 Release 链接。已有链接及锚点尽量保留。Cloud 列表不包含仅合并到 main 的未发布功能。

## 历史补录

从 `gh release list/view --repo TNT-Likely/BeeCount-Cloud` 的版本、日期、正文取得事实；必要时读取对应 tag 的 README、提交 diff 或 compare 区间。不要按当前代码回填到早期版本。核心发布可精选，未逐条补录的维护版保留完整 Releases 入口。

补录时不重打 tag、不编辑历史 Release、不改发布日期。中文和英文涵盖相同版本与变化，注意 MCP 1.5.3 的传输层升级等需要迁移配置的版本。

## App 文案

保留既有单文件两段格式：第一段按简体中文、繁體中文、English 提供 App Store 文案；第二段为 Google Play 的 `<en-US>`、`<zh-CN>`、`<zh-HK>`。Google Play 中不包含纯 iOS 条目，两种商店都不写自建服务端运维内容。

这是商店文案，不要求修改 App 的韩文/繁体 ARB 翻译。只做本次用户授权的文案和 locale 变更。

## 核对

确认 App/Cloud 版本归属、真实发布时间与 Release 链接、中英镜像和侧栏入口、升级说明、未发布项归属。官网构建可用于检查 Markdown 链接与两种语言页面；如本次需要运行构建或人工页面验收，记录实际结果及范围。记录准备完成、Release 成功和官网上线三个不同状态。
