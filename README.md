# 蜜蜂记账（BeeCount）

仅支持 iOS 与 Android。品牌与设计规范详见 `.ai` 目录。

## 构建与发布

- 开发包（Android）：
 	- 使用 dev flavor，显示名为“蜜蜂记账测试版”，applicationId 追加 `.dev`，可与生产包共存。
 	- 运行：`flutter run --flavor dev`（或在 IDE 中选择 dev 变体）。

- 生产包（Android/iOS）：
 	- 使用 prod flavor（Android）与默认配置（iOS），显示名为“蜜蜂记账”。
 	- GitHub Actions 工作流 `.github/workflows/release.yml` 会自动打包并创建 Release。

- Supabase 凭据：
 	- 本地优先读取 `assets/config.json`，CI 会写入该文件；也可通过 `--dart-define` 覆盖。

## 快速开始

1. 安装依赖

 - flutter pub get
 - dart run build_runner build -d

2. 运行（iOS 模拟器）

 - flutter run -d ios
