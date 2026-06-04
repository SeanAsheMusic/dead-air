#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Dead Air"
APP_DIR="$ROOT/dist-developer-id/$APP_NAME.app"
RELEASE_DIR="$ROOT/release"
STAGING_DIR="$ROOT/dmg-staging"
VOLUME_NAME="Dead Air"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Bundle/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Bundle/Info.plist")"
DMG_NAME="Dead-Air-${VERSION}-${BUILD}.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
TMP_DMG="$RELEASE_DIR/Dead-Air-${VERSION}-${BUILD}.tmp.dmg"
NOTARIZE=false

usage() {
  cat >&2 <<EOF
Usage: $0 [--notarize]

Environment:
  DEAD_AIR_SIGN_IDENTITY      Developer ID Application signing identity.
  DEAD_AIR_NOTARY_PROFILE     Optional notarytool keychain profile.
  APPLE_ID                    Apple ID for notarytool, if no profile is used.
  APPLE_APP_PASSWORD          App-specific password for notarytool.
  APPLE_TEAM_ID               Apple Developer team ID for notarytool.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ -z "${DEAD_AIR_SIGN_IDENTITY:-}" ]]; then
  echo "DEAD_AIR_SIGN_IDENTITY is required for a release DMG." >&2
  exit 66
fi

if [[ "$NOTARIZE" == true && -z "${DEAD_AIR_NOTARY_PROFILE:-}" ]]; then
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "Notarization requires DEAD_AIR_NOTARY_PROFILE or APPLE_ID, APPLE_APP_PASSWORD, and APPLE_TEAM_ID." >&2
    exit 66
  fi
fi

cd "$ROOT"
"$ROOT/Scripts/build_app.sh" --developer-id

rm -rf "$RELEASE_DIR" "$STAGING_DIR"
mkdir -p "$RELEASE_DIR" "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

/usr/bin/codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME.app"

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$TMP_DMG" >/dev/null

/usr/bin/hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$TMP_DMG"

/usr/bin/codesign --force --sign "$DEAD_AIR_SIGN_IDENTITY" "$DMG_PATH"
/usr/bin/codesign --verify --strict "$DMG_PATH"

if [[ "$NOTARIZE" == true ]]; then
  if [[ -n "${DEAD_AIR_NOTARY_PROFILE:-}" ]]; then
    /usr/bin/xcrun notarytool submit "$DMG_PATH" --keychain-profile "$DEAD_AIR_NOTARY_PROFILE" --wait
  else
    /usr/bin/xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
  fi
  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
else
  echo "Created signed DMG without notarization. Re-run with --notarize for Gatekeeper-ready distribution." >&2
fi

echo "$DMG_PATH"
