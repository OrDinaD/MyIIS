#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFilter


def gradient_background(width: int, height: int) -> Image.Image:
    start = (244, 248, 255)
    end = (213, 229, 255)
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


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def build_framed_image(source: Image.Image) -> Image.Image:
    screen_w, screen_h = source.size
    bezel = max(28, int(screen_w * 0.035))
    device_radius = max(86, int(screen_w * 0.095))
    screen_radius = max(54, int(screen_w * 0.055))

    device_w = screen_w + bezel * 2
    device_h = screen_h + bezel * 2

    canvas_w = device_w + int(screen_w * 0.28)
    canvas_h = device_h + int(screen_h * 0.12)

    canvas = gradient_background(canvas_w, canvas_h).convert("RGBA")
    device_x = (canvas_w - device_w) // 2
    device_y = (canvas_h - device_h) // 2

    shadow = Image.new("RGBA", (device_w + 120, device_h + 120), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((36, 32, device_w + 84, device_h + 86), radius=device_radius, fill=(15, 23, 42, 84))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow, (device_x - 60, device_y - 34))

    device = Image.new("RGBA", (device_w, device_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(device)

    draw.rounded_rectangle((0, 0, device_w, device_h), radius=device_radius, fill=(17, 24, 39, 255))
    draw.rounded_rectangle((5, 5, device_w - 5, device_h - 5), radius=device_radius - 6, outline=(255, 255, 255, 54), width=2)
    draw.rounded_rectangle((11, 11, device_w - 11, device_h - 11), radius=device_radius - 14, outline=(0, 0, 0, 140), width=2)

    side_button_color = (51, 65, 85, 255)
    draw.rounded_rectangle((-7, int(device_h * 0.21), 5, int(device_h * 0.31)), radius=6, fill=side_button_color)
    draw.rounded_rectangle((-7, int(device_h * 0.36), 5, int(device_h * 0.49)), radius=6, fill=side_button_color)
    draw.rounded_rectangle((device_w - 5, int(device_h * 0.30), device_w + 7, int(device_h * 0.44)), radius=6, fill=side_button_color)

    screen = source.convert("RGBA")
    device.paste(screen, (bezel, bezel), mask=rounded_mask((screen_w, screen_h), screen_radius))

    island_w = max(260, int(screen_w * 0.30))
    island_h = max(42, int(screen_h * 0.020))
    island_x = (device_w - island_w) // 2
    island_y = bezel + max(18, int(screen_h * 0.014))
    draw.rounded_rectangle(
        (island_x, island_y, island_x + island_w, island_y + island_h),
        radius=island_h // 2,
        fill=(6, 8, 14, 255),
    )

    canvas.alpha_composite(device, (device_x, device_y))
    return canvas.convert("RGB")


def collect_inputs(raw_dir: Path) -> list[Path]:
    files = sorted(raw_dir.glob("iPhone 17-*.png"))
    if files:
        return files
    return sorted([p for p in raw_dir.glob("*.png") if "Clone" not in p.name])


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate framed showcase screenshots.")
    parser.add_argument("--raw-dir", default="fastlane/screenshots/ru-RU")
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
