#!/usr/bin/env python3
"""Локальный сервер Godot Web. Корень перенаправляется в папку web/.

Запуск:  python3 serve.py [порт]
Папку определяем по расположению этого файла, а не по текущей рабочей:
так скрипт работает и из двойного клика, и из песочницы.
"""
import http.server
import socketserver
import sys
import urllib.parse
import pathlib

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4986
ROOT = pathlib.Path(__file__).resolve().parent


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def _redirect_entrypoint(self):
        clean = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
        if clean not in ('/', '/index.html'):
            return False
        self.send_response(302)
        self.send_header('Location', '/web/')
        self.end_headers()
        return True

    def do_GET(self):
        if not self._redirect_entrypoint():
            super().do_GET()

    def do_HEAD(self):
        if not self._redirect_entrypoint():
            super().do_HEAD()

    def guess_type(self, path):
        # без явной кодировки браузер читает русский текст как кракозябры
        base = super().guess_type(path)
        if str(path).endswith(('.html', '.htm')):
            return 'text/html; charset=utf-8'
        if str(path).endswith('.js'):
            return 'application/javascript; charset=utf-8'
        # без этого типа браузер отказывается запускать веб-сборку Godot
        if str(path).endswith('.wasm'):
            return 'application/wasm'
        if str(path).endswith('.pck'):
            return 'application/octet-stream'
        return base

    def end_headers(self):
        # без кэша: игрок всегда получает свежую сборку
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stdout.write('  ' + (fmt % args) + '\n')
        sys.stdout.flush()


socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('0.0.0.0', PORT), Handler) as srv:
    print(f'Красная кнопка — сервер на порту {PORT}')
    print(f'  здесь:  http://localhost:{PORT}/')
    print(f'  папка:  {ROOT}')
    sys.stdout.flush()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print('\nСервер остановлен.')
