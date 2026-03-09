# Fastlane

Repo-root `fastlane` lanes for Flutter screenshots and store deployment.

## Setup

```bash
bundle install
```

## Android

Build a release APK:

```bash
bundle exec fastlane android build_apk
```

Capture a screenshot from a booted emulator/device:

```bash
bundle exec fastlane android screenshot
```

Optional:

- `ANDROID_SERIAL=<device-id>` to target a specific emulator/device
- `FASTLANE_SCREENSHOT_DELAY=8` to wait longer before capture

Deploy to Google Play internal track:

```bash
SUPPLY_JSON_KEY=/absolute/path/to/google-play-service-account.json \
bundle exec fastlane android deploy
```

Optional:

- `FASTLANE_ANDROID_TRACK=production|beta|internal`
- `FASTLANE_ANDROID_PACKAGE_NAME=com.example.app`

## iOS

Build a release IPA:

```bash
bundle exec fastlane ios build_ipa
```

Capture a screenshot from a booted simulator:

```bash
bundle exec fastlane ios screenshot
```

Optional:

- `IOS_SIMULATOR_DEVICE=<simulator-udid-or-booted>`
- `FASTLANE_SCREENSHOT_DELAY=8`

Deploy to TestFlight:

```bash
APP_STORE_CONNECT_KEY_ID=... \
APP_STORE_CONNECT_ISSUER_ID=... \
APP_STORE_CONNECT_KEY_FILE=/absolute/path/to/AuthKey_ABC123XYZ.p8 \
bundle exec fastlane ios deploy
```

Optional:

- `FASTLANE_APP_IDENTIFIER=com.example.app`
- `FASTLANE_APPLE_ID=name@example.com`
- `FASTLANE_TEAM_ID=<developer-team-id>`
- `FASTLANE_ITC_TEAM_ID=<app-store-connect-team-id>`

## Notes

- Android deployment uploads the generated `.aab`, not the `.apk`.
- iOS deployment uploads to TestFlight; App Store production submission is a separate release step.
- Screenshot lanes capture the launched app on an already booted simulator/emulator. If you need in-app navigation screenshots, add deterministic UI automation first.
