#!/bin/bash
# ═══════════════════════════════════════════════════
# 🎨 Fireworks Image Generator — Установщик
# curl -fsSL https://raw.githubusercontent.com/geba02/FW_Image/main/install.sh | bash
# ═══════════════════════════════════════════════════

set -e

REPO="https://raw.githubusercontent.com/geba02/FW_Image/main"
INSTALL_DIR="$HOME/Applications/FW_Image"
APP_PATH="$HOME/Applications/FW_Image.app"

echo ""
echo "═══════════════════════════════════════════════"
echo "  🎨 Fireworks Image Generator — Установка"
echo "═══════════════════════════════════════════════"
echo ""

# ─── 1. Python ──────────────────────────────────────────────
echo "[1/5] Проверяю Python 3..."
PY=""
if [ -x "/opt/homebrew/bin/python3" ]; then PY="/opt/homebrew/bin/python3"
elif [ -x "/usr/local/bin/python3" ]; then PY="/usr/local/bin/python3"
elif command -v python3 &>/dev/null; then PY="$(command -v python3)"
fi
if [ -z "$PY" ]; then
    echo "❌ Python 3 не найден! Установите: https://www.python.org/downloads/"
    exit 1
fi
echo "   ✅ $("$PY" --version 2>&1)"

# ─── 2. pywebview ───────────────────────────────────────────
echo "[2/5] Проверяю pywebview..."
if "$PY" -c "import webview" 2>/dev/null; then
    echo "   ✅ Уже установлен"
else
    echo "   📦 Устанавливаю..."
    "$PY" -m pip install pywebview --break-system-packages -q 2>/dev/null || \
    "$PY" -m pip install pywebview -q 2>/dev/null || \
    { echo "❌ Не удалось. Попробуйте: $PY -m pip install pywebview"; exit 1; }
    echo "   ✅ Установлен"
fi

# ─── 3. Скачиваю файлы ─────────────────────────────────────
echo "[3/5] Скачиваю файлы..."
mkdir -p "$INSTALL_DIR/generated_images"
curl --http1.1 -fsSL "$REPO/server.py" -o "$INSTALL_DIR/server.py"
curl --http1.1 -fsSL "$REPO/index.html" -o "$INSTALL_DIR/index.html"
curl --http1.1 -fsSL "$REPO/AppIcon.icns" -o "$INSTALL_DIR/AppIcon.icns"
echo "   ✅ Файлы загружены"

# ─── 4. Создаю .app ────────────────────────────────────────
echo "[4/5] Создаю приложение..."
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

# Иконка
cp "$INSTALL_DIR/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns" 2>/dev/null

# Launcher
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

# Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
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
touch "$APP_PATH"
echo "   ✅ Приложение создано"

# ─── 5. Готово ──────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ Установка завершена!"
echo "═══════════════════════════════════════════════"
echo ""
echo "  🚀 Запускай: ~/Applications/FW_Image.app"
echo "  📂 Картинки: ~/Applications/FW_Image/generated_images/"
echo "  🔑 При первом запуске введи API ключ Fireworks AI"
echo ""
