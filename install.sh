#!/bin/bash
# ═══════════════════════════════════════════════════
# 🎨 Fireworks Image Generator — Установщик
# Запуск: curl -fsSL https://raw.githubusercontent.com/geba02/FW_Image/main/install.sh | bash
# ═══════════════════════════════════════════════════

set -e

BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

REPO="https://raw.githubusercontent.com/geba02/FW_Image/main"
INSTALL_DIR="$HOME/Applications/FW_Image"
APP_PATH="$HOME/Applications/FW_Image.app"

echo ""
echo "${BLUE}═══════════════════════════════════════════════${NC}"
echo "${BLUE}  🎨 Fireworks Image Generator — Установка${NC}"
echo "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# ─── 1. Python ──────────────────────────────────────────────
echo "${YELLOW}[1/5]${NC} Проверяю Python 3..."
PY=""
if [ -x "/opt/homebrew/bin/python3" ]; then PY="/opt/homebrew/bin/python3"
elif [ -x "/usr/local/bin/python3" ]; then PY="/usr/local/bin/python3"
elif command -v python3 &>/dev/null; then PY="$(command -v python3)"
fi
if [ -z "$PY" ]; then
    echo "${RED}❌ Python 3 не найден! Установите: https://www.python.org/downloads/${NC}"
    exit 1
fi
echo "   ✅ $("$PY" --version 2>&1)"

# ─── 2. pywebview ───────────────────────────────────────────
echo "${YELLOW}[2/5]${NC} Проверяю pywebview..."
if "$PY" -c "import webview" 2>/dev/null; then
    echo "   ✅ Уже установлен"
else
    echo "   📦 Устанавливаю..."
    "$PY" -m pip install pywebview --break-system-packages -q 2>/dev/null || \
    "$PY" -m pip install pywebview -q 2>/dev/null || \
    { echo "${RED}❌ Не удалось. Попробуйте: $PY -m pip install pywebview${NC}"; exit 1; }
    echo "   ✅ Установлен"
fi

# ─── 3. Скачиваю файлы ─────────────────────────────────────
echo "${YELLOW}[3/5]${NC} Скачиваю файлы..."
mkdir -p "$INSTALL_DIR/generated_images"
curl -fsSL "$REPO/server.py" -o "$INSTALL_DIR/server.py"
curl -fsSL "$REPO/index.html" -o "$INSTALL_DIR/index.html"
echo "   ✅ Файлы загружены"

# ─── 4. Создаю .app ────────────────────────────────────────
echo "${YELLOW}[4/5]${NC} Создаю приложение..."
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cat > "$APP_PATH/Contents/MacOS/launcher" << 'LAUNCHER'
#!/bin/zsh
PY=""
if [ -x "/opt/homebrew/bin/python3" ]; then PY="/opt/homebrew/bin/python3"
elif [ -x "/usr/local/bin/python3" ]; then PY="/usr/local/bin/python3"
elif command -v python3 &>/dev/null; then PY="$(command -v python3)"
fi
LAUNCHER
echo "\"\$PY\" \"$INSTALL_DIR/server.py\"" >> "$APP_PATH/Contents/MacOS/launcher"
chmod +x "$APP_PATH/Contents/MacOS/launcher"

cat > "$APP_PATH/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Fireworks Generator</string>
    <key>CFBundleDisplayName</key><string>Fireworks Generator</string>
    <key>CFBundleIdentifier</key><string>com.fireworks.imagegen</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>launcher</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP_PATH" 2>/dev/null

# Иконка 🎨
ICON_TMP=$(mktemp -d)
cat > "$ICON_TMP/icon.html" << 'ICONHTML'
<html><body style="margin:0;padding:0;width:1024px;height:1024px;background:transparent;display:flex;align-items:center;justify-content:center;"><div style="width:1024px;height:1024px;background:#0e0e12;border-radius:228px;display:flex;align-items:center;justify-content:center;"><span style="font-size:680px;line-height:1;">🎨</span></div></body></html>
ICONHTML
qlmanage -t -s 1024 -o "$ICON_TMP" "$ICON_TMP/icon.html" >/dev/null 2>&1
SRC="$ICON_TMP/icon.html.png"
if [ -f "$SRC" ]; then
    ISET="$ICON_TMP/AppIcon.iconset"
    mkdir -p "$ISET"
    for pair in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" "512:icon_256x256@2x" "512:icon_512x512" "1024:icon_512x512@2x"; do
        sz=${pair%%:*}; name=${pair#*:}
        sips -z $sz $sz "$SRC" --out "$ISET/${name}.png" >/dev/null 2>&1
    done
    iconutil -c icns "$ISET" -o /tmp/fw_icon.icns 2>/dev/null
    if [ -f /tmp/fw_icon.icns ]; then
        cp /tmp/fw_icon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
    fi
fi
rm -rf "$ICON_TMP" /tmp/fw_icon.icns 2>/dev/null
touch "$APP_PATH"

echo "   ✅ Приложение создано"

# ─── 5. Ярлык ──────────────────────────────────────────────
echo "${YELLOW}[5/5]${NC} Создаю ярлык на рабочий стол..."
ln -sf "$APP_PATH" "$HOME/Desktop/Fireworks Generator" 2>/dev/null
echo "   ✅ Готово"

echo ""
echo "${GREEN}═══════════════════════════════════════════════${NC}"
echo "${GREEN}  ✅ Установка завершена!${NC}"
echo "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "  🚀 Запускай: Fireworks Generator на рабочем столе"
echo "  📂 Картинки: ~/Applications/FW_Image/generated_images/"
echo "  🔑 При первом запуске введи API ключ Fireworks AI"
echo ""
