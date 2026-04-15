#!/bin/bash
# ═══════════════════════════════════════════════════
# 🎨 Fireworks Image Generator — Установщик
# Запуск: curl -fsSL https://raw.githubusercontent.com/geba02/FW_Image/master/install.sh | bash
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
