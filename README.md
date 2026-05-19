# 蜜蜂记账(BeeCount) &nbsp; [English](README_EN.md)

<div align="center">

![GitHub stars](https://img.shields.io/github/stars/TNT-Likely/BeeCount?style=social)
![License](https://img.shields.io/badge/license-Business%20Source%20License-orange.svg)
![Release](https://img.shields.io/github/v/release/TNT-Likely/BeeCount?label=latest&color=green)
![Downloads](https://img.shields.io/github/downloads/TNT-Likely/BeeCount/total?color=blue)
![Last commit](https://img.shields.io/github/last-commit/TNT-Likely/BeeCount)
![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-02569B?logo=flutter)

**你的数据,你做主的开源记账应用**

支持 BeeCount Cloud 自建云端 / iCloud / Supabase / WebDAV / S3 五种同步方案

<br/>

<a href="https://apps.apple.com/app/id6754611670">
  <img src="https://img.shields.io/badge/App%20Store-000000?style=for-the-badge&logo=app-store&logoColor=white" alt="Download on App Store" height="64"/>
</a>
<a href="https://play.google.com/store/apps/details?id=com.tntlikely.beecount">
  <img src="https://img.shields.io/badge/Google%20Play-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Get it on Google Play" height="64"/>
</a>
<a href="https://github.com/TNT-Likely/BeeCount-Cloud">
  <img src="https://img.shields.io/badge/Web%20(Self--Hosted)-4A90E2?style=for-the-badge&logo=docker&logoColor=white" alt="Self-host Web" height="64"/>
</a>

<br/>
<br/>

[🌐 官网](https://count.beejz.com) · [📖 文档](https://count.beejz.com/docs/intro) · [💝 捐赠](#-捐赠支持) · [💬 Telegram](https://t.me/beecount) · [📦 APK](https://github.com/TNT-Likely/BeeCount/releases/latest) · [🚀 TestFlight](https://testflight.apple.com/join/Eaw2rWxa)

</div>

---

> 🤖 **新:[MCP](https://count.beejz.com/docs/mcp) 支持** — 搭配 [BeeCount Cloud](https://github.com/TNT-Likely/BeeCount-Cloud),用 LLM 直接管账本。

---

## 💡 为什么选择蜜蜂记账

一款轻量、开源、隐私可控的**个人财务管理**和**支出追踪** App。

| 传统记账应用 | 蜜蜂记账 |
|---|---|
| ❌ 数据存第三方,无法审计 | ✅ **完全开源**,代码可审计 |
| ❌ 隐私可能被分析利用 | ✅ **离线优先** + 自建云端,开发者无法访问 |
| ❌ 服务商倒闭数据丢失 | ✅ **数据主权**,5 种同步方案任选 |
| ❌ 高级功能付费墙 | ✅ **完全免费**(包括 AI / OCR / 语音记账) |
| ❌ 广告 / 理财推荐 | ✅ **零广告 / 零追踪 / 零数据收集** |

> **平台支持**:🤖 Android 5.0+ · 🍎 iOS 15.5+ · 🌐 Web(BeeCount Cloud 自带,见下文)
>
> ~~📱 HarmonyOS — [已停止更新](https://github.com/TNT-Likely/beecount-openharmony)~~

---

## 🌟 核心功能

<details>
<summary><b>🤖 AI 智能记账</b> — AI 对话 / OCR / 语音 / 截图自动识别</summary>

- **AI 小助手** — 自然语言对话记账,智能理解意图,基于智谱 GLM-4
- **OCR 拍照记账** — 双引擎(本地 TFLite + GLM 云端),识别支付宝/微信/云闪付截图
- **语音记账** — 按住说话,GLM 模型理解口语化表达("今天买菜花了 50 块")
- **截图自动记账** — Android 无障碍服务监听 / iOS 快捷指令双击背部触发

</details>

<details>
<summary><b>📝 基础记账</b> — 多账本 / 多账户 / 二级分类 / 预算 / 周期记账 / 标签 / 图表 / 导入导出</summary>

- **多账本** — 生活/工作/投资分开管理,每本独立币种
- **多账户** — 现金/银行卡/信用卡等独立账户,转账自动更新双方余额
- **二级分类** — 父子分类层级
- **预算管理** — 月度总预算 + 分类预算 + 超支提醒
- **周期记账** — 每日/每周/每月/每年自动记账,适合固定收支
- **标签系统** — 多标签 + 颜色标记,灵活筛选
- **图表分析** — 月度报表 / 分类排行 / 趋势分析 / 年度报告
- **数据导入导出** — CSV(支付宝/微信账单)+ YAML 配置导出

</details>

<details>
<summary><b>🎨 体验</b> — 暗黑模式 / 三语 / 桌面小组件 / 主题装扮</summary>

- **暗黑模式** — 纯黑 + 主题色边框,OLED 友好
- **3 语言** — 简中 / 繁中 / English,本地化日期/数字格式
- **桌面小组件** — iOS / Android 桌面快速记账
- **主题装扮** — 多主题色

</details>

---

## 📸 截图预览

<div align="center">
  <img src="demo/videos/zh/01-add-transaction.gif" alt="快速记账" width="200" />
  <img src="demo/videos/zh/02-ocr-recognition.gif" alt="AI OCR 智能识别" width="200" />
  <img src="demo/videos/zh/04-data-analysis.gif" alt="数据分析" width="200" />
</div>

<details>
<summary>更多截图(9 大主题 / 暗黑模式)</summary>

### 9 大功能主题

<div align="center">
  <img src="assets/store/screenshots/raw/zh/01-home.png" alt="首页" width="200" />
  <img src="assets/store/screenshots/raw/zh/02-open-source.png" alt="云服务" width="200" />
  <img src="assets/store/screenshots/raw/zh/03-analytics.png" alt="数据分析" width="200" />
</div>

<div align="center">
  <img src="assets/store/screenshots/raw/zh/04-ai.png" alt="AI 智能记账" width="200" />
  <img src="assets/store/screenshots/raw/zh/05-add.png" alt="记一笔" width="200" />
  <img src="assets/store/screenshots/raw/zh/06-ledgers.png" alt="多账本" width="200" />
</div>

<div align="center">
  <img src="assets/store/screenshots/raw/zh/07-tags.png" alt="彩色标签" width="200" />
  <img src="assets/store/screenshots/raw/zh/08-accounts.png" alt="资产管理" width="200" />
  <img src="assets/store/screenshots/raw/zh/09-mine.png" alt="设置中心" width="200" />
</div>

### 暗黑模式

<div align="center">
  <img src="demo/preview/dark/01-home.png" alt="首页-暗黑" width="200" />
  <img src="demo/preview/dark/02-chart-analysis.png" alt="图表分析-暗黑" width="200" />
  <img src="demo/preview/dark/04-profile.png" alt="我的-暗黑" width="200" />
  <img src="demo/preview/dark/05-ai-chat.png" alt="AI对话-暗黑" width="200" />
</div>

</details>

---

## ☁️ 云同步方案

蜜蜂记账提供 5 种同步方案,所有方案数据完全由你掌控,**详细配置教程见 [docs/cloud-setup.md](docs/cloud-setup.md)**。

| 方案 | 适用场景 | 特点 |
|---|---|---|
| **BeeCount Cloud** | 多端实时协同 + 自托管 + 多人共账 | Docker 一键、秒同步、自带 Web 端、多用户、**共享账本** |
| **iCloud** | iOS 单平台用户 | 零配置、原生集成 |
| **Supabase** | 无 NAS 的跨平台用户 | 免费额度充足、配置简单 |
| **WebDAV** | NAS 用户 | 数据本地化、群晖/绿联云/Nextcloud |
| **S3 协议** | 灵活云存储 | Cloudflare R2 / AWS S3 / MinIO,免费额度大 |

> 🔐 **为什么自建?** 隐私第一、成本可控、数据安全、开源可审计。所有同步代码开源。

---

## 🆕 BeeCount Cloud 自建云

> **多端实时秒级同步 + Web 管理端 + 多用户独立 + AES-256 加密备份** — 推荐有 NAS / VPS / Docker 环境的用户。

### 核心能力

- 📱 **多设备实时协同** — 手机 A 改一笔,手机 B 和 Web 几秒内看到(WebSocket 推送)
- 🌐 **自带 Web 管理端** — 一个 Docker 镜像 = server + web,浏览器直接打开服务器地址即用
- 👥 **多用户独立** — 一个服务器多人注册,数据互相隔离
- 🤝 **共享账本** — Owner 一键生成邀请码,家人 / 团队加入同一本,Owner / Editor 双角色,实时同步 + 每笔交易标记"谁记的 / 谁编辑的" + 成员收支统计(三端等价)
- 🔐 **AES-256 加密备份** — 多远端 fan-out(R2 / S3 / WebDAV / B2),备份用 AES zip 加密,丢失服务也能用标准解压工具自助恢复

### 部署 + 完整文档

完整 Docker Compose 部署教程、备份系统、PWA、运维细节都在 Cloud 仓库:

**[👉 BeeCount-Cloud 仓库 — 一键 Docker 部署 + 完整文档](https://github.com/TNT-Likely/BeeCount-Cloud)**

### Web 管理端预览

<div align="center">
  <img src="demo/preview/web/zh-01-home.png" alt="Web 首页" width="600" />
  <br/>
  <sub>💰 首页:收支、资产构成、分类热力、趋势 — 一屏总览(暗黑模式)</sub>
</div>

<details>
<summary>更多 Web 截图</summary>

<div align="center">
  <img src="demo/preview/web/zh-02-transactions.png" alt="Web 交易列表" width="600" />
  <br/>
  <sub>📒 交易列表:关键字 / 分类 / 账户 / 日期 / 标签多维筛选</sub>
</div>

<br/>

<div align="center">
  <img src="demo/preview/web/zh-03-devices.png" alt="Web 在线设备" width="600" />
  <br/>
  <sub>📱 在线设备 + 备份归档管理</sub>
</div>

</details>

---

## 🛠️ 开发指南

<details>
<summary>技术栈 + 快速开始</summary>

### 技术栈

- **Flutter 3.27+** · 跨平台 UI 框架
- **Riverpod** · 状态管理
- **Drift (SQLite)** · 本地数据库 ORM
- **Supabase / 自建 BeeCount Cloud / WebDAV / S3** · 云端同步多方案

### 快速开始

```bash
# 安装依赖
flutter pub get

# 代码生成
dart run build_runner build --delete-conflicting-outputs

# 运行应用
flutter run --flavor dev

# 构建发布
flutter build apk --flavor prod --release
```

更多开发规范见 [docs/contributing/CONTRIBUTING_ZH.md](docs/contributing/CONTRIBUTING_ZH.md)。

</details>

---

## 🤝 贡献

<details>
<summary>欢迎所有形式的贡献</summary>

- 🐛 [报告 Bug](https://github.com/TNT-Likely/BeeCount/issues/new)
- 💡 [功能建议](https://github.com/TNT-Likely/BeeCount/discussions/new?category=ideas)
- 💻 [代码贡献](docs/contributing/CONTRIBUTING_ZH.md#代码贡献流程) · 🌍 [翻译](docs/contributing/CONTRIBUTING_ZH.md#翻译贡献) · 📝 [文档](docs/contributing/CONTRIBUTING_ZH.md#文档贡献) · 🎨 [设计师招募](docs/contributing/CONTRIBUTING_ZH.md#designer-recruitment)

**快速开始**:Fork → 创建 feature 分支 → 提交 → PR。详细规范见 [完整贡献指南](docs/contributing/CONTRIBUTING_ZH.md)。

</details>

---

## 💬 常见问题

<details>
<summary>查看常见问题解答</summary>

**Q: 不配置云服务能正常使用吗?**
A: 完全可以!应用默认本地存储,所有功能都能正常使用。可随时导出 CSV 备份。

**Q: 应该选哪个云方案?**
A:
- iOS 单设备 → **iCloud**(零配置)
- 跨平台 + 多端实时协同 → **BeeCount Cloud**(自托管,推荐)
- 跨平台无 NAS → **Supabase / S3**
- 有 NAS → **WebDAV**

**Q: 如何确保数据安全?**
A: 使用自己的服务器 / Storage / Bucket,WebDAV 和 S3 建议 HTTPS 加密传输。BeeCount Cloud 备份默认 AES-256 加密。

更多详情见 [docs/cloud-setup.md](docs/cloud-setup.md) 或 [Issues](https://github.com/TNT-Likely/BeeCount/issues)。

</details>

---

## 💝 捐赠支持

蜜蜂记账完全免费开源,**无广告无付费功能**。如果觉得有用,请作者喝杯咖啡 ☕ 支持持续开发。

### 捐赠方式

[![PayPal](https://img.shields.io/badge/PayPal-Donate-0070BA?logo=paypal&logoColor=white&style=for-the-badge)](https://paypal.me/sunxiaoyes)

<details><summary>支付宝 / 微信二维码</summary>

| 支付宝 | 微信支付 |
|:---:|:---:|
| <img src="docs/donate/alipay.png" width="160" alt="支付宝"/> | <img src="docs/donate/wechat.png" width="160" alt="微信支付"/> |

</details>

**USDT (TRC20)**:`TKBV69B2AoU67p3vDhnJUbMJtZ1DxuUF5C` · <details><summary>币安二维码</summary>![币安](docs/donate/binance.png)</details>

### 资金透明度

| 项 | 金额 |
|---|---|
| Apple 开发者账号续费 | ¥688 / 年 |
| 轻量云服务器(ICP 备案) | ¥79 / 年 |
| 域名 | ¥80 / 年 |
| Google Play 开发者账号(一次性) | ¥177 |
| **年度持续成本** | **¥847 / 年** |

### 感谢支持者

| | | | | | | | | | | | |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| <img src="assets/avatars/qiao.svg" width="44"/> | <img src="assets/avatars/rui.svg" width="44"/> | <a href="https://github.com/fishdivinity"><img src="assets/avatars/fishdivinity.png" width="44"/></a> | <img src="assets/avatars/shao.svg" width="44"/> | <img src="assets/avatars/ge.svg" width="44"/> | <img src="assets/avatars/te.svg" width="44"/> | <img src="assets/avatars/wen.svg" width="44"/> | <img src="assets/avatars/anon.svg" width="44"/> | <a href="https://github.com/birdnofoots"><img src="https://github.com/birdnofoots.png" width="44"/></a> | <a href="https://github.com/charieswang72-pro"><img src="https://github.com/charieswang72-pro.png" width="44"/></a> | <a href="https://github.com/542474846"><img src="https://github.com/542474846.png" width="44"/></a> | <a href="https://github.com/JOHN-2025"><img src="https://github.com/JOHN-2025.png" width="44"/></a> |
| *桥 ¥12 | *睿 ¥720 | fishdivinity ¥100 | *邵 ¥15 | *哥 ¥6 | *特 ¥15 | *文 ¥50 | 匿名 ¥50 | birdnofoots ¥10 | Charies ¥10 | 542474846 ¥66 | JOHN-2025 ¥30 |

> 💡 已捐赠?[提交信息](https://github.com/TNT-Likely/BeeCount/issues/new?template=donation_info.yml) 展示在列表中。

---

## 📄 开源协议

本项目采用 **商业源代码许可证(Business Source License,BSL)**。

| 用途 | 许可 |
|---|---|
| ✅ **个人使用 / 学习研究 / 开源贡献** | 完全免费 |
| ❌ **商业使用** | 需要付费授权 |

<details>
<summary>什么算商业使用</summary>

- 将本软件作为商业产品或服务提供给客户
- 在盈利性组织中使用本软件
- 基于本软件开发商业产品
- 提供基于本软件的付费云服务

如需商业授权,请通过 [GitHub Issues](https://github.com/TNT-Likely/BeeCount/issues) 联系。详见 [LICENSE](LICENSE)。

</details>

---

## 📦 相关仓库

| 仓库 | 说明 |
|---|---|
| [BeeCount-Cloud](https://github.com/TNT-Likely/BeeCount-Cloud) | 自建云同步服务端 + Web 管理端(FastAPI + React) |
| [BeeCount-Website](https://github.com/TNT-Likely/BeeCount-Website) | 官网 / 文档仓库 |
| [beecount-openharmony](https://github.com/TNT-Likely/beecount-openharmony) | 鸿蒙版本(已停止更新) |
| [BeeShot](https://github.com/TNT-Likely/BeeShot) | App Store 截图生成器 |

---

## ⭐ Star History

<details>
<summary>查看 Star 历史曲线</summary>

<a href="https://www.star-history.com/?repos=tnt-likely%2Fbeecount&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=tnt-likely/beecount&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=tnt-likely/beecount&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=tnt-likely/beecount&type=date&legend=top-left" />
 </picture>
</a>

</details>

---

## 🙏 致谢

感谢 [果核剥壳 - 互联网的净土](https://www.ghxi.com/)、[星之墨辰](https://mp.weixin.qq.com/s/HieVbKzpdUvnoaCa_9xjkA) 对本项目的宣传。

感谢所有为蜜蜂记账项目贡献代码、提出建议和反馈问题的朋友们!

如有问题或建议,欢迎在 [Issues](https://github.com/TNT-Likely/BeeCount/issues) 中提出,或在 [Discussions](https://github.com/TNT-Likely/BeeCount/discussions) 中参与讨论。

**蜜蜂记账 🐝 — 让记账变得简单而安全**
