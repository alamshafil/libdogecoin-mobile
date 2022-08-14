# libdogecoin-mobile

A script to cross compile libdogecoin for Android arm64 or iOS arm64.

# Usage

## Android

**NOTE: This script downloads the Android NDK which is around ~2 GB**

```bash
./build.sh android
```

Resulting build will be in `libdogecoin-android/build`

For use in Flutter, copy `build/arm64-v8a` `<flutter project>/android/app/src/main/jniLibs/arm64-v8a`

## iOS

**NOTE: This script downloads the iOS toolchain and iOS SDKs which is around ~1.5 GB**

```bash
./build.sh ios
```

Resulting build will be in `libdogecoin-ios/build`

For use in Flutter, add libdogecoin.framework to your Xcode project.
