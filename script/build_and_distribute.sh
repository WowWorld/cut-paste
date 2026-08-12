#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Cut Paste — 构建 + 签名 + DMG 打包（无需 Developer ID 证书）
# 用户下载后需手动绕过 Gatekeeper（右键打开 或 xattr -cr）
# ============================================================

APP_NAME="Cut Paste"
SWIFT_PRODUCT_NAME="CutPaste"
BUNDLE_ID="io.github.wowworld.cutpaste"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_APPICONSET="$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
APP_ICON_ICNS="$APP_RESOURCES/AppIcon.icns"
DMG_PATH="$DIST_DIR/CutPaste.dmg"
ZIP_PATH="$DIST_DIR/CutPaste.zip"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# ---- Step 1: 编译 ----
info "Step 1: 编译 Swift 项目..."
cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$SWIFT_PRODUCT_NAME" >/dev/null 2>&1 || true

swift build --disable-sandbox
BUILD_BINARY="$(swift build --disable-sandbox --show-bin-path)/$SWIFT_PRODUCT_NAME"

# ---- Step 2: 组装 .app Bundle ----
info "Step 2: 组装 .app Bundle..."
/bin/rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -d "$APP_ICON_APPICONSET" ]] && command -v iconutil >/dev/null 2>&1; then
  ICON_TMP_DIR="$(mktemp -d)"
  ICON_TMP_ICONSET="$ICON_TMP_DIR/AppIcon.iconset"
  mkdir -p "$ICON_TMP_ICONSET"
  cp "$APP_ICON_APPICONSET"/icon_*.png "$ICON_TMP_ICONSET"/
  iconutil -c icns "$ICON_TMP_ICONSET" -o "$APP_ICON_ICNS"
  /bin/rm -rf "$ICON_TMP_DIR"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_SYSTEM_VERSION}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# ---- Step 3: 签名（优先使用 Apple Development 证书，否则 ad-hoc）----
info "Step 3: 签名应用..."

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$CODESIGN_IDENTITY" ]]; then
  CODESIGN_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | awk -F '"' '/Apple Development|Developer ID Application/ { print $2; exit }'
  )"
fi

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  info "使用证书签名: $CODESIGN_IDENTITY"
  codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE" >/dev/null
else
  warn "未找到签名证书，使用 ad-hoc 签名"
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
fi

# ---- Step 4: 创建 DMG 安装包 ----
info "Step 4: 创建 DMG 安装包..."
/bin/rm -f "$DMG_PATH"

STAGING_DIR="$(mktemp -d)"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "Cut Paste" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_PATH" >/dev/null

/bin/rm -rf "$STAGING_DIR"
info "DMG 已生成: $DMG_PATH"

# ---- Step 5: 创建 ZIP 包（兼容旧版下载）----
info "Step 5: 创建 ZIP 包..."
cd "$DIST_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"
info "ZIP 已生成: $ZIP_PATH"

# ---- 完成 ----
info "============================================"
info "打包完成！"
info "============================================"
echo ""
echo "产物："
echo "  DMG: $DMG_PATH  ($(du -h "$DMG_PATH" | awk '{print $1}'))"
echo "  ZIP: $ZIP_PATH  ($(du -h "$ZIP_PATH" | awk '{print $1}'))"
echo ""
echo "用户安装步骤："
echo "  1. 下载 CutPaste.dmg"
echo "  2. 打开 DMG，将 Cut Paste 拖入 Applications"
echo "  3. 右键点击 Cut Paste.app → 打开 → 确认打开"
echo "  4. 授予辅助功能权限"
