#!/usr/bin/env python3
"""
🔌 Fireworks Proxy Server (без зависимостей — только stdlib)
Запускает локальный сервер на http://localhost:8090
Проксирует запросы к Fireworks AI API, обходя CORS.
Также раздаёт HTML-интерфейс.

Запуск:  python3 server.py
Потом:   открой http://localhost:8090 в браузере
"""

import http.server
import json
import os
import sys
import subprocess
import urllib.request
import urllib.error
import ssl
import threading
import base64
from pathlib import Path

# ─── Автоустановка pywebview ───────────────────────────────────
try:
    import webview
except ImportError:
    print("📦 Устанавливаю pywebview (нужны права администратора)...")
    try:
        # Попытка без sudo
        subprocess.check_call([
            sys.executable, "-m", "pip", "install",
            "pywebview", "--break-system-packages", "-q"
        ])
    except (subprocess.CalledProcessError, PermissionError):
        # Запрос пароля через macOS диалог
        subprocess.check_call([
            "osascript", "-e",
            f'do shell script "{sys.executable} -m pip install pywebview --break-system-packages -q" with administrator privileges'
        ])
    import webview

PORT = 8090
FIREWORKS_BASE = "https://api.fireworks.ai"

# Папка для сохранённых картинок
SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR / "generated_images"
OUTPUT_DIR.mkdir(exist_ok=True)

# SSL контекст для urllib
ctx = ssl.create_default_context()


class ReuseHTTPServer(http.server.HTTPServer):
    allow_reuse_address = True
    allow_reuse_port = True


class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    """Раздаёт статику + проксирует /api/* → Fireworks AI"""

    def do_OPTIONS(self):
        """Preflight CORS"""
        self.send_response(200)
        self._cors_headers()
        self.end_headers()

    def do_POST(self):
        if self.path == "/api/save":
            self._handle_save()
        elif self.path == "/api/fetch_image":
            self._fetch_image()
        elif self.path == "/api/copy_to":
            self._copy_to_folder()
        elif self.path == "/api/save_key":
            self._save_key()
        elif self.path.startswith("/api/"):
            self._proxy_post()
        else:
            self.send_error(404)

    def do_GET(self):
        # Главная страница
        if self.path == "/" or self.path == "":
            self.path = "/index.html"
        elif self.path == "/api/history":
            self._list_history()
            return
        elif self.path == "/api/load_key":
            self._load_key()
            return
        elif self.path.startswith("/api/image/"):
            self._serve_image()
            return
        super().do_GET()

    # ── Сохранение/загрузка API ключа ───────────────────────
    def _save_key(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)
            key = data.get("key", "").strip()
            if not key:
                self._json_error(400, "Empty key")
                return
            key_file = SCRIPT_DIR / ".api_key"
            key_file.write_text(key)
            self.send_response(200)
            self._cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True}).encode())
        except Exception as e:
            self._json_error(500, str(e))

    def _load_key(self):
        try:
            key_file = SCRIPT_DIR / ".api_key"
            key = ""
            if key_file.exists():
                key = key_file.read_text().strip()
            self.send_response(200)
            self._cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"key": key}).encode())
        except Exception as e:
            self._json_error(500, str(e))

    # ── Список файлов из generated_images ───────────────────
    def _list_history(self):
        try:
            files = sorted(
                [f.name for f in OUTPUT_DIR.iterdir()
                 if f.is_file() and f.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp')],
                reverse=True
            )
            self.send_response(200)
            self._cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"files": files}).encode())
        except Exception as e:
            self._json_error(500, str(e))

    # ── Отдать картинку из generated_images ─────────────────
    def _serve_image(self):
        try:
            filename = self.path.split("/api/image/", 1)[1]
            # Безопасность: убираем ../ и берём только имя
            filename = Path(filename).name
            filepath = OUTPUT_DIR / filename
            if not filepath.exists():
                self.send_error(404)
                return
            data = filepath.read_bytes()
            self.send_response(200)
            self._cors_headers()
            ext = filepath.suffix.lower()
            ct = {'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp'}
            self.send_header("Content-Type", ct.get(ext.lstrip('.'), 'image/png'))
            self.send_header("Content-Length", len(data))
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            self._json_error(500, str(e))

    # ── Прокси к Fireworks ──────────────────────────────────
    def _proxy_post(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)

            fw_path = data.get("fw_path", "")
            fw_key = data.get("fw_key", "")
            fw_body = data.get("fw_body", {})
            accept = data.get("accept", "application/json")

            if not fw_path or not fw_key:
                self._json_error(400, "Missing fw_path or fw_key")
                return

            url = FIREWORKS_BASE + fw_path
            payload = json.dumps(fw_body).encode()

            req = urllib.request.Request(url, data=payload, method="POST")
            req.add_header("Authorization", f"Bearer {fw_key}")
            req.add_header("Content-Type", "application/json")
            req.add_header("Accept", accept)

            resp = urllib.request.urlopen(req, context=ctx, timeout=120)
            resp_data = resp.read()
            content_type = resp.headers.get("Content-Type", "")

            self.send_response(200)
            self._cors_headers()

            if "image/" in content_type:
                # Бинарная картинка
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", len(resp_data))
                self.end_headers()
                self.wfile.write(resp_data)
            else:
                # JSON
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(resp_data)

        except urllib.error.HTTPError as e:
            err_body = e.read().decode(errors="replace")[:500]
            self._json_error(e.code, err_body)
        except Exception as e:
            self._json_error(500, str(e))

    # ── Скачать картинку по URL (обход CORS) ───────────────
    def _fetch_image(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)
            image_url = data.get("url", "")

            if not image_url:
                self._json_error(400, "No URL")
                return

            req = urllib.request.Request(image_url)
            resp = urllib.request.urlopen(req, context=ctx, timeout=60)
            img_data = resp.read()

            self.send_response(200)
            self._cors_headers()
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", len(img_data))
            self.end_headers()
            self.wfile.write(img_data)
        except Exception as e:
            self._json_error(500, str(e))

    # ── Копировать картинку в выбранную папку ─────────────────
    def _copy_to_folder(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)
            filename = data.get("filename", "")

            if not filename:
                self._json_error(400, "No filename")
                return

            safe = Path(filename).name
            src = OUTPUT_DIR / safe
            if not src.exists():
                self._json_error(404, "File not found")
                return

            # Системный диалог выбора папки
            result = subprocess.run([
                "osascript", "-e",
                'set theFolder to choose folder with prompt "Куда сохранить картинку?"\n'
                'return POSIX path of theFolder'
            ], capture_output=True, text=True, timeout=120)

            if result.returncode != 0:
                self.send_response(200)
                self._cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"cancelled": True}).encode())
                return

            import shutil
            dest_dir = Path(result.stdout.strip())
            dest = dest_dir / safe
            shutil.copy2(str(src), str(dest))

            self.send_response(200)
            self._cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True, "path": str(dest)}).encode())
        except Exception as e:
            self._json_error(500, str(e))

    # ── Сохранение картинки на диск ───────────────────────────
    def _handle_save(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)

            filename = data.get("filename", "image.png")
            image_b64 = data.get("image_b64", "")

            if not image_b64:
                self._json_error(400, "No image data")
                return

            # Убираем data:image/png;base64, если есть
            if "," in image_b64:
                image_b64 = image_b64.split(",", 1)[1]

            image_bytes = base64.b64decode(image_b64)

            # Безопасное имя файла
            safe_name = "".join(c for c in filename if c.isalnum() or c in "._- ").strip()
            if not safe_name:
                safe_name = "image.png"

            filepath = OUTPUT_DIR / safe_name
            filepath.write_bytes(image_bytes)

            self.send_response(200)
            self._cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({
                "ok": True,
                "path": str(filepath),
                "size": len(image_bytes),
            }).encode())

        except Exception as e:
            self._json_error(500, str(e))

    # ── Helpers ─────────────────────────────────────────────
    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json_error(self, code, msg):
        self.send_response(code)
        self._cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"error": msg}).encode())

    def log_message(self, format, *args):
        # Красивый лог
        msg = format % args
        if "POST /api/" in msg:
            print(f"  🔄 {msg}")
        elif "GET /" in msg:
            pass  # не спамим статикой
        else:
            print(f"  📡 {msg}")


def start_server():
    """Запускает HTTP-сервер в фоновом потоке."""
    os.chdir(SCRIPT_DIR)
    server = ReuseHTTPServer(("0.0.0.0", PORT), ProxyHandler)
    server.serve_forever()


def main():
    print()
    print("=" * 50)
    print("🎨 Fireworks Image Generator")
    print("=" * 50)
    print(f"📂 Картинки: {OUTPUT_DIR}")
    print("=" * 50)
    print()

    # Запускаем сервер в фоновом потоке
    t = threading.Thread(target=start_server, daemon=True)
    t.start()

    # Открываем нативное окно — когда закроешь, всё завершится
    webview.create_window(
        "🎨 Fireworks Generator",
        f"http://localhost:{PORT}",
        width=920,
        height=800,
        min_size=(600, 500),
    )
    webview.start()
    print("👋 Закрыто")


if __name__ == "__main__":
    main()
