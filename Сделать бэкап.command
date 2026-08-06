#!/bin/bash
# Сохраняет снимок текущего состояния игры. Двойной клик — и можно спокойно ломать.
cd "$(dirname "$0")"
STAMP=$(date "+%d.%m.%Y %H:%M")
git add -A
if git diff --cached --quiet; then
  echo "Изменений нет — новый снимок не нужен."
else
  git -c user.name="Красная кнопка" -c user.email="game@local" commit -q -m "Снимок $STAMP"
  echo "✓ Снимок сохранён: $STAMP"
fi
echo
echo "Последние снимки:"
git log --pretty=format:"  %h  %ad  %s" --date=format:"%d.%m %H:%M" | head -10
echo
read -n 1 -s -r -p "Нажми любую клавишу, чтобы закрыть"
