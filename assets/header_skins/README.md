# 头部皮肤创作指引 / Header skins

> BeeCount 顶部 `PrimaryHeader` 的「主题色 + 皮肤」装饰层。本文是完整创作规范;两个主 README 只放了折叠摘要。

「主题色 + 皮肤 = 顶部头图」:皮肤是叠在头部主题色底之上的一层装饰。分两类:

| 类型 | 怎么做 | 跟随主题色 | 适合 |
|---|---|---|---|
| **代码皮肤** | 在 `lib/styles/header_skins.dart` 用 `CustomPainter` 画 | ✅ 自动(从 primary 用 HSL 派生) | 渐变 / 几何 / 光斑 / 低多边形 |
| **图片皮肤** | 放一张 SVG,`_ImageSkin` 用 `BoxFit.cover` 铺满 | ✅ 可选(`currentColor`) | 插画 / 场景 |

下面重点讲门槛最低的**图片皮肤(SVG)**。

## SVG 皮肤规范

模板见 [`example_skin.svg`](example_skin.svg)。

### 尺寸与构图
- **全幅设计**:皮肤会被 `BoxFit.cover` 铺满整个头部,和代码皮肤一样大。不同页面头部高矮不一(首页高、子页矮),会按比例**居中裁切** —— 重要元素放中间,别贴边。
- **推荐 viewBox**:宽幅横图,参考示例的 `400 × 200`(2:1)。

### 跟随主题色(currentColor)
- 想随用户主题色变化的部分,fill 写成 **`fill="currentColor"`**,再用 **`fill-opacity`** 拉出明暗层次(示例里天空 0.08 / 太阳 0.28 / 远山 0.42 / 近山 0.66)。
- 渲染时 `currentColor` 会被替换成用户主题色(亮色 = primary、暗色 = 略提亮的 primary);底色由 `_ImageSkin` 兜底(亮 = 主题色浅染 / 暗 = 纯黑)。
- 不想跟随的部分,直接写死 `fill="#RRGGBB"` 即可,两者可混用。

### 兼容性红线
- **只用内联 `fill`**:颜色写成元素属性。**不要用 `<style>` CSS 类**(`.cls1{fill:…}`)—— flutter_svg 不解析 `<style>`,会把整块渲染成**黑色**。
- **渐变可用**:`<defs>` 里的 `<linearGradient>` / `<radialGradient>` 正常支持。
- **不要 `<text>`**:设备字体不确定,文字请在矢量软件里**转成路径**。
- **不要签名 / 水印**:别让作者签名等元素出现在角落。
- **保持纯矢量**:不要内嵌位图 `<image>`,文件尽量小。
- **许可**:用第三方素材必须是 **CC0 / MIT** 等可商用许可,并在 PR 注明出处。

## 接入三步

1. 把 SVG 放进 `assets/header_skins/`(目录已整体注册,**无需改 `pubspec.yaml`**)。
2. 在 `lib/styles/header_skins.dart` 的 `kHeaderSkins` 列表注册一条:
   ```dart
   HeaderSkin(
     id: 'my_skin',
     nameOf: (l) => l.headerSkinMySkin,
     builder: (p, d) => _ImageSkin('assets/header_skins/my_skin.svg', p, d),
   ),
   ```
   (代码皮肤则让 `builder` 返回自己的 `CustomPaint`,可参考同文件的 `_AuroraSkin` 等。)
3. 在 `lib/l10n/app_zh.arb` / `app_en.arb` / `app_zh_TW.arb` 各加一个显示名 `headerSkinMySkin`,跑 `flutter gen-l10n`。

## 自检
- `flutter analyze` 无报错。
- 真机/模拟器切到该皮肤:**没有黑块**(黑块 = 用了 `<style>`)、裁切构图合理、换不同主题色都好看、亮 / 暗模式都可读。

完成后提 PR 即可 🎨
