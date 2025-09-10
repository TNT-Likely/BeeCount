# 蜜蜂记账（BeeCount）

轻量、开源的个人记账 App，支持 iOS 与 Android。内置账本、分类、统计分析、导入导出、云同步（Supabase）。

演示截图

<div align="center">
 <img src="assets/preview/home.png" alt="首页" width="200" />
 <img src="assets/preview/add.jpg" alt="记一笔" width="200" />
 <img src="assets/preview/analytic.jpg" alt="分析页" width="200" />
 <img src="assets/preview/zhangben.jpg" alt="账本" width="200" />
 <img src="assets/preview/mine.png" alt="我的页" width="200" />
</div>

上述为部分功能页面截图，更多细节请体验 App。

功能特性

- 记一笔：分类、金额、日期、备注
- 分析：月度收支、结余与分类排行
- 数据：CSV 导入、导出
- 同步：使用 Supabase 存储，登录后云备份/恢复
- 个性：主题色、图标等

## 快速开始（用户）

前置要求

- Flutter 3.27+（fvm 可选）
- iOS/macOS 需 Xcode，Android 需 Android Studio/SDK

安装与运行

1) 安装依赖

```bash
flutter pub get
```

1) 运行（示例）

```bash
# Android 调试
flutter run --flavor dev -d android
# iOS 模拟器
flutter run -d ios
```

## 使用说明

- 记账：在首页底部“+”添加，支持长按记录删除
- 切换月份：顶部日期选择器；到列表顶部/底部继续拉可切换月
- 隐藏金额：首页右上角“眼睛”按钮
- 导入/导出：我的页 → 导入/导出
- 登录与同步：我的页 → 登录，开启“自动同步”可自动上传

## 构建与发布

风味与命名

- Android flavors：dev（测试包）、prod（发布包）
- Debug 包：显示名“蜜蜂记账测试版”，可与 prod 共存
- Release 包：prodRelease，输出命名包含版本号，例如：`app-prod-release-v1.2.3(45).apk`

Android 打包

- Debug：

```bash
flutter build apk --flavor dev --debug
```

- Release：

1) 配置签名：复制 `android/key.properties.sample` 为 `android/key.properties` 并填写

2) 构建：

```bash
flutter build apk --flavor prod --release
```

iOS 打包

- 在 Xcode 中打开 `ios/Runner.xcworkspace`，按常规流程 Archive & Distribute

CI 与版本

- GitHub Actions 会根据标签创建 Release 并打包
- 应用内“关于”与“检测更新”会展示/获取最新版本

## Supabase 配置与自定义

配置来源优先级（高→低）

1) --dart-define 注入：

- SUPABASE_URL
- SUPABASE_ANON_KEY

2) 非 Release 模式下的 `assets/config.json`

本地调试示例

- 在 `assets/config.json` 中填写：

```json
{
 "supabaseUrl": "https://YOUR-PROJECT.supabase.co",
 "supabaseAnonKey": "YOUR-ANON-KEY"
}
```

- 或使用 dart-define：

```bash
flutter run \
 --dart-define=SUPABASE_URL=... \
 --dart-define=SUPABASE_ANON_KEY=...
```

自定义你的 Supabase 服务

- 登录 supabase.io 创建项目，启用 Auth 与 Postgres 存储
- 在应用中使用你自己的 URL/Anon Key
- 注意保管密钥，不要把 service_role key 放入客户端

## 开发指南

主要技术

- Flutter + Riverpod + Drift(SQLite)
- 结构：`lib/pages` 页面、`lib/widgets` 组件、`lib/data` 数据层、`lib/cloud` 云服务

代码约定

- UI 颜色与间距：见 `lib/styles`
- Header：`lib/widgets/ui/primary_header.dart`
- 日志：`lib/utils/logger.dart`

常见脚本

- 依赖：flutter pub get
- 代码生成：dart run build_runner build -d

## 开源协议与免责声明

- 协议：本项目遵循 MIT License（见仓库 LICENSE）。
- 免责声明：

  - 本软件按“现状”提供，不对可用性或适配性作任何明示或暗示担保；
  - 使用本软件产生的任何数据丢失或损失风险由使用者自行承担；
  - 请遵守当地法律法规，不得用于任何违法用途。
