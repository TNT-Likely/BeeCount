# 蜜蜂记账（BeeCount）

> 中文 | [English](README.md)

**你的数据，你做主的开源记账应用**

一款轻量、开源、隐私可控的个人记账 App，支持 iOS/Android 双平台。内置完整的账本管理、分类统计、数据分析、导入导出功能，并支持自定义云备份。**核心优势：支持自定义 Supabase 后端，数据完全由你掌控。**

## 📱 产品演示

### 核心功能展示

<div align="center">
  <img src="demo/preview/zh/01-home.png" alt="首页主界面" width="200" />
  <img src="demo/preview/zh/02-search.png" alt="智能搜索" width="200" />
  <img src="demo/preview/zh/03-edit-transaction.png" alt="编辑交易" width="200" />
  <img src="demo/preview/zh/04-chart-analysis.png" alt="图表分析" width="200" />
</div>

<div align="center">
  <img src="demo/preview/zh/05-ledger-management.png" alt="账本管理" width="200" />
  <img src="demo/preview/zh/06-profile.png" alt="个人中心" width="200" />
  <img src="demo/preview/zh/07-category-detail.png" alt="分类详情" width="200" />
  <img src="demo/preview/zh/08-category-migration.png" alt="分类迁移" width="200" />
</div>

### 高级功能

<div align="center">
  <img src="demo/preview/zh/09-category-management.png" alt="分类管理" width="200" />
  <img src="demo/preview/zh/10-personalization.png" alt="个性装扮" width="200" />
  <img src="demo/preview/zh/11-cloud-service.png" alt="云服务" width="200" />
  <img src="demo/preview/zh/12-import-confirm.png" alt="导入确认" width="200" />
</div>

## 🌟 核心特性

### 🔒 数据安全与隐私

- **完全自主**：支持自定义 Supabase 后端，数据存储在你自己的项目中
- **开源透明**：代码完全开源，逻辑可审计，无黑箱操作
- **离线优先**：基于本地 SQLite 数据库，无网络也能正常记账
- **可选同步**：云同步是增强功能，不依赖外部服务也能完整使用

### 📊 完整记账功能

- **智能记账**：支持收入/支出分类、金额、日期、备注等完整信息
- **多账本管理**：创建多个账本，分别管理生活、工作等不同场景
- **分类统计**：自动生成月度收支报表、分类排行、趋势分析
- **数据分析**：直观的图表展示，帮助了解消费习惯和财务状况

### 🔄 数据管理

- **CSV 导入导出**：支持从其他记账应用迁移数据，或定期备份
- **云端备份**：可选择上传到自己的 Supabase 项目进行备份
- **多设备同步**：配置相同云服务即可在多设备间同步数据
- **分类迁移**：支持批量迁移交易记录到其他分类

### 🎨 个性化定制

- **主题装扮**：多种主题色彩可选，打造专属界面风格
- **多语言支持**：支持9种语言界面切换，包含主要国际语言
- **灵活配置**：可根据个人习惯调整各种使用偏好

### 🌍 国际化支持

- **已支持语言**：
  - 简体中文 🇨🇳
  - 繁体中文 🇨🇳
  - English 🇬🇧
  - 日本語 🇯🇵
  - 한국어 🇰🇷
  - Español 🇪🇸
  - Français 🇫🇷
  - Deutsch 🇩🇪
- **语言特性**：
  - 完整的界面翻译，包括所有菜单、按钮、提示信息
  - 智能的分类名称翻译和映射
  - 本地化的日期、数字格式显示
  - CSV 导入时自动识别和匹配多语言分类名称
  - 支持系统跟随或手动选择语言

> 如果你希望添加新的语言支持，欢迎在 Issues 中提出或直接提交 PR！

## 🚀 快速开始

### 方式一：直接安装（推荐）

1. 前往 [Releases](https://github.com/FBSocial/BeeCount/releases) 页面
2. 下载最新版本的 `app-prod-release-*.apk` 文件
3. 安装后即可开始使用（默认本地模式，无需任何配置）

### 方式二：自行构建

```bash
# 克隆项目
git clone https://github.com/FBSocial/BeeCount.git
cd BeeCount

# 安装依赖
flutter pub get
dart run build_runner build -d

# 运行应用
flutter run --flavor dev -d android --dart-define-from-file=assets/config.json
```

## 📖 使用说明

### 基础操作

- **添加记账**：点击首页底部的"+"按钮
- **编辑记录**：点击任意交易记录进入编辑页面
- **删除记录**：长按交易记录选择删除
- **切换月份**：点击顶部日期或在列表中上下滑动翻页
- **隐藏金额**：点击首页右上角眼睛图标

### 数据管理

- **导入数据**：个人中心 → 导入数据 → 选择 CSV 文件
- **导出备份**：个人中心 → 导出数据 → 选择导出格式
- **分类管理**：个人中心 → 分类管理 → 添加/编辑/删除分类
- **账本切换**：底部导航 → 账本 → 选择或创建新账本

## ☁️ 云备份配置（可选）

### 为什么选择自建云服务？

- **数据主权**：数据完全存储在你自己的 Supabase 项目中
- **隐私保护**：开发者无法访问你的任何数据
- **成本可控**：Supabase 免费额度足够个人使用
- **稳定可靠**：不依赖第三方托管服务

### 配置步骤

1. **创建 Supabase 项目**
   - 访问 [supabase.com](https://supabase.com) 注册账号
   - 创建新项目，选择合适的区域
   - 在项目设置中获取 URL 和 anon key

2. **配置 Storage**
   - 在 Supabase 控制台创建名为 `beecount-backups` 的 Storage Bucket
   - 设置为 Private 并配置 RLS 访问策略

3. **应用内配置**
   - 打开蜜蜂记账 → 个人中心 → 云服务
   - 选择"自定义云服务"
   - 填入你的 Supabase URL 和 anon key
   - 登录/注册后即可开始同步

详细配置指南请参考项目文档。

## 🛠️ 开发指南

### 技术栈

- **Flutter 3.27+**：跨平台 UI 框架
- **Riverpod**：状态管理解决方案
- **Drift (SQLite)**：本地数据库 ORM
- **Supabase**：云端备份和同步服务

### 项目结构

```
lib/
├── data/           # 数据模型和数据库操作
├── pages/          # 应用页面
├── widgets/        # 可复用组件
├── cloud/          # 云服务集成
├── l10n/           # 国际化资源
├── providers/      # Riverpod 状态提供者
└── utils/          # 工具函数
```

### 开发命令

```bash
# 安装依赖
flutter pub get

# 代码生成
dart run build_runner build --delete-conflicting-outputs

# 运行测试
flutter test

# 构建发布版本
flutter build apk --flavor prod --release
```

### 贡献指南

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: 添加某个功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

**提交规范**：使用中文提交信息，格式为 `类型: 简洁描述`

- `feat:` 新功能
- `fix:` 修复问题
- `refactor:` 代码重构
- `style:` 样式调整
- `docs:` 文档更新

## 📄 开源协议

本项目基于 [MIT 协议](LICENSE) 开源，你可以自由使用、修改和分发。

## ⚠️ 免责声明

- 本软件按"现状"提供，不提供任何明示或暗示的保证
- 使用本软件造成的数据丢失、经济损失等由使用者自行承担
- 请确保合法、合规地使用本软件

## 💬 常见问题

**Q: 不配置云服务能正常使用吗？**
A: 完全可以！应用默认使用本地存储，所有功能都能正常使用。你仍可随时导出 CSV 进行备份。

**Q: 配置自定义云服务后还能切回默认模式吗？**
A: 可以随时切换。已保存的自定义配置不会丢失，可以再次启用。

**Q: 如何确保数据安全？**
A: 建议使用自己的 Supabase 项目，配置正确的访问策略，定期导出 CSV 备份，使用强密码并开启两步验证。

**Q: 支持哪些数据格式？**
A: 目前支持 CSV 格式的导入导出，兼容大部分主流记账应用的数据格式。

**Q: 如何在多设备间同步数据？**
A: 在所有设备上配置相同的 Supabase URL 和 anon key，登录同一账号即可自动同步。

---

## 🙏 致谢

感谢所有为蜜蜂记账项目贡献代码、提出建议和反馈问题的朋友们！

如有问题或建议，欢迎在 [Issues](https://github.com/FBSocial/BeeCount/issues) 中提出，或在 [Discussions](https://github.com/FBSocial/BeeCount/discussions) 中参与讨论。

**蜜蜂记账 🐝 - 让记账变得简单而安全**
