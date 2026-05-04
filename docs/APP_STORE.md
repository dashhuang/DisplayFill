# DisplayFill Mac App Store Release

This document covers the Mac App Store path. The existing direct-download release flow stays in [RELEASE.md](./RELEASE.md).

## Project Setup

- `AppStore` build configuration uses `DisplayFill/LightAppStore.entitlements`.
- The App Store build is sandboxed with `com.apple.security.app-sandbox`.
- `Info.plist` declares `LSApplicationCategoryType` as `public.app-category.utilities`.
- `PrivacyInfo.xcprivacy` declares no tracking and no collected data.

## App Store Connect Setup

Create the app in App Store Connect before uploading the first build:

- Platform: macOS
- Name: DisplayFill
- Bundle ID: `cn.huang.dash.DisplayFill`
- Primary category: Utilities
- SKU: any stable internal value, for example `displayfill-macos`
- Privacy Policy URL: required before submission

Suggested privacy answer: the app does not collect user data. The app reads local display geometry, HDR headroom, and pointer position only on-device to render the fill-light overlay and pointer cutout.

## Local Validation

Run:

```bash
xcodebuild \
  -project DisplayFill.xcodeproj \
  -scheme DisplayFill \
  -configuration AppStore \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Then test a signed sandbox build from Xcode or by archiving with the App Store configuration.

## Export Without Uploading

```bash
./scripts/release_app_store.sh
```

This creates an App Store Connect export under `dist/appstore/export` but does not upload it.

## Upload Build

Only upload after the App Store Connect app record exists.

Using the Apple account already configured in Xcode:

```bash
UPLOAD=1 ./scripts/release_app_store.sh
```

Using an App Store Connect API key:

```bash
ASC_KEY_PATH="/path/to/AuthKey_KEYID.p8" \
ASC_KEY_ID="KEYID" \
ASC_ISSUER_ID="ISSUER_UUID" \
UPLOAD=1 \
./scripts/release_app_store.sh
```

After upload, App Store Connect needs time to process the build before it can be selected for TestFlight or App Review.

## Review Notes

Suggested App Review note:

> DisplayFill is a local macOS utility that turns the display edges into an adjustable fill light for video calls and low-light work. It does not record the screen, use the camera or microphone, send display contents over the network, or collect user data. The app reads local display geometry, HDR headroom, and pointer position only to place the overlay, support multiple displays, and render the pointer cutout.

Before submitting for review, verify the sandbox build on:

- Single built-in display
- Built-in display plus external display
- HDR enabled and disabled
- Menu opening on each display
- Pointer cutout movement
