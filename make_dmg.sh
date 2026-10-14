#!/bin/bash
# Собирает PtmobStats.app под Apple Silicon и упаковывает в установочный образ dist/PtmobStats.dmg.
# Запускать на macOS с Xcode 15+ (локально или в GitHub Actions).
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    brew install xcodegen
fi

xcodegen generate

# Подпись «для локального запуска» (ad-hoc) — сертификат разработчика не нужен.
xcodebuild \
    -project PtmobStats.xcodeproj \
    -scheme PtmobStats \
    -configuration Release \
    -derivedDataPath build \
    -destination 'platform=macOS,arch=arm64' \
    ARCHS=arm64 \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM="" \
    build

APP="build/Build/Products/Release/PtmobStats.app"
STAGING="build/dmg"
rm -rf "$STAGING" dist
mkdir -p "$STAGING" dist

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/Как установить.txt" <<'EOF'
1. Перетащите PtmobStats.app в папку Applications.
2. Первый запуск: правый клик по PtmobStats.app в Программах → «Открыть» → «Открыть».
   (Приложение не нотарифицировано Apple, поэтому macOS спросит подтверждение.)
   Если macOS пишет «повреждено», выполните в Терминале:
       xattr -dr com.apple.quarantine /Applications/PtmobStats.app
3. Правый клик по рабочему столу → «Изменить виджеты…» → «Посещаемость ptmob.ru».
EOF

hdiutil create \
    -volname "Посещаемость ptmob.ru" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    dist/PtmobStats.dmg

echo "Готово: dist/PtmobStats.dmg"
