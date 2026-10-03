#!/bin/bash
# Builds ClipBoardUltra.app, signs it with a stable local identity, installs it to
# /Applications and relaunches it.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="ClipBoardUltra"
BUNDLE_ID="com.ultra.ClipBoardUltra"
APP_BUNDLE="$APP_NAME.app"
INSTALL_PATH="/Applications/$APP_BUNDLE"

# ---------------------------------------------------------------------------
# SDK: prefer the SDK that matches the installed swiftc.
# ---------------------------------------------------------------------------
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
echo "==> SDK: $SDK_PATH ($ARCH)"

mkdir -p build

# ---------------------------------------------------------------------------
# Icon (regenerated from scripts/generate_icon.swift when missing)
# ---------------------------------------------------------------------------
if [ ! -f Resources/AppIcon.icns ]; then
    echo "==> Generating app icon..."
    swiftc -sdk "$SDK_PATH" scripts/generate_icon.swift -o build/genicon
    ./build/genicon build
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
    cp build/Logo.png Resources/Logo.png
fi

# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------
echo "==> Compiling..."
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find Sources/ClipBoardUltra -name '*.swift' | sort)

swiftc -O \
    -sdk "$SDK_PATH" \
    -target "$ARCH-apple-macos13.0" \
    "${SOURCES[@]}" \
    -o "build/$APP_NAME"

# ---------------------------------------------------------------------------
# Bundle
# ---------------------------------------------------------------------------
echo "==> Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "build/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
[ -f Resources/Logo.png ] && cp Resources/Logo.png "$APP_BUNDLE/Contents/Resources/Logo.png"

# ---------------------------------------------------------------------------
# Signing
#
# Ad-hoc signatures change on every build, so macOS forgets the Accessibility
# permission and auto-paste silently stops working. Signing with a persistent
# self-signed certificate keeps the app's identity stable across rebuilds.
# The certificate lives in its own keychain so the login keychain is untouched.
# ---------------------------------------------------------------------------
SIGN_KEYCHAIN="$HOME/Library/Keychains/clipboardultra-signing.keychain-db"
SIGN_KC_PASS="clipboardultra-local"
SIGN_NAME="ClipBoardUltra Local Signing"
NEW_IDENTITY=0

add_keychain_to_search_list() {
    local current
    current=$(security list-keychains -d user | tr -d '"' | xargs)
    if [[ " $current " != *" $SIGN_KEYCHAIN "* ]]; then
        # shellcheck disable=SC2086
        security list-keychains -d user -s $current "$SIGN_KEYCHAIN"
    fi
}

if [ ! -f "$SIGN_KEYCHAIN" ]; then
    echo "==> Creating local signing identity (one time)..."
    TMP=$(mktemp -d)
    cat > "$TMP/cfg" <<EOF
[req]
distinguished_name=dn
prompt=no
[dn]
CN=$SIGN_NAME
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cfg" -extensions ext 2>/dev/null
    openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
        -out "$TMP/id.p12" -passout pass:"$SIGN_KC_PASS" 2>/dev/null \
      || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
        -out "$TMP/id.p12" -passout pass:"$SIGN_KC_PASS"
    security create-keychain -p "$SIGN_KC_PASS" "$SIGN_KEYCHAIN"
    security set-keychain-settings "$SIGN_KEYCHAIN"   # no auto-lock timeout
    security unlock-keychain -p "$SIGN_KC_PASS" "$SIGN_KEYCHAIN"
    security import "$TMP/id.p12" -k "$SIGN_KEYCHAIN" -P "$SIGN_KC_PASS" -T /usr/bin/codesign >/dev/null
    security set-key-partition-list -S apple-tool:,apple: -s -k "$SIGN_KC_PASS" "$SIGN_KEYCHAIN" >/dev/null
    rm -rf "$TMP"
    NEW_IDENTITY=1
fi

security unlock-keychain -p "$SIGN_KC_PASS" "$SIGN_KEYCHAIN"
add_keychain_to_search_list

echo "==> Signing with \"$SIGN_NAME\"..."
codesign --force --options runtime --timestamp=none \
    --keychain "$SIGN_KEYCHAIN" -s "$SIGN_NAME" \
    --identifier "$BUNDLE_ID" "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"

if [ "$NEW_IDENTITY" = "1" ]; then
    # The old ad-hoc permission entry no longer matches; clear it so macOS asks cleanly.
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "    Signing identity changed: grant Accessibility once more after launch (it will stick from now on)."
fi

# ---------------------------------------------------------------------------
# Install & relaunch
# ---------------------------------------------------------------------------
echo "==> Installing to $INSTALL_PATH..."
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5
# Replace contents in place so the path macOS remembers stays the same.
mkdir -p "$INSTALL_PATH"
rsync -a --delete "$APP_BUNDLE/" "$INSTALL_PATH/"
touch "$INSTALL_PATH"   # refresh Finder/Dock icon cache

if [ "${NO_LAUNCH:-0}" != "1" ]; then
    echo "==> Launching..."
    open "$INSTALL_PATH"
fi

echo "==> Done: $INSTALL_PATH"
