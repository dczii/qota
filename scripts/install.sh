#!/usr/bin/env bash
# Builds Qota and installs it as an app bundle in ~/Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${INSTALL_DIR:-$HOME/Applications}/Qota.app"

cd "$ROOT"
echo "Building Qota (release)..."
swift build -c release

BINARY="$(swift build -c release --show-bin-path)/Qota"
[ -x "$BINARY" ] || { echo "Build did not produce $BINARY" >&2; exit 1; }

# Replacing a running app confuses launch services, so stop it first.
pkill -x Qota 2>/dev/null || true

echo "Installing to ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Qota"

# The icon is drawn from code rather than checked in as a binary. Purely cosmetic,
# and it only shows in Finder since this is a menu-bar app, so never fail the install for it.
ICON_KEY=""
if ICONSET="$(mktemp -d)" && swift "$ROOT/scripts/generate-icon.swift" "$ICONSET/icon_1024.png" 2>/dev/null; then
    for px in 16 32 64 128 256 512; do
        sips -z "$px" "$px" "$ICONSET/icon_1024.png" --out "$ICONSET/icon_${px}x${px}.png" >/dev/null 2>&1
        sips -z $((px * 2)) $((px * 2)) "$ICONSET/icon_1024.png" --out "$ICONSET/icon_${px}x${px}@2x.png" >/dev/null 2>&1
    done
    rm -f "$ICONSET/icon_1024.png"
    mv "$ICONSET" "${ICONSET}.iconset" 2>/dev/null || true
    if iconutil -c icns "${ICONSET}.iconset" -o "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; then
        ICON_KEY="    <key>CFBundleIconFile</key><string>AppIcon</string>"
    fi
    rm -rf "${ICONSET}.iconset"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Qota</string>
    <key>CFBundleDisplayName</key><string>Qota</string>
    <key>CFBundleExecutable</key><string>Qota</string>
    <key>CFBundleIdentifier</key><string>com.qota.Qota</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
$ICON_KEY
    <!-- Menu-bar only: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signing gives the bundle a stable identity, so the Keychain prompt for the
# Cursor CLI token is answered once instead of on every rebuild.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: ad-hoc codesign failed; Keychain may prompt repeatedly" >&2

echo "Installed. Launching..."
open "$APP"
echo "Qota is running — look in the menu bar."
