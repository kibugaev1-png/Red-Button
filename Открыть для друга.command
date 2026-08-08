#!/bin/bash
# Поднимает игру по сети: друг в той же Wi-Fi открывает адрес в браузере и играет.
# Пока это окно открыто — сервер работает. Закрыл окно или Ctrl+C — сервер погас.
cd "$(dirname "$0")"
PORT=8080

# локальный адрес в сети: именно его надо отправить другу
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

clear
echo "════════════════════════════════════════════════════"
echo "  КРАСНАЯ КНОПКА — сервер для игры по сети"
echo "════════════════════════════════════════════════════"
echo
echo "  Тебе на этом компьютере:"
echo "     http://localhost:$PORT/"
echo
if [ -n "$IP" ]; then
  echo "  Другу — если он в той же Wi-Fi, пусть откроет:"
  echo "     http://$IP:$PORT/"
else
  echo "  Не смог определить адрес в сети — проверь, что Wi-Fi включён."
fi
echo
echo "  Друг вне твоей сети? Тогда отправь ему ссылку из чата"
echo "  или сам файл «Красная кнопка v2.html» — он откроется двойным кликом."
echo
echo "  Сервер работает, пока это окно открыто."
echo "  Чтобы остановить — закрой окно или нажми Ctrl+C."
echo "════════════════════════════════════════════════════"
echo

# отдаём одностраничную сборку как главную страницу
python3 - "$PORT" "$PWD" <<'PY'
import http.server, socketserver, sys, urllib.parse, pathlib

# папку берём из аргумента, а не из текущей: так надёжнее при двойном клике
PORT = int(sys.argv[1])
ROOT = pathlib.Path(sys.argv[2])
BUNDLE = 'Красная кнопка v2.html'

class Handler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        clean = urllib.parse.unquote(path.split('?', 1)[0].split('#', 1)[0])
        if clean in ('/', '/index.html'):
            return str(ROOT / BUNDLE)
        return super().translate_path(path)

    def end_headers(self):
        # запрещаем кэш: друг всегда получает свежую сборку
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        super().end_headers()

    def log_message(self, fmt, *args):
        print('  запрос:', fmt % args)

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('0.0.0.0', PORT), Handler) as srv:
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print('\n  Сервер остановлен.')
PY
