#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFilter


def gradient_background(width: int, height: int) -> Image.Image:
    start = (9, 14, 30)
    end = (32, 54, 96)
    bg = Image.new("RGB", (width, height), start)
    px = bg.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        r = int(start[0] + (end[0] - start[0]) * t)
        g = int(start[1] + (end[1] - start[1]) * t)
        b = int(start[2] + (end[2] - start[2]) * t)
        for x in range(width):
            px[x, y] = (r, g, b)
    return bg


def build_framed_image(source: Image.Image) -> Image.Image:
    screen_w, screen_h = source.size
    device_border_x = 52
    device_border_top = 122
    device_border_bottom = 98

    device_w = screen_w + device_border_x * 2
    device_h = screen_h + device_border_top + device_border_bottom

    canvas_w = device_w + 360
    canvas_h = device_h + 280

    canvas = gradient_background(canvas_w, canvas_h).convert("RGBA")
    device_x = (canvas_w - device_w) // 2
    device_y = (canvas_h - device_h) // 2

    shadow = Image.new("RGBA", (device_w + 80, device_h + 80), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((20, 20, device_w + 60, device_h + 60), radius=130, fill=(0, 0, 0, 220))
    shadow = shadow.filter(ImageFilter.GaussianBlur(25))
    canvas.alpha_composite(shadow, (device_x - 40, device_y - 18))

    device = Image.new("RGBA", (device_w, device_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(device)

    draw.rounded_rectangle((0, 0, device_w, device_h), radius=120, fill=(18, 19, 23, 255))
    draw.rounded_rectangle((8, 8, device_w - 8, device_h - 8), radius=112, outline=(95, 99, 112, 180), width=2)

    screen_mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle((0, 0, screen_w, screen_h), radius=68, fill=255)

    device.paste(source.convert("RGBA"), (device_border_x, device_border_top), mask=screen_mask)

    island_w = max(300, int(screen_w * 0.28))
    island_h = 54
    island_x = (device_w - island_w) // 2
    island_y = device_border_top + 14
    draw.rounded_rectangle((island_x, island_y, island_x + island_w, island_y + island_h), radius=27, fill=(7, 7, 10, 255))

    canvas.alpha_composite(device, (device_x, device_y))
    return canvas.convert("RGB")


def collect_inputs(raw_dir: Path) -> list[Path]:
    files = sorted(raw_dir.glob("iPhone 17-*.png"))
    if files:
        return files
    return sorted([p for p in raw_dir.glob("*.png") if "Clone" not in p.name])


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate framed showcase screenshots.")
    parser.add_argument("--raw-dir", default="fastlane/screenshots/en-US")
    parser.add_argument("--out-dir", default="public/showcase")
    args = parser.parse_args()

    raw_dir = Path(args.raw_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    inputs = collect_inputs(raw_dir)
    if not inputs:
        raise SystemExit(f"No PNG screenshots found in {raw_dir}")

    for src in inputs:
        with Image.open(src) as image:
            framed = build_framed_image(image)
        out_name = src.name.replace("iPhone 17-", "").replace(" ", "_").lower()
        out_path = out_dir / out_name
        framed.save(out_path, format="PNG", optimize=True)
        print(out_path)


if __name__ == "__main__":
    main()
