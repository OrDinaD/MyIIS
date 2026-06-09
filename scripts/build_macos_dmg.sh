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
  -destination 'platform=macOS,variant=Mac Catalyst' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR"

echo "🧹 Удаление расширений (виджетов и интентов)..."
rm -rf "$BUILD_DIR/$APP_NAME.app/PlugIns"
rm -rf "$BUILD_DIR/$APP_NAME.app/Extensions"

echo "🔐 Подписание приложения (Ad-hoc)..."
codesign -s - -f --deep "$BUILD_DIR/$APP_NAME.app"

echo "📦 Создание DMG файла..."
DMG_NAME="$BUILD_DIR/$APP_NAME.dmg"
TMP_DMG_DIR="$BUILD_DIR/dmg_tmp"
rm -rf "$TMP_DMG_DIR"
mkdir -p "$TMP_DMG_DIR"
mv "$BUILD_DIR/$APP_NAME.app" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DMG_NAME"
rm -rf "$TMP_DMG_DIR"

echo "✅ Успех! DMG файл сохранен по пути: $DMG_NAME"
