#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import argparse

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FRAME_PATH = ROOT / "scripts" / "assets" / "iphone-frame.png"
LEGACY_SHOWCASE_SIZE = (1670, 3122)
LEGACY_SCREEN_BOX = (154, 174, 1417, 2887)
LEGACY_PATCH_OFFSET = (78, 88)
FRAME_SCREEN_BOX = (9, 12, 284, 598)
FRAME_SCREEN_RADIUS = 34


@dataclass(frozen=True)
class TextPatch:
    box: tuple[int, int, int, int]
    text: str
    size: int
    weight: str = "regular"
    fill: tuple[int, int, int] = (0, 0, 0)
    anchor: str = "la"
    align: str = "left"
    background: tuple[int, int, int] = (255, 255, 255)
    radius: int = 0


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    name = "Arial Bold.ttf" if weight == "bold" else "Arial.ttf"
    return ImageFont.truetype(f"/System/Library/Fonts/Supplemental/{name}", size)


def gradient_background(width: int, height: int) -> Image.Image:
    start = (8, 13, 27)
    end = (24, 46, 84)
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


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def prepare_frame(frame_path: Path, target_screen_height: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    frame = Image.open(frame_path).convert("RGBA")
    frame_w, frame_h = frame.size
    sx1, sy1, sx2, sy2 = FRAME_SCREEN_BOX
    screen_scale = target_screen_height / (sy2 - sy1)
    scaled_frame = frame.resize((round(frame_w * screen_scale), round(frame_h * screen_scale)), Image.Resampling.LANCZOS)
    screen_box = (
        round(sx1 * screen_scale),
        round(sy1 * screen_scale),
        round(sx2 * screen_scale),
        round(sy2 * screen_scale),
    )

    overlay = scaled_frame.copy()
    clear = Image.new("L", (screen_box[2] - screen_box[0], screen_box[3] - screen_box[1]), 0)
    clear_draw = ImageDraw.Draw(clear)
    clear_draw.rounded_rectangle(
        (0, 0, clear.width, clear.height),
        radius=round(FRAME_SCREEN_RADIUS * screen_scale),
        fill=255,
    )
    transparent = Image.new("RGBA", clear.size, (0, 0, 0, 0))
    overlay.paste(transparent, screen_box[:2], clear)
    return overlay, screen_box


def build_framed_image(source: Image.Image, frame_path: Path) -> Image.Image:
    source = source.convert("RGBA")
    frame, screen_box = prepare_frame(frame_path, source.height)
    screen_w = screen_box[2] - screen_box[0]
    screen_h = screen_box[3] - screen_box[1]

    canvas_w = max(frame.width + 320, 1500)
    canvas_h = max(frame.height + 240, 3000)
    canvas = gradient_background(canvas_w, canvas_h).convert("RGBA")
    frame_x = (canvas_w - frame.width) // 2
    frame_y = (canvas_h - frame.height) // 2

    shadow = Image.new("RGBA", (frame.width + 140, frame.height + 140), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((56, 48, frame.width + 88, frame.height + 96), radius=120, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow, (frame_x - 70, frame_y - 58))

    screen = cover_resize(source, (screen_w, screen_h))
    screen_mask = rounded_mask((screen_w, screen_h), max(72, round(screen_w * 0.12)))
    canvas.paste(screen, (frame_x + screen_box[0], frame_y + screen_box[1]), screen_mask)
    canvas.alpha_composite(frame, (frame_x, frame_y))
    return canvas.convert("RGB")


def extract_legacy_screen(image: Image.Image) -> Image.Image:
    if image.size != LEGACY_SHOWCASE_SIZE:
        return image
    return image.crop(LEGACY_SCREEN_BOX)


def draw_patch(draw: ImageDraw.ImageDraw, patch: TextPatch) -> None:
    x1, y1, x2, y2 = patch.box
    if patch.radius:
        draw.rounded_rectangle(patch.box, radius=patch.radius, fill=patch.background)
    else:
        draw.rectangle(patch.box, fill=patch.background)

    text_font = font(patch.size, patch.weight)
    if patch.anchor == "mm":
        draw.multiline_text(((x1 + x2) // 2, (y1 + y2) // 2), patch.text, font=text_font, fill=patch.fill, anchor="mm", align="center", spacing=8)
    else:
        draw.multiline_text((x1, y1), patch.text, font=text_font, fill=patch.fill, anchor=patch.anchor, align=patch.align, spacing=6)


def tab_patches(active: str) -> list[TextPatch]:
    labels = [
        ((314, 2506, 438, 2566), "Профиль", "profile"),
        ((520, 2506, 676, 2566), "Посещ.", "attendance"),
        ((757, 2506, 914, 2566), "Рейтинг", "rating"),
        ((982, 2506, 1144, 2566), "Сервисы", "services"),
    ]
    patches: list[TextPatch] = []
    for box, title, key in labels:
        color = (0, 122, 255) if key == active else (20, 20, 20)
        patches.append(TextPatch(box, title, 31, fill=color, anchor="mm", background=(255, 255, 255)))
    return patches


def localize_legacy_screen(screen: Image.Image, name: str) -> Image.Image:
    image = screen.convert("RGB")
    draw = ImageDraw.Draw(image)
    white = (255, 255, 255)
    page = (242, 242, 247)
    gray = (142, 142, 147)
    light = (245, 245, 248)
    blue = (0, 122, 255)

    patches_by_name: dict[str, list[TextPatch]] = {
        "01_loginscreen": [
            TextPatch((210, 520, 996, 760), "Личный кабинет\nстудента БГУИР", 72, "bold", anchor="mm", background=white),
            TextPatch((300, 765, 906, 835), "Авторизуйтесь, чтобы продолжить", 41, "bold", gray, anchor="mm", background=white),
            TextPatch((124, 985, 470, 1045), "Логин", 39, "bold", gray, background=white),
            TextPatch((186, 1124, 760, 1188), "Введите логин", 42, fill=(185, 185, 193), background=(247, 247, 251)),
            TextPatch((124, 1295, 470, 1355), "Пароль", 39, "bold", gray, background=white),
            TextPatch((186, 1433, 760, 1496), "Введите пароль", 42, fill=(185, 185, 193), background=(247, 247, 251)),
            TextPatch((0, 1640, 1206, 1735), "Войти", 42, "bold", (255, 255, 255), anchor="mm", background=blue),
        ],
        "02_profilescreen": [
            TextPatch((0, 335, 460, 465), "Профиль", 73, "bold", background=white),
            TextPatch((86, 1565, 500, 1635), "Учёба", 44, "bold", background=white),
            TextPatch((110, 1765, 430, 1825), "Факультет", 37, fill=gray, background=white),
            TextPatch((110, 1895, 520, 1955), "Специальность", 37, fill=gray, background=white),
            TextPatch((110, 2035, 360, 2095), "Группа", 37, fill=gray, background=white),
            TextPatch((110, 2165, 330, 2225), "Курс", 37, fill=gray, background=white),
            TextPatch((86, 2370, 640, 2440), "Личная информация", 40, "bold", background=white),
            *tab_patches("profile"),
        ],
        "03_attendancescreen": [
            TextPatch((0, 335, 720, 465), "Посещаемость", 73, "bold", background=white),
            TextPatch((180, 630, 770, 690), "Заявления ОРВИ", 43, "bold", background=white),
            TextPatch((180, 690, 880, 745), "История заявлений и решений", 34, fill=gray, background=white),
            TextPatch((180, 1045, 760, 1105), "Пропуски", 43, "bold", background=white),
            TextPatch((180, 1105, 760, 1160), "Текущий семестр", 34, fill=gray, background=white),
            TextPatch((180, 1460, 760, 1520), "Справки", 43, "bold", background=white),
            TextPatch((180, 1520, 930, 1575), "Документы по уважительным причинам", 34, fill=gray, background=white),
            *tab_patches("attendance"),
        ],
        "04_ratingscreen": [
            TextPatch((0, 335, 560, 465), "Рейтинг", 73, "bold", background=page),
            TextPatch((120, 620, 560, 690), "Мой рейтинг", 43, "bold", background=white),
            TextPatch((120, 695, 520, 745), "Группа 220603", 35, fill=gray, background=white),
            TextPatch((235, 1185, 450, 1235), "Средний", 31, fill=gray, background=light),
            TextPatch((705, 1185, 970, 1235), "Пропуски", 31, fill=gray, background=light),
            TextPatch((0, 1605, 1206, 1670), "Не удалось загрузить данные", 42, "bold", anchor="mm", background=white),
            TextPatch((0, 1678, 1206, 1762), "Не удалось определить\nидентификатор студента", 41, fill=gray, anchor="mm", background=white),
            TextPatch((516, 1848, 690, 1905), "Повторить", 34, (255, 255, 255), anchor="mm", background=blue),
            *tab_patches("rating"),
        ],
        "05_servicesscreen": [
            TextPatch((0, 335, 560, 465), "Сервисы", 73, "bold", background=page),
            TextPatch((96, 520, 360, 595), "Учёба", 42, "bold", fill=gray, background=page),
            TextPatch((190, 705, 520, 765), "Зачётка", 43, "bold", background=white),
            TextPatch((190, 910, 520, 970), "Обучение", 43, "bold", background=white),
            TextPatch((190, 1110, 520, 1170), "Диплом", 43, "bold", background=white),
            TextPatch((190, 1315, 520, 1375), "Группа", 43, "bold", background=white),
            TextPatch((96, 1585, 440, 1660), "Ресурсы", 42, "bold", fill=gray, background=page),
            TextPatch((190, 1775, 560, 1835), "Общежитие", 43, "bold", background=white),
            TextPatch((190, 1980, 560, 2040), "Библиотека", 43, "bold", background=white),
            TextPatch((96, 2260, 300, 2330), "Инфо", 42, "bold", fill=gray, background=page),
            *tab_patches("services"),
        ],
        "06_gradebookscreen": [
            TextPatch((0, 335, 580, 465), "Зачётка", 73, "bold", background=page),
            TextPatch((96, 585, 540, 650), "Номер: 22060301", 40, "bold", background=white),
            TextPatch((690, 585, 1115, 650), "Ср. балл: 9.30", 40, "bold", background=white),
            TextPatch((96, 860, 420, 930), "Семестр", 42, "bold", fill=gray, background=page),
            TextPatch((96, 1215, 560, 1275), "Средний балл", 37, background=white),
            TextPatch((96, 1445, 420, 1515), "Предметы", 42, "bold", fill=gray, background=page),
            TextPatch((96, 1715, 230, 1760), "Часы", 33, fill=gray, background=white),
            TextPatch((96, 1782, 360, 1828), "Форма контроля", 33, fill=gray, background=white),
            TextPatch((96, 1848, 230, 1894), "Дата", 33, fill=gray, background=white),
            TextPatch((96, 1912, 350, 1958), "Преподаватель", 33, fill=gray, background=white),
            TextPatch((96, 1978, 300, 2024), "Пересдачи", 33, fill=gray, background=white),
            TextPatch((96, 2260, 230, 2305), "Часы", 33, fill=gray, background=white),
            TextPatch((96, 2326, 360, 2372), "Форма контроля", 33, fill=gray, background=white),
            TextPatch((96, 2392, 230, 2438), "Дата", 33, fill=gray, background=white),
            TextPatch((96, 2456, 350, 2502), "Преподаватель", 33, fill=gray, background=white),
            TextPatch((96, 2522, 300, 2568), "Пересдачи", 33, fill=gray, background=white),
            *tab_patches("services"),
        ],
    }

    stem = name.replace("iPhone 17-", "").replace(" ", "_").lower().replace(".png", "")
    dx, dy = LEGACY_PATCH_OFFSET
    for patch in patches_by_name.get(stem, []):
        x1, y1, x2, y2 = patch.box
        shifted_patch = TextPatch(
            box=(x1 + dx, y1 + dy, x2 + dx, y2 + dy),
            text=patch.text,
            size=patch.size,
            weight=patch.weight,
            fill=patch.fill,
            anchor=patch.anchor,
            align=patch.align,
            background=patch.background,
            radius=patch.radius,
        )
        draw_patch(draw, shifted_patch)
    return image


def collect_inputs(raw_dir: Path, legacy_dir: Path | None) -> list[Path]:
    files = sorted(raw_dir.glob("iPhone 17-*.png"))
    if files:
        return files
    files = sorted([p for p in raw_dir.glob("*.png") if "Clone" not in p.name])
    if files:
        return files
    if legacy_dir is not None:
        return sorted(legacy_dir.glob("*.png"))
    return []


def output_name(src: Path) -> str:
    return src.name.replace("iPhone 17-", "").replace(" ", "_").lower()


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate framed showcase screenshots.")
    parser.add_argument("--raw-dir", default="fastlane/screenshots/ru-RU")
    parser.add_argument("--legacy-dir", default="public/showcase")
    parser.add_argument("--out-dir", default="public/showcase")
    parser.add_argument("--frame", default=str(DEFAULT_FRAME_PATH))
    parser.add_argument("--no-localize-legacy", action="store_true")
    args = parser.parse_args()

    raw_dir = Path(args.raw_dir)
    legacy_dir = Path(args.legacy_dir) if args.legacy_dir else None
    out_dir = Path(args.out_dir)
    frame_path = Path(args.frame)
    out_dir.mkdir(parents=True, exist_ok=True)

    inputs = collect_inputs(raw_dir, legacy_dir)
    if not inputs:
        raise SystemExit(f"No PNG screenshots found in {raw_dir}")

    for src in inputs:
        with Image.open(src) as image:
            screen = extract_legacy_screen(image.convert("RGB"))
        if src.parent == legacy_dir and not args.no_localize_legacy:
            screen = localize_legacy_screen(screen, src.name)
        framed = build_framed_image(screen, frame_path)
        out_path = out_dir / output_name(src)
        framed.save(out_path, format="PNG", optimize=True)
        print(out_path)


if __name__ == "__main__":
    main()
