# BeeCount &nbsp; [中文](README.md)

<div align="center">

![GitHub stars](https://img.shields.io/github/stars/TNT-Likely/BeeCount?style=social)
![License](https://img.shields.io/badge/license-Business%20Source%20License-orange.svg)
![Release](https://img.shields.io/github/v/release/TNT-Likely/BeeCount?label=latest&color=green)
![Downloads](https://img.shields.io/github/downloads/TNT-Likely/BeeCount/total?color=blue)
![Last commit](https://img.shields.io/github/last-commit/TNT-Likely/BeeCount)
![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-02569B?logo=flutter)

**Your Data, Your Control — Open Source Accounting App**

Sync via BeeCount Cloud (self-hosted) / iCloud / Supabase / WebDAV / S3

<br/>

<a href="https://apps.apple.com/app/id6754611670">
  <img src="https://img.shields.io/badge/App%20Store-000000?style=for-the-badge&logo=app-store&logoColor=white" alt="Download on App Store" height="64"/>
</a>
<a href="https://play.google.com/store/apps/details?id=com.tntlikely.beecount">
  <img src="https://img.shields.io/badge/Google%20Play-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Get it on Google Play" height="64"/>
</a>
<a href="https://github.com/TNT-Likely/BeeCount-Cloud/blob/main/README.en.md">
  <img src="https://img.shields.io/badge/Web%20(Self--Hosted)-4A90E2?style=for-the-badge&logo=docker&logoColor=white" alt="Self-host Web" height="64"/>
</a>

<br/>
<br/>

[🌐 Website](https://count.beejz.com/en/) · [📖 Docs](https://count.beejz.com/en/docs/intro) · [💝 Donate](#-donate) · [💬 Telegram](https://t.me/beecount) · [📦 APK](https://github.com/TNT-Likely/BeeCount/releases/latest) · [🚀 TestFlight](https://testflight.apple.com/join/Eaw2rWxa)

</div>

---

> 🤖 **New: [MCP](https://count.beejz.com/en/docs/mcp) support** — pair with [BeeCount Cloud](https://github.com/TNT-Likely/BeeCount-Cloud) to drive your ledger from any MCP client.

---

## 💡 Why BeeCount

A lightweight, open-source, privacy-first **personal finance** and **expense tracking** app.

| Traditional apps | BeeCount |
|---|---|
| ❌ Data on third-party servers, no audit | ✅ **Fully open-source**, code auditable |
| ❌ Privacy may be analyzed and exploited | ✅ **Offline-first** + self-hosted, developer can't access your data |
| ❌ Service shutdown = data loss | ✅ **Data sovereignty**, choose from 5 sync options |
| ❌ Premium features behind paywalls | ✅ **Completely free** (including AI / OCR / voice input) |
| ❌ Ads / financial product recommendations | ✅ **Zero ads / zero tracking / zero data collection** |

> **Platform support**: 🤖 Android 5.0+ · 🍎 iOS 15.5+ · 🌐 Web (built into BeeCount Cloud, see below)
>
> ~~📱 HarmonyOS — [Discontinued](https://github.com/TNT-Likely/beecount-openharmony)~~

---

## 🌟 Core Features

<details>
<summary><b>🤖 AI-Powered</b> — AI assistant / OCR / voice / auto-capture from screenshots</summary>

- **AI Assistant** — Natural language conversation, intent recognition, powered by Zhipu GLM-4
- **OCR Photo Capture** — Dual engines (local TFLite + GLM cloud), recognizes Alipay/WeChat/UnionPay screenshots
- **Voice Input** — Hold to speak, GLM models understand colloquial expressions
- **Auto Capture from Screenshots** — Android accessibility service / iOS Shortcuts back-tap

</details>

<details>
<summary><b>📝 Bookkeeping</b> — multi-ledger / accounts / categories / budgets / recurring / tags / charts / import-export</summary>

- **Multi-ledger** — Separate ledgers for life/work/investment, each with its own currency
- **Multiple accounts** — Cash/card/credit, transfer auto-updates both balances
- **Two-tier categories** — Parent-child hierarchy
- **Budgets** — Total + category budgets, overspending alerts
- **Recurring transactions** — Daily/weekly/monthly/yearly auto-records for fixed income/expenses
- **Tags** — Multi-tag with color labels for flexible filtering
- **Charts** — Monthly reports / category rankings / trends / annual report
- **Import/Export** — CSV (Alipay/WeChat bills) + YAML config

</details>

<details>
<summary><b>🎨 Experience</b> — dark mode / 3 languages / home widgets / theming</summary>

- **Dark mode** — Pure black + theme accent borders, OLED-friendly
- **3 languages** — Simplified/Traditional Chinese, English, with localized formatting
- **Home widgets** — iOS / Android quick-record widgets
- **Theme customization** — Multiple primary colors

</details>

---

## 📸 Screenshots

<div align="center">
  <img src="demo/videos/en/01-add-transaction.gif" alt="Add transaction" width="200" />
  <img src="demo/videos/en/02-ocr-recognition.gif" alt="AI OCR" width="200" />
  <img src="demo/videos/en/04-data-analysis.gif" alt="Analytics" width="200" />
</div>

<details>
<summary>More screenshots (9 themes / dark mode)</summary>

### 9 Core Themes

<div align="center">
  <img src="assets/store/screenshots/raw/en/01-home.png" alt="Home" width="200" />
  <img src="assets/store/screenshots/raw/en/02-open-source.png" alt="Cloud Service" width="200" />
  <img src="assets/store/screenshots/raw/en/03-analytics.png" alt="Analytics" width="200" />
</div>

<div align="center">
  <img src="assets/store/screenshots/raw/en/04-ai.png" alt="AI Smart Logging" width="200" />
  <img src="assets/store/screenshots/raw/en/05-add.png" alt="Quick Entry" width="200" />
  <img src="assets/store/screenshots/raw/en/06-ledgers.png" alt="Multi-Ledger" width="200" />
</div>

<div align="center">
  <img src="assets/store/screenshots/raw/en/07-tags.png" alt="Color Tags" width="200" />
  <img src="assets/store/screenshots/raw/en/08-accounts.png" alt="Net Worth" width="200" />
  <img src="assets/store/screenshots/raw/en/09-mine.png" alt="Settings" width="200" />
</div>

### Dark Mode

<div align="center">
  <img src="demo/preview/dark/01-home.png" alt="Home dark" width="200" />
  <img src="demo/preview/dark/02-chart-analysis.png" alt="Charts dark" width="200" />
  <img src="demo/preview/dark/04-profile.png" alt="Profile dark" width="200" />
  <img src="demo/preview/dark/05-ai-chat.png" alt="AI chat dark" width="200" />
</div>

</details>

---

## ☁️ Sync Options

BeeCount offers 5 sync options. Your data, your control. **See [docs/cloud-setup_EN.md](docs/cloud-setup_EN.md) for full setup guides.**

| Option | Best For | Highlights |
|---|---|---|
| **BeeCount Cloud** | Real-time multi-device + self-hosted + multi-user co-write | One-click Docker, sub-second sync, built-in Web, multi-user, **shared ledgers** |
| **iCloud** | iOS-only users | Zero config, native integration |
| **Supabase** | Cross-platform without NAS | Generous free tier, easy setup |
| **WebDAV** | NAS users | Local data, Synology/UGREEN/Nextcloud |
| **S3 protocol** | Flexible cloud storage | Cloudflare R2/AWS S3/MinIO, large free tier |

> 🔐 **Why self-host?** Privacy first, cost control, data security, fully open-source. All sync code is auditable.

---

## 🆕 BeeCount Cloud (Self-hosted)

> **Sub-second multi-device sync + Web admin + multi-user isolation + AES-256 encrypted backup** — Recommended for users with NAS / VPS / Docker.

### Highlights

- 📱 **Real-time multi-device** — Phone A makes a change, Phone B and Web see it within seconds (WebSocket)
- 🌐 **Built-in Web admin** — One Docker image = server + web; open server URL to use
- 👥 **Multi-user isolation** — One server, many user accounts, each only sees their own data
- 🤝 **Shared ledgers** — Owner generates an invite code; family / team join the same book. Owner / Editor roles, realtime sync, every transaction tagged with creator + last editor, plus member balance stats. iOS / Android / Web all supported.
- 🔐 **AES-256 encrypted backup** — Multi-remote fan-out (R2 / S3 / WebDAV / B2), AES zip encryption — recoverable with standard tools even without the service

### Deploy + Full Documentation

Full Docker Compose deployment, backup system, PWA, and ops details live in the Cloud repo:

**[👉 BeeCount-Cloud repo — One-click Docker deploy + full docs](https://github.com/TNT-Likely/BeeCount-Cloud)**

### Web Admin Preview

<div align="center">
  <img src="demo/preview/web/en-01-home.png" alt="Web home" width="600" />
  <br/>
  <sub>💰 Home: income/expense, asset breakdown, category heatmap, trends — at a glance (dark mode)</sub>
</div>

<details>
<summary>More Web screenshots</summary>

<div align="center">
  <img src="demo/preview/web/en-02-transactions.png" alt="Web transactions" width="600" />
  <br/>
  <sub>📒 Transactions: keyword / category / account / date / tag multi-filter</sub>
</div>

<br/>

<div align="center">
  <img src="demo/preview/web/en-03-devices.png" alt="Web devices" width="600" />
  <br/>
  <sub>📱 Online devices + backup archive management</sub>
</div>

</details>

---

## 🛠️ Development

<details>
<summary>Tech stack + quick start</summary>

### Tech Stack

- **Flutter 3.27+** · Cross-platform UI framework
- **Riverpod** · State management
- **Drift (SQLite)** · Local database ORM
- **Supabase / Self-hosted BeeCount Cloud / WebDAV / S3** · Multi-option cloud sync

### Quick Start

```bash
# Install dependencies
flutter pub get

# Code generation
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run --flavor dev

# Build release
flutter build apk --flavor prod --release
```

See [docs/contributing/CONTRIBUTING.md](docs/contributing/CONTRIBUTING.md) for development conventions.

</details>

---

## 🤝 Contributing

<details>
<summary>All contributions welcome</summary>

- 🐛 [Report a bug](https://github.com/TNT-Likely/BeeCount/issues/new)
- 💡 [Feature request](https://github.com/TNT-Likely/BeeCount/discussions/new?category=ideas)
- 💻 [Code](docs/contributing/CONTRIBUTING.md#code-contribution-flow) · 🌍 [Translation](docs/contributing/CONTRIBUTING.md#translation-contributions) · 📝 [Docs](docs/contributing/CONTRIBUTING.md#documentation-contributions) · 🎨 [Designer recruitment](docs/contributing/CONTRIBUTING.md#designer-recruitment)

**Quick start**: Fork → create feature branch → commit → PR. See the [full contributing guide](docs/contributing/CONTRIBUTING.md) for details.

</details>

---

## 💬 FAQ

<details>
<summary>Common questions</summary>

**Q: Can I use it without configuring cloud services?**
A: Absolutely! The app uses local storage by default. All features work normally. You can export CSV for backup anytime.

**Q: Which sync option should I pick?**
A:
- iOS single device → **iCloud** (zero config)
- Cross-platform + real-time multi-device → **BeeCount Cloud** (self-hosted, recommended)
- Cross-platform without NAS → **Supabase / S3**
- Have a NAS → **WebDAV**

**Q: How is data security ensured?**
A: Use your own server / Storage / Bucket. WebDAV and S3 should use HTTPS. BeeCount Cloud backups are AES-256 encrypted by default.

For more details, see [docs/cloud-setup_EN.md](docs/cloud-setup_EN.md) or [Issues](https://github.com/TNT-Likely/BeeCount/issues).

</details>

---

## 💝 Donate

BeeCount is completely free and open-source — **no ads, no paid features**. If you find it useful, buy the developer a coffee ☕ to support continued development.

### How to Donate

[![PayPal](https://img.shields.io/badge/PayPal-Donate-0070BA?logo=paypal&logoColor=white&style=for-the-badge)](https://paypal.me/sunxiaoyes)

<details><summary>Alipay / WeChat QR codes</summary>

| Alipay | WeChat Pay |
|:---:|:---:|
| <img src="docs/donate/alipay.png" width="160" alt="Alipay"/> | <img src="docs/donate/wechat.png" width="160" alt="WeChat"/> |

</details>

**USDT (TRC20)**: `TKBV69B2AoU67p3vDhnJUbMJtZ1DxuUF5C` · <details><summary>Binance QR code</summary>![Binance](docs/donate/binance.png)</details>

### Cost Transparency

| Item | Amount |
|---|---|
| Apple Developer Account renewal | ¥688 / year |
| Lightweight cloud server (ICP filing) | ¥79 / year |
| Domain | ¥80 / year |
| Google Play Developer Account (one-time) | ¥177 |
| **Annual recurring cost** | **¥847 / year** |

### Supporters

| | | | | | | | | | | | |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| <img src="assets/avatars/qiao.svg" width="44"/> | <img src="assets/avatars/rui.svg" width="44"/> | <a href="https://github.com/fishdivinity"><img src="assets/avatars/fishdivinity.png" width="44"/></a> | <img src="assets/avatars/shao.svg" width="44"/> | <img src="assets/avatars/ge.svg" width="44"/> | <img src="assets/avatars/te.svg" width="44"/> | <img src="assets/avatars/wen.svg" width="44"/> | <img src="assets/avatars/anon.svg" width="44"/> | <a href="https://github.com/birdnofoots"><img src="https://github.com/birdnofoots.png" width="44"/></a> | <a href="https://github.com/charieswang72-pro"><img src="https://github.com/charieswang72-pro.png" width="44"/></a> | <a href="https://github.com/542474846"><img src="https://github.com/542474846.png" width="44"/></a> | <a href="https://github.com/JOHN-2025"><img src="https://github.com/JOHN-2025.png" width="44"/></a> |
| *Qiao ¥12 | *Rui ¥720 | fishdivinity ¥100 | *Shao ¥15 | *Ge ¥6 | *Te ¥15 | *Wen ¥50 | Anonymous ¥50 | birdnofoots ¥10 | Charies ¥10 | 542474846 ¥66 | JOHN-2025 ¥30 |

> 💡 Already donated? [Submit info](https://github.com/TNT-Likely/BeeCount/issues/new?template=donation_info.yml) to be displayed in the list.

---

## 📄 License

This project uses the **Business Source License (BSL)**.

| Use Case | License |
|---|---|
| ✅ **Personal / learning / open-source contribution** | Completely free |
| ❌ **Commercial use** | Requires paid license |

<details>
<summary>What counts as commercial use</summary>

- Providing this software as a commercial product or service to customers
- Using it in a for-profit organization
- Building commercial products on top of this software
- Offering paid cloud services based on this software

For commercial licensing, please contact via [GitHub Issues](https://github.com/TNT-Likely/BeeCount/issues). See [LICENSE](LICENSE) for details.

</details>

---

## 📦 Related Repositories

| Repository | Description |
|---|---|
| [BeeCount-Cloud](https://github.com/TNT-Likely/BeeCount-Cloud) | Self-hosted sync server + Web admin (FastAPI + React) |
| [BeeCount-Website](https://github.com/TNT-Likely/BeeCount-Website) | Website / docs repo |
| [beecount-openharmony](https://github.com/TNT-Likely/beecount-openharmony) | HarmonyOS version (discontinued) |
| [BeeShot](https://github.com/TNT-Likely/BeeShot) | App Store screenshot generator |

---

## ⭐ Star History

<details>
<summary>View Star history chart</summary>

<a href="https://www.star-history.com/?repos=tnt-likely%2Fbeecount&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=tnt-likely/beecount&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=tnt-likely/beecount&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=tnt-likely/beecount&type=date&legend=top-left" />
 </picture>
</a>

</details>

---

## 🙏 Acknowledgments

Thanks to [Guhe Bake (Internet Pure Land)](https://www.ghxi.com/) and [Star Mochen](https://mp.weixin.qq.com/s/HieVbKzpdUvnoaCa_9xjkA) for promoting this project.

Thanks to everyone who has contributed code, suggestions, or feedback to BeeCount!

For questions or suggestions, please raise an [Issue](https://github.com/TNT-Likely/BeeCount/issues) or join the [Discussions](https://github.com/TNT-Likely/BeeCount/discussions).

**BeeCount 🐝 — Making accounting simple and secure**
