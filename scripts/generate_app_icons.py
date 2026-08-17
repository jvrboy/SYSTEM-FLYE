from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math

root = Path(__file__).resolve().parents[1] / "SYSTEMFLYE" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
root.mkdir(parents=True, exist_ok=True)

sizes = [40, 58, 60, 80, 87, 120, 180, 1024]
for size in sizes:
    scale = max(size, 256) / 256
    canvas = Image.new("RGB", (size, size), (7, 11, 24))
    draw = ImageDraw.Draw(canvas)
    cx = cy = size / 2
    radius = size * 0.43
    for r in range(int(radius), 0, -1):
        t = r / radius
        color = (int(11 + 16 * (1 - t)), int(19 + 45 * (1 - t)), int(48 + 75 * (1 - t)))
        draw.ellipse((cx-r, cy-r, cx+r, cy+r), fill=color)
    ring = int(max(1, size * 0.018))
    draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), outline=(51, 211, 238), width=ring)
    bars = [0.34, 0.58, 0.82, 0.52, 0.74, 0.45, 0.68]
    gap = size * 0.055
    bar_w = size * 0.055
    start_x = cx - (len(bars) * bar_w + (len(bars)-1) * gap) / 2
    for i, height in enumerate(bars):
        x = start_x + i * (bar_w + gap)
        h = size * 0.31 * height + size * 0.08
        y1 = cy - h / 2
        y2 = cy + h / 2
        color = (111, 91, 255) if i % 2 else (65, 226, 233)
        draw.rounded_rectangle((x, y1, x + bar_w, y2), radius=max(1, int(bar_w/2)), fill=color)
    dot_r = size * 0.028
    draw.ellipse((cx-dot_r, cy-dot_r, cx+dot_r, cy+dot_r), fill=(255, 214, 102))
    if size >= 1024:
        canvas = canvas.filter(ImageFilter.GaussianBlur(0.3))
    canvas.save(root / f"icon-{size}.png", format="PNG", optimize=True)

contents = '''{
  "images" : [
    {"filename" : "icon-40.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20"},
    {"filename" : "icon-60.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20"},
    {"filename" : "icon-58.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29"},
    {"filename" : "icon-87.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29"},
    {"filename" : "icon-80.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40"},
    {"filename" : "icon-120.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40"},
    {"filename" : "icon-120.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60"},
    {"filename" : "icon-180.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60"},
    {"filename" : "icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024"}
  ],
  "info" : {"author" : "xcode", "version" : 1}
}
'''
(root / "Contents.json").write_text(contents)
print(root)
