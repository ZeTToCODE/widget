#!/bin/bash
# Сборка и установка виджета на Mac с Apple Silicon (M4).
# Требуется Xcode 15+ (из App Store). XcodeGen ставится через Homebrew автоматически.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Нужен Homebrew: https://brew.sh" >&2
        exit 1
    fi
    brew install xcodegen
fi

xcodegen generate

# Подпись «для локального запуска» (ad-hoc) — Apple ID не нужен.
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
rm -rf /Applications/PtmobStats.app
cp -R "$APP" /Applications/
open /Applications/PtmobStats.app

echo
echo "Готово. Правый клик по рабочему столу → «Изменить виджеты…» → «Посещаемость ptmob.ru»."
