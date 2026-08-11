#!/usr/bin/env python3
"""Собирает всю игру в один HTML-файл.

Нужен, чтобы игру можно было отправить одним файлом и открыть без сервера.
После правок в js/ запускать обязательно, иначе файл отстанет от исходников.
"""
import re, pathlib, datetime

ROOT = pathlib.Path(__file__).resolve().parent
OUT = ROOT / 'Красная кнопка v2.html'
html = (ROOT / 'index.html').read_text(encoding='utf-8')

# вместо каждого <script src=...> вставляем сам код
def inline(m):
    src = m.group(1).split('?')[0]
    code = (ROOT / src).read_text(encoding='utf-8')
    return '<script>\n// ---- ' + src + ' ----\n' + code + '\n</script>'

html = re.sub(r'<script src="([^"]+)"></script>', inline, html)

# кодировку указываем явно: без неё русский текст читается кракозябрами
if 'charset' not in html:
    html = html.replace('<head>', '<head>\n<meta charset="utf-8">', 1)

stamp = datetime.datetime.now().strftime('%d.%m %H:%M')
html = html.replace('</title>', ' — сборка ' + stamp + '</title>', 1)
OUT.write_text(html, encoding='utf-8')
print('собрано:', OUT.name, round(OUT.stat().st_size / 1024), 'КБ, сборка', stamp)
