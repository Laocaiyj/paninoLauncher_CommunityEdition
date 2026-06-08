#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
APP_NAME="${APP_NAME:-PaninoLauncher}"
BUNDLE_ID="${BUNDLE_ID:-dev.panino.launcher}"
VERSION="${VERSION:-0.1}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="$DIST_DIR/package-work"
APP_BUNDLE="$WORK_DIR/$APP_NAME.app"
DMG_ROOT="$WORK_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
SWIFT_DIR="$ROOT_DIR/macos/PaninoLauncher"
RESOURCE_BUNDLE_NAME="PaninoLauncher_PaninoLauncher.bundle"

echo "==> Building production Core"
"$ROOT_DIR/scripts/build-core-production.sh"
CORE_BIN="$(cd "$ROOT_DIR" && cabal list-bin exe:panino-core --project-file=cabal.project.production)"
if [ ! -x "$CORE_BIN" ]; then
  echo "Core executable not found or not executable: $CORE_BIN" >&2
  exit 1
fi

echo "==> Building Swift app ($CONFIGURATION)"
(cd "$SWIFT_DIR" && swift build -c "$CONFIGURATION")
SWIFT_BIN_DIR="$(cd "$SWIFT_DIR" && swift build -c "$CONFIGURATION" --show-bin-path)"
SWIFT_EXE="$SWIFT_BIN_DIR/$APP_NAME"
SWIFT_RESOURCE_BUNDLE="$SWIFT_BIN_DIR/$RESOURCE_BUNDLE_NAME"
if [ ! -x "$SWIFT_EXE" ]; then
  echo "Swift executable not found or not executable: $SWIFT_EXE" >&2
  exit 1
fi
if [ ! -d "$SWIFT_RESOURCE_BUNDLE" ]; then
  echo "Swift resource bundle not found: $SWIFT_RESOURCE_BUNDLE" >&2
  exit 1
fi

echo "==> Assembling app bundle"
rm -rf "$WORK_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$SWIFT_EXE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$CORE_BIN" "$APP_BUNDLE/Contents/Resources/panino-core"
chmod 755 "$APP_BUNDLE/Contents/Resources/panino-core"
cp -R "$SWIFT_RESOURCE_BUNDLE" "$APP_BUNDLE/$RESOURCE_BUNDLE_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

ICON_SOURCE="$ROOT_DIR/macos/PaninoLauncher/PaninoLauncher/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICON_SOURCE" ] && command -v iconutil >/dev/null 2>&1; then
  ICONSET="$WORK_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET"
  cp "$ICON_SOURCE"/*.png "$ICONSET/"
  if iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"; then
    echo "==> App icon generated"
  else
    echo "Warning: iconutil failed; DMG will still be created without AppIcon.icns" >&2
  fi
else
  echo "Warning: app icon source missing or iconutil unavailable" >&2
fi

if [ "${CODE_SIGN_IDENTITY:-}" ]; then
  echo "==> Code signing app with $CODE_SIGN_IDENTITY"
  codesign --force --deep --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "==> Skipping code signing (set CODE_SIGN_IDENTITY to sign)"
fi

echo "==> Creating DMG"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Created $DMG_PATH"
echo "Unsigned local test DMG is ready. For public distribution, sign with Developer ID and notarize."
