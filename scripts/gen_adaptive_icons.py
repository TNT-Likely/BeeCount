#!/usr/bin/env python3
"""生成 Android adaptive icon 素材(前景 / monochrome 线框版)。

产出(1024×1024,内容缩进 adaptive 安全区 ~62%):
  assets/icon/adaptive_foreground.png  — 全彩蜜蜂(透明底),adaptive 前景层
  assets/icon/adaptive_monochrome.png  — 线框蜜蜂(黑色+透明镂空),Android 13 themed icon 用
  assets/icon/preview_themed.png       — 模拟 Pixel 动态图标亮/暗效果(仅预览,不打包)

为什么 monochrome 必须是线框版:themed icon 只取图层的 **alpha 通道**做单色
着色 —— 全彩 logo 的填充形状在 alpha 里是一坨实心剪影(白眼睛/黑条纹全部消失)。
特征必须用描边和透明镂空表达。

几何取自 assets/logo.svg(256 viewBox),用 PIL 按 4× 超采样重绘后缩回抗锯齿。

用法:python3 scripts/gen_adaptive_icons.py
之后:dart run flutter_launcher_icons
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "icon"

CANVAS = 1024  # adaptive 图层画布
SS = 4  # 超采样倍数

# 256 viewBox → 画布的缩放/平移。内容 bbox 约 x[60,196] y[24,214](高 ~190)。
# 前景与 monochrome 各用一套占比:
# - 前景 60%:再叠 ic_launcher.xml 的 16% inset 后,落在 adaptive 安全区内
# - monochrome 90%:launcher 渲染 themed icon 时还会再加一层自己的 inset,
#   glyph 留白太多会显得特别小(Google 官方 mono 素材也是几乎铺满画布)
SCALE = 3.3
OFF_X = CANVAS / 2 - 128 * SCALE
OFF_Y = CANVAS / 2 - 119 * SCALE


def set_content_ratio(ratio):
    """设置内容(高 190 单位)占画布的比例,居中。"""
    global SCALE, OFF_X, OFF_Y
    SCALE = CANVAS * ratio / 190
    OFF_X = CANVAS / 2 - 128 * SCALE
    OFF_Y = CANVAS / 2 - 119 * SCALE

# logo.svg 的配色
YELLOW = (255, 193, 7, 255)  # #FFC107 身体
CYAN = (128, 222, 234, 204)  # #80DEEA 翅膀(80% 不透明)
BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)


def pt(x, y):
    """256 坐标 → 超采样画布坐标"""
    return ((x * SCALE + OFF_X) * SS, (y * SCALE + OFF_Y) * SS)


def d(v):
    """256 尺度的长度 → 超采样画布长度"""
    return v * SCALE * SS


def ellipse_box(cx, cy, rx, ry):
    x0, y0 = pt(cx - rx, cy - ry)
    x1, y1 = pt(cx + rx, cy + ry)
    return [x0, y0, x1, y1]


def thick_line(draw, p0, p1, width, fill):
    """带圆头端点的粗线(PIL line 无 cap,用端点圆补)"""
    draw.line([p0, p1], fill=fill, width=int(width))
    for p in (p0, p1):
        r = width / 2
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)


def antenna_points(side):
    """触角三次贝塞尔采样:M128,66 c 0,-14 10,-26 24,-28(side=±1 镜像)"""
    p0 = (128, 66)
    p1 = (128, 52)
    p2 = (128 + side * 10, 40)
    p3 = (128 + side * 24, 38)
    pts = []
    for i in range(21):
        t = i / 20
        x = ((1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0]
             + 3 * (1 - t) * t**2 * p2[0] + t**3 * p3[0])
        y = ((1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1]
             + 3 * (1 - t) * t**2 * p2[1] + t**3 * p3[1])
        pts.append(pt(x, y))
    return pts


def draw_antennae(draw, width, fill):
    for side in (1, -1):
        pts = antenna_points(side)
        for a, b in zip(pts, pts[1:]):
            thick_line(draw, a, b, width, fill)


def gen_foreground():
    """全彩前景:与 logo.svg 同构"""
    set_content_ratio(0.60)
    im = Image.new("RGBA", (CANVAS * SS, CANVAS * SS), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    # 触角(画在头后面)
    draw_antennae(dr, d(10), BLACK)
    # 头
    dr.ellipse(ellipse_box(128, 106, 36, 36), fill=BLACK)
    # 身体(黄填充 + 黑描边)
    dr.ellipse(ellipse_box(128, 174, 54, 40), fill=YELLOW,
               outline=BLACK, width=int(d(10)))
    # 条纹(端点收进轮廓内:PIL 椭圆描边向内画,SVG 原坐标的圆头会戳出轮廓)
    thick_line(dr, pt(82, 174), pt(174, 174), d(12), BLACK)
    thick_line(dr, pt(92, 190), pt(164, 190), d(12), BLACK)
    # 翅膀(半透明,单独图层避免叠加补端点圆造成深浅不均)
    wings = Image.new("RGBA", im.size, (0, 0, 0, 0))
    wdr = ImageDraw.Draw(wings)
    wdr.ellipse(ellipse_box(92, 126, 28, 18), fill=CYAN)
    wdr.ellipse(ellipse_box(164, 126, 28, 18), fill=CYAN)
    im = Image.alpha_composite(im, wings)
    dr = ImageDraw.Draw(im)
    # 眼睛
    dr.ellipse(ellipse_box(116, 102, 6, 6), fill=WHITE)
    dr.ellipse(ellipse_box(140, 102, 6, 6), fill=WHITE)
    return im.resize((CANVAS, CANVAS), Image.LANCZOS)


def gen_monochrome():
    """单色版:themed icon 只取 alpha 通道,结构与彩色 logo 完全同构:
    - 头:实心圆 + 镂空眼睛(logo 即实心黑头 + 白眼)
    - 身体:描边椭圆 + 实心条纹线(logo 即描边黄肚 + 黑条纹)
    - 翅膀:描边椭圆
    - 触角:粗线
    画布占比 0.90:launcher 渲染 themed icon 时自带大 inset,glyph 必须近乎铺满
    (留白太多会显得特别小);铺满后线宽在小尺寸下也足够清晰。
    """
    set_content_ratio(0.90)
    # 用 L 模式画 alpha 蒙版:255=笔画,0=透明(可表达镂空)
    mask = Image.new("L", (CANVAS * SS, CANVAS * SS), 0)
    dr = ImageDraw.Draw(mask)
    # 触角
    draw_antennae(dr, d(12), 255)
    # 翅膀描边
    dr.ellipse(ellipse_box(92, 126, 28, 18), outline=255, width=int(d(11)))
    dr.ellipse(ellipse_box(164, 126, 28, 18), outline=255, width=int(d(11)))
    # 头:实心圆
    dr.ellipse(ellipse_box(128, 106, 36, 36), fill=255)
    # 身体:描边椭圆 + 实心条纹(端点收进轮廓内,圆头不戳出描边)
    dr.ellipse(ellipse_box(128, 174, 54, 40), outline=255, width=int(d(13)))
    thick_line(dr, pt(82, 174), pt(174, 174), d(11), 255)
    thick_line(dr, pt(92, 190), pt(164, 190), d(11), 255)
    # 眼睛:镂空(对应 logo 的白眼睛)
    dr.ellipse(ellipse_box(116, 102, 8, 8), fill=0)
    dr.ellipse(ellipse_box(140, 102, 8, 8), fill=0)

    mask = mask.resize((CANVAS, CANVAS), Image.LANCZOS)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
    out.putalpha(mask)
    return out


def gen_preview(mono):
    """模拟 Pixel themed icon 亮/暗效果,纯预览用"""
    size = 512
    pad = 40
    glyph = mono.resize((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size * 2 + pad * 3, size + pad * 2),
                       (255, 255, 255, 255))
    for i, (bg, fg) in enumerate([
        ((233, 226, 208, 255), (74, 68, 89, 255)),   # 亮:浅底深 glyph
        ((74, 68, 89, 255), (233, 226, 208, 255)),   # 暗:深底浅 glyph
    ]):
        cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        dr = ImageDraw.Draw(cell)
        dr.ellipse([0, 0, size, size], fill=bg)
        tinted = Image.new("RGBA", (size, size), fg)
        tinted.putalpha(glyph.getchannel("A"))
        cell = Image.alpha_composite(cell, tinted)
        canvas.paste(cell, (pad + i * (size + pad), pad), cell)
    return canvas


def gen_legacy(fg):
    """legacy 启动图标(Android 8 以下 / 不支持 adaptive 的 launcher):
    必须**不透明**——透明底在部分设备上表现很差(旧版用 0.13.1 生成时被拍平成
    白底,0.14.4 会保留 alpha,故这里显式给不透明底)。底色与 adaptive 背景一致。
    """
    bg = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 255))  # 白底,与 adaptive 背景一致
    # 前景占比 0.60 留白偏多,legacy 无系统蒙版裁切,放大一些(0.60×1.3=0.78)
    big = int(CANVAS * 1.3)
    scaled = fg.resize((big, big), Image.LANCZOS)
    crop = (big - CANVAS) // 2
    bg.alpha_composite(scaled.crop((crop, crop, crop + CANVAS, crop + CANVAS)))
    return bg


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    fg = gen_foreground()
    fg.save(OUT_DIR / "adaptive_foreground.png")
    gen_legacy(fg).save(OUT_DIR / "launcher_legacy.png")
    mono = gen_monochrome()
    mono.save(OUT_DIR / "adaptive_monochrome.png")
    gen_preview(mono).save(OUT_DIR / "preview_themed.png")
    print("✓ adaptive_foreground / launcher_legacy / adaptive_monochrome / preview_themed →", OUT_DIR)


if __name__ == "__main__":
    main()
