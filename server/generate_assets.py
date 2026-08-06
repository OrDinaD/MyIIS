import os
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
os.makedirs(ASSETS_DIR, exist_ok=True)

def create_badge(size, text):
    img = Image.new("RGBA", size, (246, 237, 171, 255))
    draw = ImageDraw.Draw(img)
    w, h = size
    # Синий ободок
    draw.rectangle([0, 0, w - 1, h - 1], outline=(38, 56, 173, 255), width=max(1, w // 20))
    # Рисуем надпись
    font_size = int(h * 0.5)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf", font_size)
    except Exception:
        font = ImageFont.load_default()
    
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) / 2, (h - th) / 2 - bbox[1]), text, fill=(38, 56, 173, 255), font=font)
    return img

def main():
    icon1x = create_badge((29, 29), "M")
    icon2x = create_badge((58, 58), "M")
    icon3x = create_badge((87, 87), "M")
    
    logo1x = create_badge((160, 50), "MyIIS")
    logo2x = create_badge((320, 100), "MyIIS")

    icon1x.save(os.path.join(ASSETS_DIR, "icon.png"))
    icon2x.save(os.path.join(ASSETS_DIR, "icon@2x.png"))
    icon3x.save(os.path.join(ASSETS_DIR, "icon@3x.png"))

    logo1x.save(os.path.join(ASSETS_DIR, "logo.png"))
    logo2x.save(os.path.join(ASSETS_DIR, "logo@2x.png"))
    print("✅ Иконки и логотипы Wallet созданы в server/assets/")

if __name__ == "__main__":
    main()
