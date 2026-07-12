# Contributing Guide

Thank you for considering contributing to BeeCount! 🎉

This guide will help you understand how to participate in the project development, report issues, submit code, and more. We welcome all forms of contributions, whether it's code, documentation, translations, or suggestions.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [What Can I Contribute?](#what-can-i-contribute)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting New Features](#suggesting-new-features)
- [Code Contribution Workflow](#code-contribution-workflow)
- [Development Environment Setup](#development-environment-setup)
- [Code Standards](#code-standards)
- [Commit Message Convention](#commit-message-convention)
- [Pull Request Process](#pull-request-process)
- [Translation Contributions](#translation-contributions)
- [Documentation Contributions](#documentation-contributions)
- [Questions and Discussions](#questions-and-discussions)

## Code of Conduct

### Our Pledge

In the interest of fostering an open and welcoming environment, we as contributors and maintainers pledge to make participation in our project and our community a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

Examples of behavior that contributes to creating a positive environment include:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

### Enforcement

Instances of unacceptable behavior may be reported by contacting the project team at sunxiaoyes@outlook.com. All complaints will be reviewed and investigated and will result in a response that is deemed necessary and appropriate to the circumstances.

## What Can I Contribute?

### 🐛 Report Bugs

Found an issue? Please let us know through [GitHub Issues](https://github.com/TNT-Likely/BeeCount/issues).

### 💡 Suggest New Features

Have a great idea? We'd love to hear it! Please check [Issues](https://github.com/TNT-Likely/BeeCount/issues) and [Discussions](https://github.com/TNT-Likely/BeeCount/discussions) first to see if someone has already suggested it.

### 💻 Contribute Code

- Fix bugs
- Implement new features
- Optimize performance
- Refactor code

### 📝 Improve Documentation

- Enhance README
- Add tutorials
- Write code comments
- Create Wiki pages

### 🌍 Contribute Translations

Help us translate the app into more languages so more people can use it.

### 🎨 Design Contributions

- UI/UX improvement suggestions
- Icon design
- Screenshots and promotional materials

#### 🎨 Designer Recruitment {#designer-recruitment}

**We're looking for talented UI/UX designers to join the BeeCount project!**

📐 **What You'll Work On:**

- Redesign app UI and interaction experience
- Create theme skins and illustration elements
- Optimize visual consistency across the interface
- Develop a modern, clean design language

🎁 **What You'll Get:**

- Portfolio pieces for open-source work
- Credit in README and app
- Close collaboration with dev team
- Satisfaction of creating great UX for thousands of users

💌 **Contact:**

- GitHub Issues: [Submit design proposals](https://github.com/TNT-Likely/BeeCount/issues)

## Reporting Bugs

### Before Submitting

Before submitting a bug report, please:

1. Check the [FAQ](https://github.com/TNT-Likely/BeeCount/wiki/FAQ) to see if there's already a solution
2. Search [existing Issues](https://github.com/TNT-Likely/BeeCount/issues) to confirm the bug hasn't been reported
3. Ensure you're using the latest version

### How to Report

When creating an Issue, please include:

**Bug Description**
- Brief and clear description of the bug
- What was the expected behavior
- What actually happened

**Steps to Reproduce**
1. Open the app
2. Click on '...'
3. Enter '...'
4. See error

**Environment Information**
- OS: [e.g., Android 13, iOS 16.5]
- Device Model: [e.g., Pixel 7, iPhone 14]
- App Version: [e.g., v0.1.5]
- Cloud Service: [Supabase / WebDAV / Local mode]

**Screenshots or Logs**
If possible, please provide screenshots or error logs.

**Example Issue**

```markdown
**Bug Description**
When adding a transaction, if the amount exceeds 6 digits, the save button becomes unresponsive.

**Steps to Reproduce**
1. Open the app, tap "+" to add transaction
2. Select any category
3. Enter amount 1000000
4. Tap save button
5. Nothing happens, transaction not saved

**Expected Behavior**
Should be able to save large amount transactions, or display amount limit warning.

**Environment Information**
- OS: Android 13
- Device: Xiaomi 13
- App Version: v0.1.5
- Cloud Service: Local mode

**Screenshots**
[Attach screenshot]
```

## Suggesting New Features

We welcome feature suggestions! Before submitting:

1. Check the "Ideas" category in [Discussions](https://github.com/TNT-Likely/BeeCount/discussions)
2. Ensure the feature aligns with project goals (privacy-first, open-source, self-hosted)
3. Consider the feature's practicality and universality

### Feature Suggestion Template

```markdown
**Feature Description**
Brief description of the feature you'd like to add.

**Use Case**
Describe what problem this feature solves and when it would be used.

**Suggested Implementation** (optional)
If you have technical suggestions, please detail them.

**Alternatives** (optional)
Have you considered other solutions?

**Additional Information**
Other relevant information, reference links, or screenshots.
```

## Code Contribution Workflow

### 1. Fork the Repository

Click the "Fork" button in the top right corner of the GitHub page to fork the repository to your account.

### 2. Clone to Local

```bash
git clone https://github.com/your-username/BeeCount.git
cd BeeCount
```

### 3. Add Upstream Repository

```bash
git remote add upstream https://github.com/TNT-Likely/BeeCount.git
```

### 4. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

Branch naming convention:
- `feature/feature-name` - New features
- `fix/issue-description` - Bug fixes
- `refactor/module-name` - Refactoring
- `docs/doc-name` - Documentation updates

### 5. Develop and Test

- Follow [Code Standards](#code-standards)
- Write necessary comments
- Test your changes

### 6. Commit Changes

```bash
git add .
git commit -m "feat: add some feature"
```

Follow the [Commit Message Convention](#commit-message-convention).

### 7. Sync Upstream Changes

```bash
git fetch upstream
git rebase upstream/main
```

### 8. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 9. Create Pull Request

1. Visit your fork repository page
2. Click "Compare & pull request"
3. Fill in PR description (see [below](#pull-request-process))
4. Submit PR

## Development Environment Setup

### System Requirements

- **Flutter SDK**: 3.27.0 or higher
- **Dart SDK**: 3.6.0 or higher
- **IDE**: VS Code or Android Studio (Flutter plugin recommended)
- **OS**: macOS, Linux, or Windows

### Installation Steps

1. **Install Flutter**

Visit [Flutter Official Site](https://flutter.dev/docs/get-started/install) and follow the instructions.

Verify installation:
```bash
flutter doctor
```

2. **Clone Project**

```bash
git clone https://github.com/TNT-Likely/BeeCount.git
cd BeeCount
```

3. **Install Dependencies**

```bash
flutter pub get
```

4. **Run Code Generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

5. **Run Application**

```bash
# Android
flutter run --flavor dev -d android

# iOS
flutter run -d ios
```

**Note**: Cloud service configuration is done through the app's UI (Profile → Cloud Service). No configuration file needed.

### Project Structure

```
lib/
├── data/              # Data layer
│   ├── db.dart       # Database definitions
│   ├── models/       # Data models
│   └── repository.dart # Data repository
├── pages/            # UI pages
│   ├── home/         # Home page
│   ├── charts/       # Charts page
│   ├── ledgers/      # Ledgers page
│   └── mine/         # Profile page
├── widgets/          # Reusable components
│   ├── ui/           # UI base components
│   └── biz/          # Business components
├── cloud/            # Cloud services
│   ├── supabase_auth.dart
│   └── supabase_sync.dart
├── l10n/             # Internationalization
├── providers.dart    # Riverpod state management
├── styles/           # Theme styles
└── utils/            # Utility functions
```

### Common Commands

```bash
# Run tests
flutter test

# Format code
dart format .

# Static analysis
flutter analyze

# Build APK
flutter build apk --flavor prod --release

# Regenerate code
dart run build_runner build --delete-conflicting-outputs

# Watch file changes and auto-generate
dart run build_runner watch
```

## Code Standards

### Dart Code Style

Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

1. **Naming Conventions**
   - Class names: `PascalCase`
   - Functions/Variables: `camelCase`
   - Constants: `lowerCamelCase` (Dart convention)
   - Private members: prefix with `_`

2. **Formatting**
   - Use `dart format` for auto-formatting
   - 80 character line limit
   - Use 2-space indentation

3. **Comments**
   - Use `///` for public API documentation
   - Add inline comments for complex logic
   - Avoid meaningless comments

```dart
/// Calculate total income and expenses for a specific month
///
/// [ledgerId] Ledger ID
/// [year] Year
/// [month] Month (1-12)
/// Returns a Map containing income and expenses
Future<Map<String, double>> calculateMonthlyTotal(
  int ledgerId,
  int year,
  int month,
) async {
  // Implementation...
}
```

4. **Null Safety**
   - Fully utilize Dart's null safety features
   - Avoid using `!` force unwrap, use `?.` and `??`
   - Function parameters use `required` or provide default values

### Flutter Component Standards

1. **Widget Structure**
   - Prefer `const` constructors
   - Break large widgets into smaller components
   - `build` method returns a single widget

2. **State Management**
   - Use Riverpod for state management
   - Provider names end with `Provider`
   - Avoid direct database operations in widgets

```dart
final ledgersProvider = FutureProvider<List<Ledger>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getAllLedgers();
});
```

3. **Performance Optimization**
   - Use `const` widgets
   - Avoid creating new objects in `build` method
   - Properly use `ListView.builder`

### Database Standards

1. **Drift Table Definitions**
   - Table names use plural (`Transactions`, `Categories`)
   - Field names use camelCase
   - Add necessary indexes

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

2. **Query Optimization**
   - Use indexes to speed up queries
   - Avoid N+1 queries
   - Use streaming queries to respond to data changes

## Commit Message Convention

We use a commit convention based on [Conventional Commits](https://www.conventionalcommits.org/), **in Chinese**.

### Format

```
<type>: <short description>

[optional detailed description]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring (no functionality change)
- `style`: Code formatting (no functionality impact)
- `perf`: Performance optimization
- `test`: Add or modify tests
- `docs`: Documentation updates
- `chore`: Build process or auxiliary tool changes
- `ci`: CI/CD configuration changes
- `revert`: Revert previous commit

### Examples

```bash
# New feature
git commit -m "feat: 添加预算功能"

# Bug fix
git commit -m "fix: 修复云同步时数据丢失的问题"

# With detailed description
git commit -m "refactor: 重构数据库查询逻辑

- 优化索引使用
- 减少冗余查询
- 提升查询性能约 30%"

# Documentation update
git commit -m "docs: 更新 Supabase 配置文档"

# Performance optimization
git commit -m "perf: 优化首页列表渲染性能"
```

### Notes

- Use Chinese descriptions
- Short description under 50 characters
- Use imperative mood ("add" not "added")
- Detailed description explains "why" not "what"

## Pull Request Process

### PR Title

Follow commit message convention, e.g.:
- `feat: 添加多币种支持`
- `fix: 修复 WebDAV 同步失败问题`

### PR Description Template

```markdown
## Change Type
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Code refactoring
- [ ] Performance optimization
- [ ] Other

## Change Description
Brief description of what this PR does.

## Related Issue
Closes #123

## Testing
- [ ] Tested on Android
- [ ] Tested on iOS
- [ ] Added unit tests
- [ ] Added integration tests

## Screenshots (if applicable)
[Attach screenshots or GIFs]

## Checklist
- [ ] Code follows project standards
- [ ] Ran `dart format` to format code
- [ ] Ran `flutter analyze` with no warnings
- [ ] Updated relevant documentation
- [ ] Commit messages follow convention
```

### Review Process

1. **Automated Checks**
   - CI/CD build passes
   - Code format check passes
   - Static analysis without errors

2. **Code Review**
   - Maintainers will review your code
   - May request changes
   - Please respond to comments promptly

3. **Merge**
   - Will be merged after review approval
   - Your contribution will appear in the next release

### PR Best Practices

- **Keep PRs small and focused**: One PR does one thing
- **Stay updated**: Keep in sync with main branch
- **Respond to comments**: Actively reply to review feedback
- **Comprehensive testing**: Ensure new features have adequate test coverage
- **Update documentation**: Sync documentation with feature changes

## Translation Contributions

BeeCount officially maintains 3 languages (Simplified Chinese, Traditional Chinese, English), plus additional community-contributed translations. We welcome contributions of new languages or improvements to existing ones.

### Currently Supported Languages

**Officially maintained:**

- Simplified Chinese (zh)
- Traditional Chinese (zh_Hant)
- English (en)

**Community-contributed:**

- 한국어 / Korean (ko)

### Adding a New Language

1. **Create Translation File**

Create a new `.arb` file in the `lib/l10n/` directory:

```
lib/l10n/app_<language_code>.arb
```

For example, adding Italian:
```
lib/l10n/app_it.arb
```

2. **Copy Template**

Copy the content of `app_en.arb` and translate all strings:

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

3. **Test Translation**

```bash
flutter pub get
flutter run
```

Switch to the new language in app settings and check the translation.

4. **Submit PR**

```bash
git add lib/l10n/app_it.arb
git commit -m "feat: 添加意大利语翻译"
git push origin feature/add-italian-translation
```

### Improving Existing Translations

If you find translation errors or areas for improvement:

1. Edit the corresponding `.arb` file
2. Submit a PR explaining the reason for the change

## Documentation Contributions

### Documentation Types

1. **README**: Project introduction and quick start
2. **Wiki**: Detailed usage tutorials
3. **Code Comments**: API documentation
4. **Contributing Guide**: This document

### Documentation Standards

1. **Language**
   - README provides both Chinese and English versions
   - Wiki primarily in Chinese
   - Code comments in Chinese

2. **Format**
   - Use Markdown format
   - Follow [Markdown Style Guide](https://google.github.io/styleguide/docguide/style.html)
   - Add table of contents and section links

3. **Content**
   - Clear and concise
   - Provide code examples
   - Add explanatory screenshots
   - Keep updated

### Updating Documentation

Found documentation issues or need to add content?

1. Fork the repository
2. Edit documentation files
3. Submit a PR

Example:
```bash
git checkout -b docs/improve-supabase-guide
# Edit documentation
git commit -m "docs: 完善 Supabase 配置说明"
git push origin docs/improve-supabase-guide
```

## Questions and Discussions

### When to Use Issues

- Report bugs
- Request features
- Ask specific technical questions

### When to Use Discussions

- General discussions
- Share experiences
- Seek help
- Brainstorming

### Community Communication

- [GitHub Discussions](https://github.com/TNT-Likely/BeeCount/discussions) - Project discussions
- [V2EX Thread](https://www.v2ex.com/t/1168480) - Chinese community
- Email: sunxiaoyes@outlook.com - Direct contact

## Recognizing Contributors

All contributors will be recorded in the project's contributor list. Significant contributions will be specially acknowledged in Release Notes.

## License

By contributing code, you agree that your contributions will be licensed under the project's [MIT License](../../LICENSE).

---

Thank you again for your contribution! 🙏

If you have any questions, feel free to contact us through [Issues](https://github.com/TNT-Likely/BeeCount/issues) or [Discussions](https://github.com/TNT-Likely/BeeCount/discussions).
