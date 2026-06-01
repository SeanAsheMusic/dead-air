#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Dead Air"
BINARY_NAME="DeadAir"
CONFIGURATION="release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ENTITLEMENTS="$ROOT/Entitlements/DeadAir-DeveloperID.entitlements"
SIGN_IDENTITY="${DEAD_AIR_SIGN_IDENTITY:--}"
CODE_SIGN_OPTIONS=()

case "${1:-}" in
  --sandbox|--app-store)
    DIST_DIR="$ROOT/dist-sandbox"
    APP_DIR="$DIST_DIR/$APP_NAME.app"
    ENTITLEMENTS="$ROOT/Entitlements/DeadAir-AppStore.entitlements"
    ;;
  --developer-id)
    DIST_DIR="$ROOT/dist-developer-id"
    APP_DIR="$DIST_DIR/$APP_NAME.app"
    ENTITLEMENTS="$ROOT/Entitlements/DeadAir-DeveloperID.entitlements"
    SIGN_IDENTITY="${DEAD_AIR_SIGN_IDENTITY:-Developer ID Application}"
    CODE_SIGN_OPTIONS=(--options runtime)
    ;;
  --local|"")
    ;;
  *)
    echo "Usage: $0 [--local|--sandbox|--app-store|--developer-id]" >&2
    exit 64
    ;;
esac

cd "$ROOT"

swift build -c "$CONFIGURATION" --product "$BINARY_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT/.build/$CONFIGURATION/$BINARY_NAME" "$APP_DIR/Contents/MacOS/$BINARY_NAME"
cp "$ROOT/Bundle/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT/Assets/DeadAirLogoMark.png" "$APP_DIR/Contents/Resources/DeadAirLogoMark.png"
for doc in README.md USER_GUIDE.md TECHNICAL_README.md QUICKSTART.md TROUBLESHOOTING.md PRIVACY.md RELEASE_NOTES.md; do
  if [[ -f "$ROOT/$doc" ]]; then
    cp "$ROOT/$doc" "$APP_DIR/Contents/Resources/$doc"
  fi
done

/usr/bin/xattr -cr "$APP_DIR" 2>/dev/null || true
if [[ ${#CODE_SIGN_OPTIONS[@]} -gt 0 ]]; then
  /usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" "${CODE_SIGN_OPTIONS[@]}" --entitlements "$ENTITLEMENTS" "$APP_DIR"
else
  /usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_DIR"
fi
/usr/bin/codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
