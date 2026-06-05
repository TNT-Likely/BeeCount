# Skins &nbsp; [中文](README.md)

> The "theme color + skin" decoration layer behind BeeCount's `PrimaryHeader`. This is the full authoring spec; the two main READMEs only carry a folded summary.

"Theme color + skin = the header banner": a skin is a decoration layer drawn on top of the header's theme-color base. Two kinds:

| Kind | How | Follows theme color | Good for |
|---|---|---|---|
| **Code skin** | Draw with `CustomPainter` in `lib/styles/header_skins.dart` | ✅ Automatic (derived from `primary` via HSL) | Gradients / geometry / bokeh / low-poly |
| **Image skin** | Drop an SVG; `_ImageSkin` fills it with `BoxFit.cover` | ✅ Optional (`themed: true`) | Illustrations / scenes |

The lowest-effort path is the **image skin (SVG)**, covered below.

## SVG skin spec

Template: [`example_skin.svg`](example_skin.svg).

### Size & composition
- **Full-bleed design**: the skin is painted edge-to-edge over the whole header with `BoxFit.cover`, the same size as a code skin. Headers vary in height (tall on Home, short on sub-pages) and are **center-cropped** proportionally — keep key elements centered, away from the edges.
- **Recommended viewBox**: a wide landscape, like the example's `400 × 200` (2:1).

### Follow the theme color (themed)
- Register the skin with **`themed: true`** → the whole SVG is **recolored** to the user's theme color; tonal depth comes only from **`fill-opacity`** (in the example: sky 0.08 / sun 0.28 / far hills 0.42 / near hills 0.66). Such a skin is **monochromatic** (one hue, depth via opacity).
- The SVG's own fill colors are ignored here; use `fill="currentColor"` as a placeholder (it looks like a grayscale draft in a browser and gets tinted inside the app).
- Tint: light = `primary`, dark = a slightly lightened `primary`; the base color is provided by `_ImageSkin` (light = lightened theme color / dark = pure black).

### Fixed colors
- **Omit `themed`** (the default) → the SVG renders with its own inline fill colors, good for multi-color illustrations (still subject to the compatibility rules below).

### Compatibility rules (hard limits)
- **Inline `fill` only**: write colors as element attributes. **Do not use `<style>` CSS classes** (`.cls1{fill:…}`) — flutter_svg does not apply `<style>`, so the whole thing renders **black**.
- **Gradients OK**: `<linearGradient>` / `<radialGradient>` inside `<defs>` are supported (only meaningful for fixed-color skins; a themed skin is one flat color).
- **No `<text>`**: device fonts are uncertain — convert text to paths in a vector editor.
- **No signature / watermark**: don't leave the author's signature etc. in a corner.
- **Stay pure vector**: don't embed raster `<image>`; keep the file small.
- **License**: third-party art must be permissively licensed (**CC0 / MIT** etc.) and attributed in the PR.

## Three steps to wire it up

1. Drop the SVG into `assets/header_skins/` (the directory is registered as a whole — **no `pubspec.yaml` change needed**).
2. Register one entry in the `kHeaderSkins` list in `lib/styles/header_skins.dart`:
   ```dart
   HeaderSkin(
     id: 'my_skin',
     nameOf: (l) => l.headerSkinMySkin,
     // themed: true → recolor the whole thing to the theme (monochrome); omit to keep the SVG's own colors
     builder: (p, d) => _ImageSkin('assets/header_skins/my_skin.svg', p, d, themed: true),
   ),
   ```
   (For a code skin, have `builder` return your own `CustomPaint` — see `_AuroraSkin` etc. in the same file.)
3. Add a display name `headerSkinMySkin` to each of `lib/l10n/app_zh.arb` / `app_en.arb` / `app_zh_TW.arb`, then run `flutter gen-l10n`.

## Self-check
- `flutter analyze` passes with no errors.
- Switch to the skin on a device/simulator: **no black block** (a black block = `<style>` was used), the crop composition looks right, it looks good across different theme colors, and it's readable in both light and dark modes.

Open a PR when done 🎨
