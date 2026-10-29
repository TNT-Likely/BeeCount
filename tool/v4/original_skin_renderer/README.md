# 原版动态皮肤独立渲染器

仅供相邻设计仓 `../BeeCount-Design/card-refresh/boards/skin-application-review.html` 确认皮肤应用方式。这个入口不导入 BeeCount App、数据库、Provider、Cloud 或 AI，不生成或安装 APK，也不改变产品默认无皮肤设置。

## 本地重建

在仓库根目录执行：

```sh
python3 tool/v4/build_original_skin_renderer.py --check-only
python3 tool/v4/build_original_skin_renderer.py
# Flutter 路径不同时：
python3 tool/v4/build_original_skin_renderer.py --flutter /absolute/path/to/flutter
```

要求本地有官方 `3.9.0` tag、Flutter 3.27.3 / Dart 3.6.1，以及该 SDK 已缓存的 Flutter Web 引擎和 Roboto 字体。构建先执行 `pub get --offline`，不引入第三方包。SDK 首次缺少 Web 引擎时仍需先通过 Flutter 工具准备缓存；已生成页面运行时没有 CDN、远程字体或云服务依赖。

将 `../BeeCount-Design/card-refresh` 作为 HTTP 静态根目录，打开 `/boards/skin-application-review.html`。当前项目已有预览服务：`http://127.0.0.1:8374/boards/skin-application-review.html`。固定的 `/renderers/build/original-skins-390/` base 路径需与此根目录一致。

临时 Flutter 工程位于本目录 `build/source_project`，编译结果位于 `../BeeCount-Design/card-refresh/renderers/build/original-skins-390`。两个 `build/` 均被 Git 忽略；只提交入口、模板、构建器、评审 HTML/CSS/JS。重新构建不会修改产品代码；主 demo 通过现有构建器引用相同原画窗口。

## 原画来源与完整性

固定官方 commit：`3fddb41747d5e6d89df82a2ff493f2f56a5ac37b`。构建器验证 tag 指向该 commit，并用 `git show` 提取以下文件的原始字节，不格式化、不增加参数、不修改 Painter：

| 原始 part | SHA-256 |
| --- | --- |
| `skin_common.dart` | `9bf14bce7b857a53ac84952ce149402499b9e109de616f30ae15b8471734773c` |
| `anniversary_skin.dart` | `ed19fed0335529ee3b5f98363171ebf784d0deb1d27142ee706ba0414f7a66e3` |
| `anniv_cake_skin.dart` | `b9953ee141b3f1d387ff82325ba5305c457b0d12156bdfdc7a2bc5aa0336f059` |

原 registry 的 `_lighten` / `_hueShift` helper 也逐字提取；生成结果附有 `source-manifest.json`，记录原文件哈希、registry 哈希和实际 Flutter 版本。两个私有原 Widget 只由新模板暴露，不调用 v4 隐藏铭文的 `pageBuilder`。

- 一岁星座：原 `#F8C91C`，头部 10 秒，底部 7 秒。保留星尘、银河、星云、月牙、流星、双蜂、星座与铭文。
- 周年蛋糕：原 `#FF7A45`，头部 10 秒，底部 9 秒。保留双层蛋糕、数字蜡烛、烛火、草莓、彩带、糖粒与铭文。
- 关闭/减弱动效走原 Widget 的 `disableAnimations` 分支；暂停使用外层 `TickerMode`，不改控制器周期。顶层页面隐藏、原画离场、打开弹窗时停止对应 ticker。
- `random_probe.dart` 用于核对原实现涉及的 5 个固定种子。Dart VM 与 Dart2JS 每个种子前 1024 次抽样完全相等，不能因此宣称不同渲染后端逐像素一致。

## 承载方式与真实边界

评审默认浅色 02「首卡共景」、深色 01「顶部柔幕」，另可强制切换两种方式。主 demo 与评审页共用 `prototype/src/original-skin-application.js` 的布局计算；原有信息、卡片几何和交互保持；皮肤窗口为旁挂、不可点击的透明 iframe，普通 demo 重新渲染不会销毁原动画控制器。

头部先在 **398×208 逻辑画布**绘制，再通过 `BoxFit.contain` 整幅等比放入承载区，保持完整构图与粒子分布，避免对新卡片高度重新计算粒子密度。原画基底继续保留；透明的是 Web 窗口。底部则直接在实际胶囊尺寸运行原始 Tab Painter。

02 提供两项真实对照：

1. **右侧留白**：把完整场景等比缩小，放入现有卡片右侧。并非只裁右侧蛋糕或星座；原画全幅可见，因此也能看到原场景自身的矩形边缘。外侧只延续原基底颜色/渐变，不生成假星尘或重新画蛋糕。
2. **整幅铺底**：完整场景铺入承载区顶部，保留较大主体；会有原月牙/铭文靠近新卡片文字的真实空间冲突，供用户确认，不能据“相同源码”宣称布局已无冲突。圆角承载容器只裁外缘角部，不专门裁掉主体。

01 完整场景等比放在第一张卡片上方，避免被不透明卡片遮去下半主体。小屏空间较少时整体缩小，不删粒子/铭文。我的页紧凑余额卡不额外插入图片行，完整场景位于原资料区域，仍待用户确认大小与文字关系。

下方两张原画直出固定为 398×208，并可使用原代码静态帧与应用效果核对。这里使用 Web 预览的零状态栏内边距；Android 的真实安全区、字体替代、CanvasKit 抗锯齿/模糊与设备渲染可能不同。**源码、算法与构图来源一致，不代表 Web 与 Android 逐像素相同。**用户恢复本项并明确浅色02、深色01后，产品已接入相同的有界原画承载：首页浅色首卡、深色顶部；我的页浅色资料区域、深色顶部。最终 Android 真机验证由统一隔离验收继续执行。

原来简化 SVG 的应用稿保存在 `skin-application-svg-history-20261026.*`，用于追溯；它不是线上原素材。旧四方向稿和导出设计图保持历史内容；主 demo 已同步原画应用，默认无皮肤未改变。

入口保存在 `lib/main.dart.in`，仅由构建器写入忽略目录中的独立项目 `lib/main.dart`。模板依赖从固定3.9提交提取的原part，不能作为App仓内可直接分析的Dart入口；这避免尚未提取原part时给主项目引入缺失引用。该组织修正不改变皮肤绘制、设计或已有预览产物。

设计仓默认与 App 相邻；其他位置设置 `BEECOUNT_DESIGN_ROOT` 为其 `card-refresh` 绝对路径。仅构建评审 renderer 时需要设计仓，App 与 `--check-only` 无此依赖。
