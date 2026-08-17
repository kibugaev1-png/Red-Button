#!/bin/bash
# Поднимает Web-сборку Godot по сети на порту 4986.
# Пока это окно открыто — сервер работает. Закрыл окно или Ctrl+C — погас.
cd "$(dirname "$0")"
PORT=4986

if [ ! -s "web/index.html" ]; then
  echo "Веб-сборка Godot не найдена."
  echo "Сначала запусти «Отправить на GitHub.command» — он соберёт игру."
  echo
  read -n 1 -s -r -p "Нажми любую клавишу, чтобы закрыть"
  exit 1
fi

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

clear
echo "════════════════════════════════════════════════════"
echo "  КРАСНАЯ КНОПКА — GODOT WEB, порт $PORT"
echo "════════════════════════════════════════════════════"
echo
echo "  Тебе на этом компьютере:"
echo "     http://localhost:$PORT/"
echo
if [ -n "$IP" ]; then
  echo "  Другу в той же Wi-Fi:"
  echo "     http://$IP:$PORT/"
else
  echo "  Адрес в сети не определён — проверь Wi-Fi."
fi
echo
echo "  Друг в другой сети по этому адресу НЕ зайдёт."
echo "  Для него есть опубликованная версия:"
echo "     https://kibugaev1-png.github.io/Red-Button/"
echo
echo "  Важно: Godot Web нельзя открыть двойным кликом по HTML —"
echo "  ему нужен этот сервер или страница GitHub Pages."
echo
echo "  Остановить сервер: закрой окно или Ctrl+C."
echo "════════════════════════════════════════════════════"
echo

exec python3 "$(pwd)/serve.py" "$PORT"
