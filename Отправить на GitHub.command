#!/bin/bash
# Коммитит все изменения и отправляет их в главный репозиторий.
# Двойной клик — и на GitHub лежит текущее состояние игры.
cd "$(dirname "$0")"

REPO="https://github.com/kibugaev1-png/Red-Button"
STAMP=$(date "+%d.%m.%Y %H:%M")

clear
echo "════════════════════════════════════════════════════"
echo "  Отправка в $REPO"
echo "════════════════════════════════════════════════════"
echo

if [ -z "$(git status --porcelain)" ]; then
  echo "  Изменений нет — коммитить нечего."
else
  echo "  Изменённые файлы:"
  git status --short | sed 's/^/    /'
  echo
  read -p "  Опиши коротко, что сделано (Enter — «Снимок $STAMP»): " MSG
  [ -z "$MSG" ] && MSG="Снимок $STAMP"
  git add -A
  git -c user.name="Красная кнопка" -c user.email="game@local" commit -q -m "$MSG"
  echo "  ✓ Коммит: $MSG"
fi

echo
echo "  Отправляю на GitHub…"
if git push origin main 2>&1 | sed 's/^/    /'; then
  echo
  echo "  ✓ Готово. Репозиторий актуален:"
  echo "    $REPO"
else
  echo
  echo "  Пуш не прошёл. Обычно причина одна — не введён доступ к GitHub."
  echo "  Проверь, что ты вошёл в GitHub на этом компьютере, и запусти снова."
fi

echo
read -n 1 -s -r -p "  Нажми любую клавишу, чтобы закрыть"
