#!/bin/sh
# Значки Retmind Desk из исходников desk/brand/src/*.svg (знак — brand/app-icon.svg, brand/mark.svg).
# Нужны: rsvg-convert (пакет librsvg2-bin) и python3 с Pillow.
# Результат — desk/brand/icons/ (лежит в git, apply.sh берёт готовое). Запуск: sh desk/brand/make_icons.sh
set -eu
D=$(cd "$(dirname "$0")" && pwd)
SRC=$D/src
OUT=$D/icons
rm -rf "$OUT"
mkdir -p "$OUT/png" "$OUT/macos.iconset" "$OUT/tray"

png() { rsvg-convert -w "$2" -h "$3" "$SRC/$1" -o "$4"; }

# Значок программы (Windows, Linux, окно): плашка #01162F без полей
for s in 16 24 32 48 64 128 256 512 1024; do png app-icon.svg $s $s "$OUT/png/app-icon-$s.png"; done

# macOS .icns: плашка с полями по сетке macOS 11+ (824 из 1024)
for s in 16 32 128 256 512; do
  png mac-icon.svg $s $s "$OUT/macos.iconset/icon_${s}x${s}.png"
  png mac-icon.svg $((s * 2)) $((s * 2)) "$OUT/macos.iconset/icon_${s}x${s}@2x.png"
done
png mac-icon.svg 1024 1024 "$OUT/png/mac-icon-1024.png"

# Трей macOS — шаблон (чёрный + прозрачный): 18 pt, @2x = 36 px
png tray-template.svg 18 18 "$OUT/tray/mac-tray-template-18.png"
png tray-template.svg 36 36 "$OUT/tray/mac-tray-template-36.png"
for s in 16 20 24 32 48; do png app-icon.svg $s $s "$OUT/tray/win-tray-$s.png"; done

# Логотип в окне программы (не больше 300x60, рисуем в 2 раза крупнее)
png logo-light.svg 388 120 "$OUT/png/logo-light.png"
png logo-dark.svg 388 120 "$OUT/png/logo-dark.png"

python3 - "$OUT" <<'EOF'
import sys
from pathlib import Path
from PIL import Image
out = Path(sys.argv[1])
def ico(name, sizes, pattern):
    imgs = [Image.open(out / pattern.format(s)).convert("RGBA") for s in sizes]
    big = imgs[-1]
    big.save(out / name, format="ICO", sizes=[(s, s) for s in sizes], append_images=imgs[:-1])
# Windows: значок программы (16–256), отдельный для трея (16–48)
ico("icon.ico", [16, 24, 32, 48, 64, 128, 256], "png/app-icon-{}.png")
ico("tray-icon.ico", [16, 20, 24, 32, 48], "tray/win-tray-{}.png")
# macOS: AppIcon.icns (Pillow пишет .icns на любой системе; на Mac можно и iconutil)
mac = Image.open(out / "png/mac-icon-1024.png").convert("RGBA")
mac.save(out / "AppIcon.icns", format="ICNS",
         append_images=[Image.open(out / f"macos.iconset/icon_{s}x{s}.png").convert("RGBA") for s in (16, 32, 128, 256, 512)])
print("AppIcon.icns", sorted(Image.open(out / "AppIcon.icns").info.get("sizes", [])) or "ok")
for n in ("icon.ico", "tray-icon.ico"):
    print(n, sorted(Image.open(out / n).info["sizes"]))
EOF

cp "$SRC/app-icon.svg" "$OUT/icon.svg"
echo "готово: $OUT"
