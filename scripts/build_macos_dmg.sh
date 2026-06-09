#!/bin/bash
set -e

echo "🚀 Начинаем сборку MyIIS для MacOS..."

BUILD_DIR="$PWD/build_macos"
APP_NAME="MyIIS"

# Очистка
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 Компиляция проекта для MacOS..."
xcodebuild build \
  -project MyIIS.xcodeproj \
  -scheme MyIIS \
  -configuration Release \
  -destination 'name=My Mac' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR"

echo "🧹 Удаление расширений (виджетов и интентов)..."
rm -rf "$BUILD_DIR/$APP_NAME.app/PlugIns"
rm -rf "$BUILD_DIR/$APP_NAME.app/Extensions"

echo "📦 Создание DMG файла..."
DMG_NAME="$BUILD_DIR/$APP_NAME.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$BUILD_DIR/$APP_NAME.app" -ov -format UDZO "$DMG_NAME"

echo "✅ Успех! DMG файл сохранен по пути: $DMG_NAME"
