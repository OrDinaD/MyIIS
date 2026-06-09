#!/bin/bash
set -e

# Переходим в корень проекта
cd "$(dirname "$0")/.."

echo "🚀 Начинаем сборку MyIIS для AltStore/SideStore..."

# Папка для сборки
BUILD_DIR="$(pwd)/build_sideload"
# Удаляем старую папку сборки, чтобы избежать конфликтов и необходимости вызывать clean
rm -rf "$BUILD_DIR"

# Собираем основной таргет (scheme MyIIS).
# Отключаем подпись, чтобы собрать приложение без Apple Developer Account.
# AltStore/SideStore сами переподпишут приложение при установке.
echo "🔨 Компиляция проекта..."
xcodebuild build \
  -project MyIIS.xcodeproj \
  -scheme MyIIS \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR"

cd "$BUILD_DIR"

# Удаляем плагины (виджеты, интенты и т.д.), чтобы они не расходовали App ID
# в бесплатном аккаунте разработчика, где есть лимит в 3/10 App ID.
echo "🧹 Удаление расширений (виджетов и интентов)..."
if [ -d "MyIIS.app/PlugIns" ]; then
  rm -rf MyIIS.app/PlugIns
  echo "✅ Папка PlugIns удалена."
else
  echo "ℹ️ Папка PlugIns не найдена."
fi

if [ -d "MyIIS.app/Extensions" ]; then
  rm -rf MyIIS.app/Extensions
  echo "✅ Папка Extensions удалена."
fi

# Упаковываем в IPA
echo "📦 Создание IPA файла..."
mkdir -p Payload
cp -r MyIIS.app Payload/
zip -qr MyIIS-AltStore.ipa Payload
rm -rf Payload

echo "✅ Успех! IPA файл для AltStore/SideStore сохранен по пути: $BUILD_DIR/MyIIS-AltStore.ipa"
