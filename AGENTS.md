# Agent Instructions

## Localization

- For localization changes, do not proactively translate new or changed strings into Korean (`app_ko.arb`), Traditional Chinese (`app_zh_TW.arb`), or Russian (`app_ru.arb`). Update those locales only when the user explicitly asks.
- Leave existing Korean, Traditional Chinese, and Russian translations unchanged unless the user asks to edit them.
- This preference applies to agent work; follow the project's localization generator and fallback behavior for untranslated entries.

## Git Workflow

- Commit messages must follow the project's Conventional Commits format and use Chinese for the subject and body.
- Pull request titles and descriptions must use Chinese. PR titles must follow the same Conventional Commits format as commit messages.

## Local Device Data

- Never run Flutter integration tests against the user's installed app package. Flutter uninstalls the application when integration tests finish, deleting its local data.
- Device integration tests must use a separate application ID or bundle ID, verified from the built artifact before installation. Otherwise use unit/widget tests and normal app runs.
- Preserve a private backup of the device database, preferences and attachments before any operation that can reinstall, clear or replace the app. Do not print credentials or commit backups.

## Delivery Workflow

处理 BeeCount 项目开发任务时，先读取 [开发流程](.agents/skills/beecount-delivery/SKILL.md) 并按任务授权分流。用户指定单独阶段时从对应 Skill 开始，实质 UI 改动先出 HTML。
