# 贡献指南

感谢你考虑为蜜蜂记账做出贡献！🎉

这份指南将帮助你了解如何参与项目开发、报告问题、提交代码等。我们欢迎所有形式的贡献，无论是代码、文档、翻译还是建议。

## 📋 目录

- [行为准则](#行为准则)
- [我能做什么贡献？](#我能做什么贡献)
- [报告 Bug](#报告-bug)
- [提出新功能建议](#提出新功能建议)
- [代码贡献流程](#代码贡献流程)
- [开发环境设置](#开发环境设置)
- [代码规范](#代码规范)
- [提交信息规范](#提交信息规范)
- [Pull Request 流程](#pull-request-流程)
- [翻译贡献](#翻译贡献)
- [文档贡献](#文档贡献)
- [问题和讨论](#问题和讨论)

## 行为准则

### 我们的承诺

为了营造一个开放、友好的环境，我们作为贡献者和维护者承诺：让参与项目和社区的每个人都享有无骚扰的体验，无论其年龄、体型、残疾、种族、性别认同和表达、经验水平、国籍、个人形象、种族、宗教或性取向如何。

### 我们的标准

有助于创造积极环境的行为包括：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同理心

### 执行

不可接受的行为可以通过联系项目团队 sunxiaoyes@outlook.com 来报告。所有投诉都将被审查和调查，并将做出必要且适当的回应。

## 我能做什么贡献？

### 🐛 报告 Bug

发现了问题？请通过 [GitHub Issues](https://github.com/TNT-Likely/BeeCount/issues) 告诉我们。

### 💡 提出新功能

有好的想法？我们很乐意听到！请先查看 [Issues](https://github.com/TNT-Likely/BeeCount/issues) 和 [Discussions](https://github.com/TNT-Likely/BeeCount/discussions) 看看是否已经有人提出。

### 💻 贡献代码

- 修复 Bug
- 实现新功能
- 优化性能
- 重构代码

### 📝 完善文档

- 改进 README
- 补充使用教程
- 添加代码注释
- 编写 Wiki 页面

### 🌍 贡献翻译

帮助我们将应用翻译成更多语言，让更多人能够使用。

### 🎨 设计贡献

- UI/UX 改进建议
- 图标设计
- 截图和宣传素材

#### 🎨 招募设计师 {#designer-recruitment}

**我们正在寻找有才华的 UI/UX 设计师加入蜜蜂记账项目！**

📐 **参与内容：**

- 重新设计应用 UI 和交互体验
- 设计主题皮肤和插画元素
- 优化用户界面的视觉一致性
- 创建现代化、简洁的设计语言

🎁 **你将获得：**

- 开源项目作品集积累
- 在 README 和应用中署名
- 与开发团队密切合作的机会
- 为数千用户打造优质体验的成就感

💌 **联系方式：**

- GitHub Issues: [提交设计建议](https://github.com/TNT-Likely/BeeCount/issues)
- Telegram: [加入讨论群](https://t.me/beecount)

## 报告 Bug

### 提交前检查

在提交 Bug 报告前，请先：

1. 检查 [FAQ](https://github.com/TNT-Likely/BeeCount/wiki/常见问题-FAQ) 看看问题是否已有解决方案
2. 搜索 [现有 Issues](https://github.com/TNT-Likely/BeeCount/issues) 确认问题未被报告
3. 确保你使用的是最新版本

### 如何报告

创建 Issue 时请包含以下信息：

**Bug 描述**
- 简短清晰地描述 Bug
- 预期行为是什么
- 实际发生了什么

**复现步骤**
1. 打开应用
2. 点击 '...'
3. 输入 '...'
4. 看到错误

**环境信息**
- 操作系统：[如 Android 13, iOS 16.5]
- 设备型号：[如 Pixel 7, iPhone 14]
- 应用版本：[如 v0.1.5]
- 云服务配置：[Supabase / WebDAV / 本地模式]

**截图或日志**
如果可以，请提供截图或错误日志。

**示例 Issue**

```markdown
**Bug 描述**
在添加交易时，如果金额超过 6 位数，保存按钮无响应。

**复现步骤**
1. 打开应用，点击 "+" 添加交易
2. 选择任意分类
3. 输入金额 1000000
4. 点击保存按钮
5. 没有任何反应，交易未保存

**预期行为**
应该能够保存大额交易，或者显示金额限制提示。

**环境信息**
- 操作系统：Android 13
- 设备：小米 13
- 应用版本：v0.1.5
- 云服务：本地模式

**截图**
[附上截图]
```

## 提出新功能建议

我们欢迎新功能建议！在提交前：

1. 检查 [Discussions](https://github.com/TNT-Likely/BeeCount/discussions) 中的"Ideas"分类
2. 确认功能符合项目定位（隐私优先、开源、自托管）
3. 考虑功能的实用性和普遍性

### 功能建议模板

```markdown
**功能描述**
简短描述你希望添加的功能。

**使用场景**
描述这个功能解决什么问题，在什么情况下使用。

**建议的实现方式**（可选）
如果你有技术建议，请详细说明。

**替代方案**（可选）
是否考虑过其他解决方案？

**附加信息**
其他相关信息、参考链接或截图。
```

## 代码贡献流程

### 1. Fork 仓库

点击 GitHub 页面右上角的 "Fork" 按钮，将仓库 fork 到你的账号下。

### 2. Clone 到本地

```bash
git clone https://github.com/你的用户名/BeeCount.git
cd BeeCount
```

### 3. 添加上游仓库

```bash
git remote add upstream https://github.com/TNT-Likely/BeeCount.git
```

### 4. 创建功能分支

```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/your-bug-fix
```

分支命名规范：
- `feature/功能名` - 新功能
- `fix/问题描述` - Bug 修复
- `refactor/模块名` - 重构
- `docs/文档名` - 文档更新

### 5. 开发和测试

- 遵循[代码规范](#代码规范)
- 编写必要的注释
- 测试你的更改

### 6. 提交更改

```bash
git add .
git commit -m "feat: 添加某个功能"
```

遵循[提交信息规范](#提交信息规范)。

### 7. 同步上游更改

```bash
git fetch upstream
git rebase upstream/main
```

### 8. 推送到你的 Fork

```bash
git push origin feature/your-feature-name
```

### 9. 创建 Pull Request

1. 访问你的 Fork 仓库页面
2. 点击 "Compare & pull request"
3. 填写 PR 描述（见[下文](#pull-request-流程)）
4. 提交 PR

## 开发环境设置

### 系统要求

- **Flutter SDK**: 3.27.0 或更高版本
- **Dart SDK**: 3.6.0 或更高版本
- **IDE**: VS Code 或 Android Studio（推荐安装 Flutter 插件）
- **操作系统**: macOS, Linux, 或 Windows

### 安装步骤

1. **安装 Flutter**

访问 [Flutter 官网](https://flutter.dev/docs/get-started/install) 按照指引安装。

验证安装：
```bash
flutter doctor
```

2. **Clone 项目**

```bash
git clone https://github.com/TNT-Likely/BeeCount.git
cd BeeCount
```

3. **安装依赖**

```bash
flutter pub get
```

4. **运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

5. **运行应用**

```bash
# Android
flutter run --flavor dev -d android

# iOS
flutter run -d ios
```

**注意**: 云服务配置通过应用内 UI 完成（个人中心 → 云服务），无需配置文件。

### 项目结构

```
lib/
├── data/              # 数据层
│   ├── db.dart       # 数据库定义
│   ├── models/       # 数据模型
│   └── repository.dart # 数据仓库
├── pages/            # UI 页面
│   ├── home/         # 首页
│   ├── charts/       # 图表页
│   ├── ledgers/      # 账本页
│   └── mine/         # 个人中心
├── widgets/          # 通用组件
│   ├── ui/           # UI 基础组件
│   └── biz/          # 业务组件
├── cloud/            # 云服务
│   ├── supabase_auth.dart
│   └── supabase_sync.dart
├── l10n/             # 国际化资源
├── providers.dart    # Riverpod 状态管理
├── styles/           # 主题样式
└── utils/            # 工具函数
```

### 常用命令

```bash
# 运行测试
flutter test

# 代码格式化
dart format .

# 静态分析
flutter analyze

# 构建 APK
flutter build apk --flavor prod --release

# 重新生成代码
dart run build_runner build --delete-conflicting-outputs

# 监听文件变化自动生成
dart run build_runner watch
```

## 代码规范

### Dart 代码风格

遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 规范：

1. **命名规范**
   - 类名：`PascalCase`
   - 函数/变量：`camelCase`
   - 常量：`lowerCamelCase`（Dart 惯例）
   - 私有成员：以 `_` 开头

2. **格式化**
   - 使用 `dart format` 自动格式化
   - 行宽限制 80 字符
   - 使用 2 空格缩进

3. **注释**
   - 公共 API 使用 `///` 文档注释
   - 复杂逻辑添加行内注释
   - 避免无意义的注释

```dart
/// 计算指定月份的收支总额
///
/// [ledgerId] 账本ID
/// [year] 年份
/// [month] 月份（1-12）
/// 返回包含收入和支出的Map
Future<Map<String, double>> calculateMonthlyTotal(
  int ledgerId,
  int year,
  int month,
) async {
  // 实现...
}
```

4. **空安全**
   - 充分利用 Dart 的空安全特性
   - 避免使用 `!` 强制解包，使用 `?.` 和 `??`
   - 函数参数使用 `required` 或提供默认值

### Flutter 组件规范

1. **Widget 结构**
   - 优先使用 `const` 构造函数
   - 将大型 Widget 拆分为小组件
   - 使用 `build` 方法返回单一 Widget

2. **状态管理**
   - 使用 Riverpod 管理状态
   - Provider 命名以 `Provider` 结尾
   - 避免在 Widget 中直接操作数据库

```dart
final ledgersProvider = FutureProvider<List<Ledger>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getAllLedgers();
});
```

3. **性能优化**
   - 使用 `const` Widget
   - 避免在 `build` 方法中创建新对象
   - 合理使用 `ListView.builder`

### 数据库规范

1. **Drift 表定义**
   - 表名使用复数（`Transactions`, `Categories`）
   - 字段名使用 camelCase
   - 添加必要的索引

```dart
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  TextColumn get description => text().nullable()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

2. **查询优化**
   - 使用索引加速查询
   - 避免 N+1 查询
   - 使用流式查询响应数据变化

## 提交信息规范

我们使用基于 [约定式提交](https://www.conventionalcommits.org/zh-hans/) 的提交规范，**使用中文**。

### 格式

```
<类型>: <简短描述>

[可选的详细描述]

[可选的脚注]
```

### 类型

- `feat`: 新功能
- `fix`: Bug 修复
- `refactor`: 代码重构（不改变功能）
- `style`: 代码格式调整（不影响功能）
- `perf`: 性能优化
- `test`: 添加或修改测试
- `docs`: 文档更新
- `chore`: 构建过程或辅助工具的变动
- `ci`: CI/CD 配置修改
- `revert`: 回滚之前的提交

### 示例

```bash
# 新功能
git commit -m "feat: 添加预算功能"

# Bug 修复
git commit -m "fix: 修复云同步时数据丢失的问题"

# 带详细描述
git commit -m "refactor: 重构数据库查询逻辑

- 优化索引使用
- 减少冗余查询
- 提升查询性能约 30%"

# 文档更新
git commit -m "docs: 更新 Supabase 配置文档"

# 性能优化
git commit -m "perf: 优化首页列表渲染性能"
```

### 注意事项

- 使用中文描述
- 简短描述不超过 50 字符
- 使用祈使句（"添加"而非"添加了"）
- 详细描述说明"为什么"而非"是什么"

## Pull Request 流程

### PR 标题

遵循提交信息规范，如：
- `feat: 添加多币种支持`
- `fix: 修复 WebDAV 同步失败问题`

### PR 描述模板

```markdown
## 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 文档更新
- [ ] 代码重构
- [ ] 性能优化
- [ ] 其他

## 变更说明
简要描述这个 PR 做了什么。

## 相关 Issue
Closes #123

## 测试情况
- [ ] 已在 Android 上测试
- [ ] 已在 iOS 上测试
- [ ] 添加了单元测试
- [ ] 添加了集成测试

## 截图（如适用）
[附上截图或 GIF]

## 检查清单
- [ ] 代码遵循项目规范
- [ ] 已运行 `dart format` 格式化代码
- [ ] 已运行 `flutter analyze` 无警告
- [ ] 已更新相关文档
- [ ] 提交信息符合规范
```

### 审核流程

1. **自动检查**
   - CI/CD 构建通过
   - 代码格式检查通过
   - 静态分析无错误

2. **代码审查**
   - 维护者会审查你的代码
   - 可能会要求修改
   - 请及时回复评论

3. **合并**
   - 审查通过后会被合并
   - 你的贡献会出现在下一个版本中

### PR 最佳实践

- **保持 PR 小而专注**：一个 PR 只做一件事
- **及时更新**：与主分支保持同步
- **响应评论**：积极回复审查意见
- **完善测试**：确保新功能有足够的测试覆盖
- **更新文档**：功能变更要同步更新文档

## 翻译贡献

蜜蜂记账官方维护 3 种语言（简体中文、繁体中文、English），并接受社区贡献的其他语言翻译。欢迎贡献新语言或改进现有翻译。

### 当前支持的语言

**官方维护：**

- 简体中文 (zh)
- 繁体中文 (zh_Hant)
- English (en)

**社区贡献：**

- 한국어 / 韩语 (ko)

### 添加新语言

1. **创建翻译文件**

在 `lib/l10n/` 目录下创建新的 `.arb` 文件：

```
lib/l10n/app_<语言代码>.arb
```

例如添加意大利语：
```
lib/l10n/app_it.arb
```

2. **复制模板**

复制 `app_en.arb` 的内容，翻译所有字符串：

```json
{
  "appName": "BeeCount",
  "home": "Casa",
  "charts": "Grafici",
  "ledgers": "Conti",
  "mine": "Mio",
  ...
}
```

3. **测试翻译**

```bash
flutter pub get
flutter run
```

在应用设置中切换到新语言，检查翻译效果。

4. **提交 PR**

```bash
git add lib/l10n/app_it.arb
git commit -m "feat: 添加意大利语翻译"
git push origin feature/add-italian-translation
```

### 改进现有翻译

如果发现翻译错误或可以改进的地方：

1. 编辑对应的 `.arb` 文件
2. 提交 PR，说明修改原因

## 文档贡献

### 文档类型

1. **README**: 项目介绍和快速开始
2. **Wiki**: 详细使用教程
3. **代码注释**: API 文档
4. **贡献指南**: 本文档

### 文档规范

1. **语言**
   - README 提供中英双语版本
   - Wiki 主要使用中文
   - 代码注释使用中文

2. **格式**
   - 使用 Markdown 格式
   - 遵循 [Markdown 风格指南](https://google.github.io/styleguide/docguide/style.html)
   - 添加目录和章节链接

3. **内容**
   - 清晰简洁
   - 提供示例代码
   - 添加截图说明
   - 保持更新

### 更新文档

发现文档问题或需要补充？

1. Fork 仓库
2. 编辑文档文件
3. 提交 PR

示例：
```bash
git checkout -b docs/improve-supabase-guide
# 编辑文档
git commit -m "docs: 完善 Supabase 配置说明"
git push origin docs/improve-supabase-guide
```

## 问题和讨论

### 何时使用 Issues

- 报告 Bug
- 提出功能请求
- 询问特定的技术问题

### 何时使用 Discussions

- 一般性讨论
- 分享使用经验
- 寻求帮助
- 头脑风暴

### 社区交流

- [GitHub Discussions](https://github.com/TNT-Likely/BeeCount/discussions) - 项目讨论
- [V2EX 帖子](https://www.v2ex.com/t/1168480) - 中文社区
- Email: sunxiaoyes@outlook.com - 直接联系

## 认可贡献者

所有贡献者都会被记录在项目的贡献者列表中。重大贡献会在 Release Notes 中特别感谢。

## 许可证

通过贡献代码，你同意你的贡献将按照项目的 [MIT License](../../LICENSE) 进行许可。

---

再次感谢你的贡献！🙏

如有任何问题，欢迎通过 [Issues](https://github.com/TNT-Likely/BeeCount/issues) 或 [Discussions](https://github.com/TNT-Likely/BeeCount/discussions) 与我们联系。
