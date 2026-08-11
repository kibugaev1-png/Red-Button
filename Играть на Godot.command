#!/bin/bash
# Запускает версию игры на Godot. Двойной клик — и играешь.
cd "$(dirname "$0")/godot"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$GODOT" ]; then
  echo "Godot не найден в /Applications. Перетащи Godot.app в Программы и запусти снова."
  read -n 1 -s -r -p "Нажми любую клавишу"; exit 1
fi
echo "Красная кнопка — запуск. Мир генерируется около секунды."
exec "$GODOT" --path .
