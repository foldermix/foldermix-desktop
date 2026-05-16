#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="foldermix"
BUNDLE_ID="dev.foldermix.desktop"
VERSION="${1:-0.0.0}"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$APP_NAME-v$VERSION.dmg"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
# If FOLDERMIX_CLI_SOURCE is not set, fall back to a sibling checkout (local dev)
# or PyPI mode (CI). PyPI mode is used when no sibling dir exists either.
FOLDERMIX_CLI_SOURCE="${FOLDERMIX_CLI_SOURCE:-}"
if [[ -z "$FOLDERMIX_CLI_SOURCE" && -d "$ROOT_DIR/../foldermix" ]]; then
    FOLDERMIX_CLI_SOURCE="$(cd "$ROOT_DIR/../foldermix" && pwd)"
fi

CLI_ENTRY="$BUILD_DIR/foldermix_cli_entry.py"
CLI_DIST_DIR="$BUILD_DIR/cli-dist"
CLI_WORK_DIR="$BUILD_DIR/cli-work"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR" "$DMG_DIR" "$DMG_PATH" "$ICONSET_DIR" "$CLI_DIST_DIR" "$CLI_WORK_DIR" "$CLI_ENTRY"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources/bin" "$DMG_DIR"

cp "$ROOT_DIR/.build/release/FoldermixDesktop" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$CLI_ENTRY" <<'PY'
from foldermix.cli import app

if __name__ == "__main__":
    app()
PY

if [[ -n "$FOLDERMIX_CLI_SOURCE" ]]; then
    # Local source mode: delegate to uv inside the foldermix source tree.
    (
      cd "$FOLDERMIX_CLI_SOURCE"
      uv run \
        --extra all \
        --extra markitdown \
        --with pyinstaller \
        pyinstaller \
          --clean \
          --noconfirm \
          --name foldermix-cli \
          --onedir \
          --distpath "$CLI_DIST_DIR" \
          --workpath "$CLI_WORK_DIR" \
          --copy-metadata foldermix \
          --collect-all rapidocr_onnxruntime \
          --collect-all onnxruntime \
          --hidden-import rapidocr_onnxruntime \
          "$CLI_ENTRY"
    )
else
    # PyPI mode (CI): install the pinned foldermix version into a venv.
    FOLDERMIX_PYPI_VERSION="$(cat "$ROOT_DIR/foldermix-version.txt")"
    python3 -m venv "$BUILD_DIR/pyinstaller-venv"
    "$BUILD_DIR/pyinstaller-venv/bin/pip" install --quiet --upgrade pip
    "$BUILD_DIR/pyinstaller-venv/bin/pip" install --quiet \
        "foldermix[all,markitdown]==$FOLDERMIX_PYPI_VERSION" \
        pyinstaller
    "$BUILD_DIR/pyinstaller-venv/bin/pyinstaller" \
        --clean \
        --noconfirm \
        --name foldermix-cli \
        --onedir \
        --distpath "$CLI_DIST_DIR" \
        --workpath "$CLI_WORK_DIR" \
        --copy-metadata foldermix \
        --collect-all rapidocr_onnxruntime \
        --collect-all onnxruntime \
        --hidden-import rapidocr_onnxruntime \
        "$CLI_ENTRY"
fi

cp -R "$CLI_DIST_DIR/foldermix-cli" "$APP_DIR/Contents/Resources/bin/foldermix-cli"

python3 - "$ICONSET_DIR" <<'PY'
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

iconset = Path(sys.argv[1])
iconset.mkdir(parents=True, exist_ok=True)
base_size = 1024
image = Image.new("RGBA", (base_size, base_size), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)

draw.rounded_rectangle((72, 72, 952, 952), radius=190, fill=(21, 27, 35, 255))
draw.rounded_rectangle((120, 130, 904, 900), radius=150, outline=(69, 220, 230, 255), width=24)
draw.rounded_rectangle((190, 270, 835, 745), radius=52, fill=(43, 62, 80, 255))
draw.polygon([(190, 300), (360, 300), (405, 365), (835, 365), (835, 745), (190, 745)], fill=(69, 220, 230, 255))
draw.rounded_rectangle((240, 410, 785, 690), radius=36, fill=(23, 30, 39, 255))

try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 280)
except OSError:
    font = ImageFont.load_default()
text = "fm"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
draw.text(
    ((base_size - text_width) / 2, 438 - text_height / 2),
    text,
    font=font,
    fill=(246, 248, 251, 255),
)

sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}
for name, size in sizes.items():
    image.resize((size, size), Image.Resampling.LANCZOS).save(iconset / name)
PY

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>foldermix</string>
  <key>CFBundleDisplayName</key>
  <string>foldermix</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null

cp -R "$APP_DIR" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
/usr/bin/hdiutil create \
  -volname "foldermix v$VERSION" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
