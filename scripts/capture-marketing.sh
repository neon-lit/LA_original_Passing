#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
PROJECT_FILE="$PROJECT_ROOT/LA_original_Passing.xcodeproj"
SCHEME="LA_original_Passing"
BUNDLE_ID="app.taira.komugi.Passing"
DEVICE_ID="${MARKETING_DEVICE_ID:-46C1B6E6-8C76-4476-92ED-459B7E7C31E1}"
DERIVED_DATA="$PROJECT_ROOT/.build/marketing-capture"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LA_original_Passing.app"
OUTPUT_DIR="$PROJECT_ROOT/marketing/ja"

mkdir -p "$OUTPUT_DIR"
find "$OUTPUT_DIR" -maxdepth 1 -type f \( -name '*.png' -o -name 'capture-complete.txt' \) -delete

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  build

xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
  -MarketingCapture 1 \
  -AppleLanguages '(ja)' \
  -AppleLocale ja_JP

CONTAINER="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"
CAPTURE_DIR="$CONTAINER/Documents/marketing/ja"

for attempt in {1..60}; do
  if [[ -f "$CAPTURE_DIR/capture-complete.txt" ]]; then
    cp "$CAPTURE_DIR"/*.png "$OUTPUT_DIR/"
    print "Captured screenshots to $OUTPUT_DIR"
    exit 0
  fi
  sleep 1
done

print -u2 "Timed out waiting for marketing captures in $CAPTURE_DIR"
exit 1
