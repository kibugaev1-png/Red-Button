#!/bin/bash
# Возвращает игру к любому сохранённому снимку.
cd "$(dirname "$0")"
echo "Снимки (сверху — самый свежий):"
echo
git log --pretty=format:"%h|%ad|%s" --date=format:"%d.%m %H:%M" | head -15 | nl -w2 -s') ' | \
  awk -F'|' '{gsub(/\|/," ",$0); print "  "$0}'
echo
echo "Перед откатом текущее состояние сохраняется автоматически."
read -p "Номер снимка для отката (Enter — отмена): " N
[ -z "$N" ] && echo "Отменено." && exit 0

HASH=$(git log --pretty=format:"%h" | sed -n "${N}p")
if [ -z "$HASH" ]; then echo "Нет такого номера."; read -n 1 -s -r; exit 1; fi

git add -A >/dev/null 2>&1
git -c user.name="Красная кнопка" -c user.email="game@local" commit -q -m "Перед откатом $(date '+%d.%m %H:%M')" >/dev/null 2>&1
git checkout -q "$HASH" -- .
echo "✓ Откатились к снимку $HASH"
echo "  Пересобери приложение: «Собрать приложение.command»"
read -n 1 -s -r -p "Нажми любую клавишу, чтобы закрыть"
