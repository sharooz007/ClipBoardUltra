#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="ClipBoardUltra"
DMG_NAME="ClipBoardUltra.dmg"
VOL_NAME="ClipBoardUltra"
STAGING_DIR="build/dmg_staging"
FINAL_DMG="$PROJECT_DIR/$DMG_NAME"

echo "=========================================="
echo "  Packaging $APP_NAME into DMG"
echo "=========================================="

# 1. Ensure ClipBoardUltra.app exists
if [ ! -d "ClipBoardUltra.app" ]; then
    echo "==> ClipBoardUltra.app not found. Running build.sh first..."
    NO_LAUNCH=1 ./scripts/build.sh
fi

# 2. Ensure background graphics exist (Retina HiDPI TIFF + PNGs)
find_valid_sdk() {
    local candidates=()
    local default_sdk
    default_sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
    [ -n "$default_sdk" ] && candidates+=("$default_sdk")
    [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" ] && candidates+=("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
    for d in /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk; do
        [ -d "$d" ] && candidates+=("$d")
    done

    for candidate in "${candidates[@]}"; do
        if [ -d "$candidate" ] && echo "import Foundation" | swiftc -sdk "$candidate" - -o /dev/null >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done
    xcrun --show-sdk-path
}
SDK_PATH="$(find_valid_sdk)"
ARCH="$(uname -m)"

swiftc -sdk "$SDK_PATH" -target "$ARCH-apple-macos13.0" scripts/generate_dmg_background.swift -o build/gen_dmg_bg
./build/gen_dmg_bg build

# 3. Clean up staging directory and old DMG
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "ClipBoardUltra.app" "$STAGING_DIR/"

# Unmount any existing volume with the same name to prevent busy errors
if [ -d "/Volumes/$VOL_NAME" ]; then
    echo "==> Unmounting existing /Volumes/$VOL_NAME..."
    hdiutil detach "/Volumes/$VOL_NAME" -force 2>/dev/null || true
fi

# 4. Use create-dmg for pixel-perfect Finder aesthetics and robust .DS_Store generation
echo "==> Building DMG with create-dmg..."
CREATE_DMG="/opt/homebrew/bin/create-dmg"
if [ ! -x "$CREATE_DMG" ]; then
    CREATE_DMG="$(which create-dmg || true)"
fi

if [ -n "$CREATE_DMG" ] && [ -x "$CREATE_DMG" ]; then
    "$CREATE_DMG" \
        --volname "$VOL_NAME" \
        --volicon "Resources/AppIcon.icns" \
        --background "build/dmg_background.tiff" \
        --window-pos 200 120 \
        --window-size 680 440 \
        --icon-size 100 \
        --text-size 12 \
        --icon "ClipBoardUltra.app" 175 215 \
        --app-drop-link 505 215 \
        --hide-extension "ClipBoardUltra.app" \
        --format UDZO \
        --filesystem HFS+ \
        --hdiutil-quiet \
        --overwrite \
        "$FINAL_DMG" \
        "$STAGING_DIR"
else
    echo "Error: create-dmg not found at /opt/homebrew/bin/create-dmg"
    exit 1
fi

rm -rf "$STAGING_DIR"

echo "=========================================="
echo "  Successfully created: $FINAL_DMG"
FILE_SIZE=$(du -h "$FINAL_DMG" | awk '{print $1}')
echo "  Size: $FILE_SIZE"
echo "  SHA256: $(shasum -a 256 "$FINAL_DMG" | awk '{print $1}')"
echo "=========================================="
