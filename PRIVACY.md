# Privacy Policy for BeeCount

**Last updated**: 2026-11-22

BeeCount ("we", "our", or "the app") is committed to protecting your privacy. This Privacy Policy explains how we handle your data when you use our application.

## TL;DR (Summary)

- Your bookkeeping records stay on your device by default. Cloud sync and AI use the services you configure.
- The official iOS App Store edition offers optional skin usage statistics, off by default.

---

## 1. Information We Collect

You can keep records locally without signing up.

Starting with version 4.0.1, the official App Store edition offers optional skin usage statistics on iOS 16 and later. If you turn on “Share skin usage statistics,” the app sends a randomly generated installation ID, a random event ID and an event type. Events cover opening the skin picker, previewing a skin, starting or cancelling a purchase, and a verified App Store purchase that unlocked the skins. The server records when it receives each event.

## 2. How We Store Your Data

### Local Storage
- All your accounting records are stored in a local SQLite database on your device
- Records stay on your device by default. If you enable cloud sync or AI, the app sends the data needed for those features to the services you configure.
- We cannot access, view, or retrieve your local data

### Cloud Storage (Optional)
If you choose to enable cloud synchronization, your data is stored in:

**Option 1: Custom Supabase Instance**
- You configure your own Supabase project
- Data is stored in YOUR Supabase account
- We do NOT have access to your Supabase credentials or data
- You control the data retention and deletion

**Option 2: WebDAV Server**
- You configure your own WebDAV server (NAS, Nextcloud, etc.)
- Data is stored on YOUR server
- We do NOT have access to your WebDAV credentials or data
- You have full control over the data

**BeeCount Cloud** is also available on servers you run yourself.

### Skin statistics (optional)

The statistics database deletes event records older than 90 days through a daily cleanup. Service provider recovery copies expire under the provider’s retention window. [Cloudflare D1 recovery and backups](https://developers.cloudflare.com/d1/reference/time-travel/).

## 3. Data Sharing

- If you enable **cloud sync**, data goes to the BeeCount Cloud, Supabase or WebDAV server you configure.
- If you enable **AI features**, the data needed for your request goes to the AI provider you configure (see Section 10).
- Skin statistics group events from the same installation to measure skin usage and purchase conversion. The records are kept separate from your ledgers, Apple Account, advertising identifier and purchase receipts. We use these records only for this analysis. Cloudflare hosts and processes the statistics and protects them under its Data Processing Addendum. [Cloudflare Data Processing Addendum](https://www.cloudflare.com/cloudflare-customer-dpa/).
- The Apple App Store handles in-app payments, restores and redemptions. [Apple Privacy Policy](https://www.apple.com/legal/privacy/).

## 4. Permissions We Request

The app requests the following Android permissions:

### Storage Permission (WRITE_EXTERNAL_STORAGE / READ_EXTERNAL_STORAGE)
- **Purpose**: To import/export CSV files for data backup
- **Optional**: You can still use the app without granting this permission
- **Scope**: Only accesses files you explicitly select

### Internet Permission (INTERNET)
- **Purpose**: To sync data with your own cloud service (if configured)
- **Optional**: The app works fully offline without this permission
- **Scope**: Connects to the cloud sync or AI services you configure to provide those features.

### Notification Permission (POST_NOTIFICATIONS)
- **Purpose**: To show app update download notifications
- **Optional**: Not required for core functionality

### Reminder Permission (SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM)
- **Purpose**: To send accounting reminders at the time you set
- **Optional**: Only requested if you enable the reminder feature

### iOS Permissions
- **Camera**: to capture payment receipts for AI recognition (only when you use it)
- **Microphone**: for voice bookkeeping (only when you use it)
- **Photo Library**: to import/share bill data files you select

## 5. Data Security

We use the following safeguards for your data.

- Local data is stored using SQLite with Android's built-in security
- Cloud sync uses HTTPS/TLS encryption when communicating with your servers
- Authentication credentials are stored securely using Android Keystore
- You can audit the public source code. [BeeCount repository](https://github.com/TNT-Likely/BeeCount).

## 6. Children's Privacy

BeeCount does not knowingly collect personal information from children under 13. Contact us privately by email if you believe we received such information.

## 7. Your Rights

You have complete control over your data:

- **Access**: All your data is in plain SQLite format, you can access it anytime
- **Portability**: Export your data to CSV format
- **Local deletion**: Uninstall the app or use the built-in data clearing feature.

You can turn off “Share skin usage statistics” in Mine → Personalization → Skin at any time. The app stops collecting new events and clears pending statistics on your device. You can still preview, buy, restore and use skins. The server deletes previously received events on the schedule in Section 2. You can email us to request access to or deletion of skin statistics data about your installation.

## 8. Open Source

BeeCount’s public source is available under the project’s software license. You can review the public code, build the app yourself from source and contribute improvements. Self-built versions from this repository can be used without the skin statistics service. [BeeCount repository](https://github.com/TNT-Likely/BeeCount).

## 9. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by:
- Posting the new Privacy Policy in the app
- Updating the "Last updated" date
- Publishing changes on our GitHub repository

## 10. Third-Party Services

The following optional features use third-party services you configure. Section 3 covers Apple App Store and skin statistics services.

### AI features (optional, off by default)
When you enable AI features and configure a provider, BeeCount sends — for the request you initiate — receipt/screenshot images, voice recordings, text you type, and the category names, account names and transaction records needed to complete recognition or analysis, to the AI provider you configured:
- **Zhipu GLM** (default, `open.bigmodel.cn`, operated by Zhipu) — subject to Zhipu's privacy policy.
- **Any other third-party AI service you configure** — subject to that provider's privacy policy.

AI is OFF by default and requires your own API key. The app shows an in-app notice naming the provider and the data involved, and asks for your consent, before any data is sent. BeeCount itself neither stores nor receives this data.

### Cloud sync (optional)
- **Supabase**: subject to [Supabase Privacy Policy](https://supabase.com/privacy)
- **WebDAV**: subject to your own server's privacy policy

## 11. Contact Us

If you have any questions about this Privacy Policy, please contact us:

- For privacy questions and data requests, contact us by email. [sunxiaoyes@outlook.com](mailto:sunxiaoyes@outlook.com).
- For public feedback, use [GitHub Issues](https://github.com/TNT-Likely/BeeCount/issues) or [GitHub Discussions](https://github.com/TNT-Likely/BeeCount/discussions).

---

## Privacy Policy (简体中文)

**蜜蜂记账隐私政策**

**最后更新时间**: 2026-11-22

### 简要说明

- 记账数据默认保存在你的设备。云同步与 AI 使用你自己配置的服务。
- 官方 iOS App Store 版提供可选的皮肤使用统计，默认关闭。

### 1. 信息收集

无需注册即可使用本地记账。

官方 iOS App Store 版自 4.0.1 起在 iOS 16 及以上提供可选的皮肤使用统计。开启「分享皮肤使用统计」后，App 会发送随机生成的安装标识、随机事件标识及事件类型。事件包括打开皮肤页面、试穿、发起购买、取消购买，以及经 App Store 验证并解锁的购买。服务器记录收到事件的时间。

### 2. 数据存储

**本地存储**
- 所有记账记录存储在您设备上的本地SQLite数据库中
- 记账数据默认保存在您的设备。启用云同步或 AI 后，应用会将所需数据发送给您配置的服务。
- 我们无法访问、查看或检索您的本地数据

**云存储（可选）**
如果您选择启用云同步，您的数据将存储在：

- **自定义Supabase实例**：存储在您自己的Supabase账户中
- **WebDAV服务器**：存储在您自己的服务器上

- **自建 BeeCount Cloud**。存储在您自己部署的服务器上。

**皮肤统计（可选）**。统计数据库每天清理超过 90 天的事件明细。云服务的恢复记录按供应商的保留期限到期。 [Cloudflare D1 恢复机制](https://developers.cloudflare.com/d1/reference/time-travel/)。

### 3. 数据共享

- 开启**云同步**后，数据会发送至你自己配置的 BeeCount Cloud、Supabase 或 WebDAV 服务器。
- 开启 **AI 功能**后，你发起的请求所需的数据会发送至你配置的第三方 AI 服务商。
- 皮肤统计使用随机标识汇总同一次安装的事件，以了解皮肤使用情况和购买转化。统计独立于账本、Apple 账户、设备广告标识和交易凭证。统计数据的用途仅限上述分析。Cloudflare 负责托管和处理统计数据，并按其数据处理附录保护这些数据。 [Cloudflare 数据处理附录](https://www.cloudflare.com/cloudflare-customer-dpa/)。
- 皮肤付款、恢复购买和兑换经由 Apple App Store 处理。 [Apple 隐私政策](https://www.apple.com/legal/privacy/szh/)。

**AI 功能(可选,默认关闭)**:开启并配置服务商后,蜜蜂记账会就你发起的请求,把账单/截图图片、语音录音、你输入的文字,以及完成识别/分析所需的分类名称、账户名称和相关交易记录,发送给你配置的服务商 —— 默认「智谱 GLM」(open.bigmodel.cn,智谱华章运营),或你自配的任意第三方 AI 服务商;各自适用其隐私政策。AI 默认关闭、需你自带 API Key;发送前 App 会以应用内提示点名服务商与所涉数据并征得你的同意。蜜蜂记账自身既不接收也不存储这些数据。

### 4. 权限请求

应用请求以下Android权限：

- **存储权限**：用于导入/导出CSV文件（可选）
- **网络权限**：用于与您自己的云服务同步（可选）
- **通知权限**：用于显示应用更新通知（可选）
- **提醒权限**：用于发送您设置的记账提醒（可选）

### 5. 你的权利

你可以导出记账数据为 CSV，也可以清除本地数据或卸载应用。

在「我的 → 个性化设置 → 皮肤」中可随时关闭「分享皮肤使用统计」。关闭后，App 停止收集新事件，并清除设备上待发送的统计事件。试穿、购买、恢复购买和使用已购皮肤均可照常进行。服务端留存的明细按上述期限清理。你也可以通过下方邮箱联系我们，提出有关访问或删除皮肤统计数据的请求。

### 6. 开源透明

蜜蜂记账依项目软件许可证开放源码。你可以查看公开代码、自行构建或提交改进。自行从该仓库构建的版本无需配置皮肤统计服务即可使用。 [BeeCount 仓库](https://github.com/TNT-Likely/BeeCount)。

### 7. 联系我们

- 隐私问题和数据请求可邮件联系。 [sunxiaoyes@outlook.com](mailto:sunxiaoyes@outlook.com)。
- 公开反馈可通过 [GitHub Issues](https://github.com/TNT-Likely/BeeCount/issues) 或 [GitHub Discussions](https://github.com/TNT-Likely/BeeCount/discussions) 提交。

---

**Your privacy is our priority. 您的隐私是我们的首要任务。🐝**
