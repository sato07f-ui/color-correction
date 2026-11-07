"""P型向けの「見分けやすさ確認カード」（自作の数字の検査表）を作る。

使い方（リポジトリのルートで実行）:
    python docs/test_plates/generate_test_plates.py

できるもの（docs/test_plates/ に出力）:
    plates/        印刷・撮影に使うカード
    comparisons/   説明用の4分割画像（元の画像／補正後 × 一般色覚／P型の見え方）

作り方:
    - ドットの配置は乱数で作る（既存の検査表は使っていない）。
    - 数字と背景の色は、P型の見え方のシミュレーション（Machado 2009）で
      ほぼ同じ色になる組を、行列の計算で決める。
    - ドットごとの明るさのばらつきは、数字と背景で同じにする
      （明るさの違いだけで数字が読めてしまわないようにするため）。
    - 補正後の画像は、アプリのシェーダー（correction.frag）と同じ計算で作る。

医療的な色覚検査ではない。デモで補正の効果を見せるための確認用。
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path(__file__).resolve().parent
SEED = 20261108

# ---- correction.frag と同じ行列（行ごとに書き、行列 @ ベクトル で掛ける） ----

# Machado, Oliveira & Fernandes (2009) の P型（重さ 1.0）
SIM_P = np.array(
    [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281, 0.099216],
        [-0.003882, -0.048116, 1.051998],
    ]
)

# 見えなくなった差分を振り直す行列（P型）
SHIFT_P = np.array(
    [
        [0.0, 0.0, 0.0],
        [0.5, 1.0, 0.0],
        [-0.5, 0.0, 1.0],
    ]
)


def to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def simulate(rgb: np.ndarray) -> np.ndarray:
    """sRGB（0〜1、最後の軸が RGB）を P型の見え方にする。"""
    return to_srgb(to_linear(rgb) @ SIM_P.T)


def correct(rgb: np.ndarray) -> np.ndarray:
    """シェーダーの correct()（強度 1.0）と同じ補正をかける。"""
    lin = to_linear(rgb)
    lost = lin - lin @ SIM_P.T
    return to_srgb(lin + lost @ SHIFT_P.T)


def to_lab(rgb: np.ndarray) -> np.ndarray:
    lin = to_linear(rgb)
    m = np.array(
        [
            [0.4124, 0.3576, 0.1805],
            [0.2126, 0.7152, 0.0722],
            [0.0193, 0.1192, 0.9505],
        ]
    )
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack(
        [116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])],
        axis=-1,
    )


def delta_e(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.linalg.norm(to_lab(a) - to_lab(b)))


# ---- 色の組を決める ----


def confusion_direction() -> np.ndarray:
    """P型のシミュレーションで、ほぼ見えなくなる色の方向（線形RGB）。

    SIM_P の最小特異値に対応するベクトル。この方向に色をずらしても、
    P型の見え方はほとんど変わらない。赤が増える向きにそろえる。
    """
    _, _, vt = np.linalg.svd(SIM_P)
    v = vt[-1]
    return v if v[0] > 0 else -v


def make_palette() -> tuple[list[np.ndarray], list[np.ndarray]]:
    """背景（緑系）と数字（橙茶系）の色を、明るさ違いで数組作る。

    背景の色 G に、P型で見えない方向 v を足して数字の色 F = G + t·v にする。
    t は、どの明るさでも色域（0〜1）に収まる範囲で、なるべく大きくする。
    """
    v = confusion_direction()
    base = to_linear(np.array([0x52, 0x79, 0x06]) / 255)  # 緑（テストで使った色）
    levels = [0.75, 0.88, 1.0, 1.12]

    grounds = [base * k for k in levels]
    t_max = min(
        min(((1.0 - g[i]) / v[i]) if v[i] > 0 else ((0.0 - g[i]) / v[i]) for i in range(3) if v[i] != 0)
        for g in grounds
    )
    t = t_max * 0.95
    figures = [g + t * v for g in grounds]
    return [to_srgb(g) for g in grounds], [to_srgb(f) for f in figures]


# ---- ドットを並べる ----


def pack_dots(size: int, radius: float, rng: random.Random) -> list[tuple[float, float, float]]:
    """円の中に、大きさの違う円を重ならないように詰める。"""
    radii = [26, 20, 16, 13, 10, 8, 6]
    attempts = [600, 1500, 3000, 6000, 12000, 20000, 30000]
    gap = 2.5
    cell = 2 * radii[0] + gap
    grid: dict[tuple[int, int], list[tuple[float, float, float]]] = {}
    dots: list[tuple[float, float, float]] = []
    cx = cy = size / 2

    for r_base, n in zip(radii, attempts):
        for _ in range(n):
            r = r_base * rng.uniform(0.85, 1.15)
            a = rng.uniform(0, 2 * math.pi)
            d = math.sqrt(rng.random()) * (radius - r)
            x, y = cx + d * math.cos(a), cy + d * math.sin(a)
            gx, gy = int(x // cell), int(y // cell)
            ok = True
            for nx in range(gx - 1, gx + 2):
                for ny in range(gy - 1, gy + 2):
                    for ox, oy, orr in grid.get((nx, ny), ()):
                        if (x - ox) ** 2 + (y - oy) ** 2 < (r + orr + gap) ** 2:
                            ok = False
                            break
                    if not ok:
                        break
                if not ok:
                    break
            if ok:
                dots.append((x, y, r))
                grid.setdefault((gx, gy), []).append((x, y, r))
    return dots


def digit_mask(text: str, size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    font_size = int(size * (0.62 if len(text) == 1 else 0.5))
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", font_size)
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text(((size - w) / 2 - box[0], (size - h) / 2 - box[1]), text, fill=255, font=font)
    return mask


def render_plate(
    text: str,
    grounds: list[np.ndarray],
    figures: list[np.ndarray],
    seed: int,
    size: int = 1000,
) -> Image.Image:
    rng = random.Random(seed)
    scale = 2  # 2倍で描いて縮小し、ドットの縁をなめらかにする
    radius = size * 0.47
    dots = pack_dots(size, radius, rng)
    mask = digit_mask(text, size)

    img = Image.new("RGB", (size * scale, size * scale), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    for x, y, r in dots:
        is_figure = mask.getpixel((int(x), int(y))) > 127
        # 明るさの組は、数字と背景で同じ確率で選ぶ
        i = rng.randrange(len(grounds))
        color = figures[i] if is_figure else grounds[i]
        rgb = tuple(int(round(c * 255)) for c in color)
        draw.ellipse(
            [(x - r) * scale, (y - r) * scale, (x + r) * scale, (y + r) * scale],
            fill=rgb,
        )
    return img.resize((size, size), Image.LANCZOS)


def render_control(text: str, seed: int, size: int = 1000) -> Image.Image:
    """誰でも読める見本のカード（明るさの違いで数字を描く）。"""
    gray_ground = [np.array([0.78, 0.78, 0.74]) * k for k in (0.9, 1.0, 1.08)]
    dark_figure = [np.array([0.20, 0.30, 0.55]) * k for k in (0.9, 1.0, 1.08)]
    return render_plate(text, gray_ground, dark_figure, seed, size)


# ---- 説明用の4分割画像 ----


def apply(img: Image.Image, fn) -> Image.Image:
    arr = np.asarray(img).astype(np.float64) / 255
    out = fn(arr)
    return Image.fromarray(np.clip(np.round(out * 255), 0, 255).astype(np.uint8))


def comparison(plate: Image.Image, text: str) -> Image.Image:
    tile = 480
    pad = 24
    label_h = 56
    title_h = 70
    w = pad * 3 + tile * 2
    h = title_h + (label_h + tile + pad) * 2 + pad
    sheet = Image.new("RGB", (w, h), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    font_title = ImageFont.truetype("C:/Windows/Fonts/YuGothB.ttc", 30)
    font_label = ImageFont.truetype("C:/Windows/Fonts/YuGothM.ttc", 22)

    draw.text((pad, 20), f"見分けやすさ確認カード「{text}」（P型）", fill=(30, 30, 30), font=font_title)

    corrected = apply(plate, correct)
    tiles = [
        ("元の画像（一般色覚の見え方）", plate),
        ("補正後（一般色覚の見え方）", corrected),
        ("元の画像を P型で見ると（シミュレーション）", apply(plate, simulate)),
        ("補正後を P型で見ると（シミュレーション）", apply(corrected, simulate)),
    ]
    for i, (label, im) in enumerate(tiles):
        col, row = i % 2, i // 2
        x = pad + col * (tile + pad)
        y = title_h + row * (label_h + tile + pad)
        draw.text((x, y + 14), label, fill=(60, 60, 60), font=font_label)
        sheet.paste(im.resize((tile, tile), Image.LANCZOS), (x, y + label_h))
    return sheet


def main() -> None:
    plates_dir = OUT_DIR / "plates"
    comp_dir = OUT_DIR / "comparisons"
    plates_dir.mkdir(exist_ok=True)
    comp_dir.mkdir(exist_ok=True)

    grounds, figures = make_palette()
    g, f = grounds[2], figures[2]
    hex_ = lambda c: "#" + "".join(f"{int(round(x * 255)):02X}" for x in c)  # noqa: E731
    print(f"背景の色: {hex_(g)}  数字の色: {hex_(f)}")
    print(f"  一般色覚での色差 ΔE       : {delta_e(g, f):5.1f}")
    print(f"  P型で見たときの色差 ΔE     : {delta_e(simulate(g), simulate(f)):5.1f}")
    print(f"  補正後をP型で見たときの色差 : {delta_e(simulate(correct(g)), simulate(correct(f))):5.1f}")

    control = render_control("12", SEED)
    control.save(plates_dir / "00_見本_12.png")
    print("plates/00_見本_12.png（誰でも読める見本）")

    # 補正なし用と補正あり用で、別の数字を使えるよう6枚作る
    texts = ["74", "6", "29", "5", "42", "8"]
    for i, text in enumerate(texts, start=1):
        plate = render_plate(text, grounds, figures, SEED + i)
        name = f"{i:02d}_{text}.png"
        plate.save(plates_dir / name)
        comparison(plate, text).save(comp_dir / f"比較_{name}")
        print(f"plates/{name}  comparisons/比較_{name}")


if __name__ == "__main__":
    main()
