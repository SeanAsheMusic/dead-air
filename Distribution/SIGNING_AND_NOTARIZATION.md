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

Then notarize, staple, and verify on a clean Mac account.

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
- Lightkey External Control Log test
- Ableton/AbleSet MIDI test
- Audio route change test
