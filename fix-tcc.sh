#!/bin/bash
# 修复辅助功能权限问题
# 用法：在终端中运行 bash fix-tcc.sh

set -e

APP_NAME="Cut Paste"
BUNDLE_ID="io.github.wowworld.cutpaste"
APP_PATH="/Users/wangliang/cut-copy/dist/Cut Paste.app"

echo "=== 1. 关闭应用 ==="
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

echo "=== 2. 重置 TCC 权限记录 ==="
echo "重置 Accessibility 权限..."
sudo tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || echo "(可能需要手动重置)"

echo "重置所有 TCC 权限..."
sudo tccutil reset All "$BUNDLE_ID" 2>/dev/null || tccutil reset All "$BUNDLE_ID" 2>/dev/null || echo "(可能需要手动重置)"

echo "=== 3. 重新签名应用 ==="
cd /Users/wangliang/cut-copy
swift build --disable-sandbox 2>/dev/null || true
cp "$(swift build --disable-sandbox --show-bin-path)/CutPaste" "dist/Cut Paste.app/Contents/MacOS/Cut Paste"

# 尝试用开发者证书签名，失败则用 ad-hoc
SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development|Developer ID Application/ { print $2; exit }')
if [ -n "$SIGN_ID" ]; then
    echo "使用开发者证书签名: $SIGN_ID"
    codesign --force --deep --sign "$SIGN_ID" "$APP_PATH"
else
    echo "未找到开发者证书，使用 ad-hoc 签名"
    codesign --force --deep --sign - "$APP_PATH"
fi

echo "=== 4. 启动应用 ==="
open -n "$APP_PATH"
sleep 2

echo ""
echo "=== 完成 ==="
echo ""
echo "现在请按以下步骤操作："
echo ""
echo "1. 应用启动后会弹出权限请求对话框，点击「打开系统设置」"
echo "2. 在「系统设置 → 隐私与安全性 → 辅助功能」中找到 Cut Paste"
echo "3. 打开开关（变为蓝色）"
echo "4. 如果列表中没有 Cut Paste："
echo "   a. 点列表下方的 + 号"
echo "   b. 按 Cmd+Shift+G"
echo "   c. 输入: /Users/wangliang/cut-copy/dist/"
echo "   d. 选择 Cut Paste.app"
echo "   e. 打开开关"
echo ""
echo "5. 回到 Cut Paste，在 Shelf 中选一个内容点粘贴测试"
echo ""
