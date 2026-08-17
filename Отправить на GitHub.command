#!/bin/bash
# Обновляет main, собирает Godot Web, коммитит изменения и отправляет их.
# Любая ошибка до коммита останавливает публикацию.
set -o pipefail
cd "$(dirname "$0")" || exit 1

ROOT="$(pwd)"
REPO="https://github.com/kibugaev1-png/Red-Button"
STAMP=$(date "+%d.%m.%Y %H:%M")
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

abort() {
  echo
  echo "  ✗ $1"
  echo "  Публикация остановлена."
  echo
  read -n 1 -s -r -p "  Нажми любую клавишу, чтобы закрыть" || true
  echo
  exit 1
}

clear
echo "════════════════════════════════════════════════════"
echo "  Отправка в $REPO"
echo "════════════════════════════════════════════════════"
echo

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || abort "Папка не является Git-репозиторием."

BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
  abort "Сейчас открыта ветка «${BRANCH:-без имени}». Переключись на main."
fi

echo "  Обновляю main без перезаписи истории…"
if ! git pull --ff-only origin main 2>&1 | sed 's/^/    /'; then
  abort "Не удалось безопасно обновить main. Разреши конфликт вручную."
fi

if [ ! -x "$GODOT" ]; then
  abort "Godot не найден в /Applications. Установи Godot.app и повтори."
fi

echo
echo "  Собираю актуальную Godot Web-версию…"
mkdir -p "$ROOT/web" || abort "Не удалось подготовить папку web."
if ! "$GODOT" --headless --path "$ROOT/godot" \
    --export-release "Web" "$ROOT/web/index.html" 2>&1 | sed 's/^/    /'; then
  abort "Экспорт Godot Web завершился ошибкой."
fi

for FILE in index.html index.js index.wasm index.pck; do
  if [ ! -s "$ROOT/web/$FILE" ]; then
    abort "После экспорта отсутствует web/$FILE."
  fi
done

echo "  ✓ Godot Web собран."
echo

if [ -z "$(git status --porcelain)" ]; then
  echo "  Изменений нет — коммитить нечего."
else
  echo "  Изменённые файлы:"
  git status --short | sed 's/^/    /'
  echo
  read -p "  Опиши коротко, что сделано (Enter — «Снимок $STAMP»): " MSG
  [ -z "$MSG" ] && MSG="Снимок $STAMP"
  git add -A || abort "Не удалось подготовить файлы к коммиту."
  git -c user.name="Красная кнопка" -c user.email="game@local" \
    commit -q -m "$MSG" || abort "Не удалось создать коммит."
  echo "  ✓ Коммит: $MSG"
fi

echo
echo "  Отправляю на GitHub…"
if git push origin main 2>&1 | sed 's/^/    /'; then
  echo
  echo "  ✓ Готово. Репозиторий актуален:"
  echo "    $REPO"
else
  abort "Push не прошёл. Проверь вход в GitHub и соединение."
fi

echo
read -n 1 -s -r -p "  Нажми любую клавишу, чтобы закрыть"
