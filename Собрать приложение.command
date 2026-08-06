#!/bin/bash
# Собирает «Красная кнопка.app» — настоящее приложение macOS без браузера.
# Двойной клик по этому файлу пересобирает приложение из текущего кода.
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"
APP="$ROOT/Красная кнопка.app"
NAME="Красная кнопка"

# Берём SDK, который понимает установленный компилятор: самый новый из
# поддерживаемых. SDK от более свежей Xcode компилятору не по зубам
SDK=""
for cand in /Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk \
            /Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
            /Library/Developer/CommandLineTools/SDKs/MacOSX14.5.sdk; do
  [ -d "$cand" ] && SDK="$cand" && break
done
[ -z "$SDK" ] && SDK="$(xcrun --show-sdk-path)"
SWIFT=(swiftc -O -sdk "$SDK" -target arm64-apple-macos12)
echo "▸ Сборка приложения из $ROOT"
rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build

# 1. значок
"${SWIFT[@]}" app/icon.swift -o build/makeicon
mkdir -p build/icon.iconset
./build/makeicon build/icon.iconset >/dev/null
iconutil -c icns build/icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

# 2. исполняемый файл; путь к папке с игрой зашивается внутрь,
#    поэтому правки в js видны сразу после перезапуска приложения
sed "s|@@GAME_DIR@@|$ROOT|g" app/main.swift > build/main.swift
"${SWIFT[@]}" build/main.swift -o "$APP/Contents/MacOS/$NAME"

# 3. копия игры внутрь приложения — на случай переноса на другой компьютер
mkdir -p "$APP/Contents/Resources/game"
cp -R index.html js "$APP/Contents/Resources/game/"

# 4. паспорт приложения
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>local.redbutton.game</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 5. локальная подпись, чтобы система не ругалась
codesign --force --deep --sign - "$APP" 2>/dev/null || true
rm -rf build

echo "✓ Готово: $APP"
echo "  Запусти двойным кликом. Cmd+R — перезапустить игру, Cmd+F — во весь экран."
