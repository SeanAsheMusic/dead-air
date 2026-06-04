# Dead Air Signing and Distribution

Dead Air is sandbox-first for both App Store and Developer ID builds.

## Local Ad-Hoc Build

```sh
./Scripts/build_app.sh --local
```

Output:

`dist/Dead Air.app`

This is a real double-clickable `.app` bundle for local development and rehearsal on this Mac. It is not a polished public installer: if you send it to another Mac, Gatekeeper may warn or block it until the app is Developer ID signed and notarized.

## Sandbox Test Build

```sh
./Scripts/build_app.sh --sandbox
```

Output:

`dist-sandbox/Dead Air.app`

## Developer ID Build

After the Apple Developer account and Developer ID certificate are available:

```sh
DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Undeniable Spectacle" ./Scripts/build_app.sh --developer-id
```

Output:

`dist-developer-id/Dead Air.app`

## Release DMG, Notarization, And Stapling

Use the release packager for direct-download beta or release distribution:

```sh
DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Undeniable Spectacle (TEAMID)" \
DEAD_AIR_NOTARY_PROFILE="dead-air-notary" \
./Scripts/package_release_dmg.sh --notarize
```

If a notarytool keychain profile is not configured, provide:

```sh
APPLE_ID="apple-id@example.com" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
APPLE_TEAM_ID="TEAMID" \
DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Undeniable Spectacle (TEAMID)" \
./Scripts/package_release_dmg.sh --notarize
```

Output:

`release/Dead-Air-4.0.0-4.dmg`

The script builds the Developer ID app, verifies the app signature, creates a DMG, signs the DMG, submits it to Apple notarization, staples the ticket, and verifies the stapled DMG with Gatekeeper assessment. A notarized DMG is the shareable artifact that should not require right-click Gatekeeper workarounds.

For an internal signed-only artifact while waiting on Apple credentials:

```sh
DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Undeniable Spectacle (TEAMID)" ./Scripts/package_release_dmg.sh
```

Do not ship the signed-only DMG outside trusted internal testing. It is not notarized.

This is the path for a normal direct-download installer or DMG outside the Mac App Store.

## App Store Build

Use the Xcode project/archive path once the signing account is available. Use `Entitlements/DeadAir-AppStore.entitlements` as the entitlement baseline.

This is the path for Mac App Store distribution and App Review.

## Final Verification

- `swift run DeadAirChecks`
- Release build with warnings as errors
- Local launch
- Sandbox launch
- Code-sign verification
- Signed DMG verification
- Notarization submission success
- Stapler success
- Gatekeeper assessment success
- Lightkey External Control Log test
- Ableton/AbleSet MIDI test
- Audio route change test
