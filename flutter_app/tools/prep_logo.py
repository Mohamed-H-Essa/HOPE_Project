"""Crop the HOPE logo's white border and emit PNG variants for in-app, icon, and splash.

Run once: `python3 tools/prep_logo.py` from the flutter_app directory.
Requires Pillow (`pip install pillow`).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "logo.jpeg"
OUT_LOGO = ROOT / "assets" / "logo.png"
OUT_ICON = ROOT / "assets" / "icon" / "app_icon.png"
OUT_SPLASH = ROOT / "assets" / "splash" / "splash_logo.png"

WHITE_THRESHOLD = 215  # pixels brighter than this are treated as background
PADDING_RATIO = 0.08   # 8% padding around the cropped logo


def crop_white_border(img: Image.Image) -> Image.Image:
    gray = ImageOps.grayscale(img)
    # invert so dark logo → bright, white bg → dark; getbbox ignores black
    mask = gray.point(lambda p: 0 if p > WHITE_THRESHOLD else 255)
    bbox = mask.getbbox()
    if bbox is None:
        return img
    return img.crop(bbox)


def pad_to_square(img: Image.Image, bg=(255, 255, 255)) -> Image.Image:
    w, h = img.size
    side = max(w, h)
    pad = int(side * PADDING_RATIO)
    canvas_side = side + 2 * pad
    canvas = Image.new("RGB", (canvas_side, canvas_side), bg)
    canvas.paste(img, (pad + (side - w) // 2, pad + (side - h) // 2))
    return canvas


def pad_to_square_transparent(img: Image.Image, canvas_side: int, logo_side: int) -> Image.Image:
    rgba = img.convert("RGBA")
    scaled = rgba.copy()
    scaled.thumbnail((logo_side, logo_side), Image.LANCZOS)
    canvas = Image.new("RGBA", (canvas_side, canvas_side), (255, 255, 255, 0))
    w, h = scaled.size
    canvas.paste(scaled, ((canvas_side - w) // 2, (canvas_side - h) // 2), scaled)
    return canvas


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Source logo not found at {SRC}")

    OUT_ICON.parent.mkdir(parents=True, exist_ok=True)
    OUT_SPLASH.parent.mkdir(parents=True, exist_ok=True)

    src = Image.open(SRC).convert("RGB")
    cropped = crop_white_border(src)
    squared = pad_to_square(cropped, bg=(255, 255, 255))

    # In-app logo (white bg, 1024)
    logo = squared.resize((1024, 1024), Image.LANCZOS)
    logo.save(OUT_LOGO, "PNG", optimize=True)

    # App icon (white bg, 1024, no alpha for iOS)
    icon = squared.resize((1024, 1024), Image.LANCZOS)
    icon.save(OUT_ICON, "PNG", optimize=True)

    # Splash logo: transparent bg with generous breathing room
    splash = pad_to_square_transparent(cropped, canvas_side=1152, logo_side=512)
    splash.save(OUT_SPLASH, "PNG", optimize=True)

    print(f"Wrote: {OUT_LOGO.relative_to(ROOT)}")
    print(f"Wrote: {OUT_ICON.relative_to(ROOT)}")
    print(f"Wrote: {OUT_SPLASH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
