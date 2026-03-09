fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android build_apk

```sh
[bundle exec] fastlane android build_apk
```

Build a release APK with Flutter

### android build_aab

```sh
[bundle exec] fastlane android build_aab
```

Build a release App Bundle with Flutter

### android screenshot

```sh
[bundle exec] fastlane android screenshot
```

Install the debug APK on a booted emulator/device and capture a screenshot

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Upload the release App Bundle to Google Play

----


## iOS

### ios build_ipa

```sh
[bundle exec] fastlane ios build_ipa
```

Build a signed iOS IPA with Flutter

### ios screenshot

```sh
[bundle exec] fastlane ios screenshot
```

Install the simulator build on a booted iOS simulator and capture a screenshot

### ios deploy

```sh
[bundle exec] fastlane ios deploy
```

Upload the Flutter-built IPA to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
