#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/MyIIS.xcodeproj}"
SCHEME="${SCHEME:-MyIIS}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
OS_VERSION="${OS_VERSION:-26.5}"
LANGUAGE="${LANGUAGE:-ru-RU}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/fastlane/screenshots/$LANGUAGE}"
RESULT_BUNDLE="${RESULT_BUNDLE:-$ROOT_DIR/build/AppStoreScreenshots.xcresult}"
SCREENSHOT_TEST="${SCREENSHOT_TEST:-MyIISUITests/MyIISUITests/testGenerateAppStoreScreenshots}"
EXPECTED_COUNT="${EXPECTED_COUNT:-10}"
MAX_BYTES="${MAX_BYTES:-10485760}"

mkdir -p "$OUTPUT_DIR" "$ROOT_DIR/build"
find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' -delete
rm -rf "$RESULT_BUNDLE"

DESTINATION="platform=iOS Simulator,name=$DEVICE_NAME,OS=$OS_VERSION"

echo "Generating App Store screenshots"
echo "Project: $PROJECT_PATH"
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"
echo "Output: $OUTPUT_DIR"

SHOWCASE_SCREENSHOT_OUTPUT_DIR="$OUTPUT_DIR" \
xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"$SCREENSHOT_TEST" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -quiet

screenshots=()
while IFS= read -r screenshot; do
  screenshots+=("$screenshot")
done < <(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' | sort)
actual_count="${#screenshots[@]}"
if [[ "$actual_count" -ne "$EXPECTED_COUNT" ]]; then
  echo "Expected $EXPECTED_COUNT screenshots, got $actual_count" >&2
  printf '%s\n' "${screenshots[@]}" >&2
  exit 1
fi

reference_size=""
for file in "${screenshots[@]}"; do
  bytes="$(stat -f '%z' "$file")"
  if [[ "$bytes" -gt "$MAX_BYTES" ]]; then
    echo "Screenshot is larger than 10 MB: $file ($bytes bytes)" >&2
    exit 1
  fi

  properties="$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$file" 2>/dev/null)"
  width="$(awk '/pixelWidth:/ { print $2 }' <<<"$properties")"
  height="$(awk '/pixelHeight:/ { print $2 }' <<<"$properties")"
  alpha="$(awk '/hasAlpha:/ { print $2 }' <<<"$properties")"

  if [[ -z "$width" || -z "$height" ]]; then
    echo "Cannot read PNG dimensions: $file" >&2
    exit 1
  fi
  if [[ "$height" -le "$width" ]]; then
    echo "Screenshot must be portrait: $file (${width}x${height})" >&2
    exit 1
  fi
  if [[ "$alpha" == "yes" ]]; then
    echo "Screenshot must not contain an alpha channel: $file" >&2
    exit 1
  fi

  current_size="${width}x${height}"
  if [[ -z "$reference_size" ]]; then
    reference_size="$current_size"
  elif [[ "$current_size" != "$reference_size" ]]; then
    echo "Screenshot dimensions are inconsistent: $file is $current_size, expected $reference_size" >&2
    exit 1
  fi

  echo "OK $(basename "$file") ${current_size} ${bytes}B"
done

echo "Done: $actual_count screenshots in $OUTPUT_DIR"
