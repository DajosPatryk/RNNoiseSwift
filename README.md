 # Swift Implementation - RNNoise

Swift wrapper for [RNNoise](https://github.com/xiph/rnnoise?tab=readme-ov-file) C library.
Building manually is not required.
Run `./autogen.sh` or upload your own model to `Libraries/RNNoise` before running. It is recommended to clone this repository and adding the package locally.

## How To Use
1. Create class `RNNoise`.
2. Use function `process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer?`
> **Note:** Buffers must be RAW PCM format, Float32.

## How To Build Manually

### Building C Library For Apple Devices
Make sure `git submodule` is initialized.
1. `cd ./Libraries/RNNoise`
2. Run `./autogen.sh` to download latest model.
3. Run `./configure` with custom `CFLAGS`.
- Command for arm64 Apple iOS: `./configure --host=arm-apple-darwin CC="$(xcrun --sdk iphoneos --find clang)" CFLAGS="-arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path)"`
- Command for arm64 Apple MacOS: `./configure CFLAGS="-arch arm64"`
> **Note:** The C library will has to be built twice, once for iOS and once for MacOS, in order to make it compatible for XCFramework.
4. Build C library with `make`
> **Note:** Clean build files with `make clean`

### Build XCFramework
1. Archive XCFramework
```bash
xcodebuild archive \
-scheme RNNoise \
-destination "generic/platform=iOS" \
-archivePath "RNNoise" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES
```
2. Build for XCFramework - Building C library beforehand is required
```bash
xcodebuild -create-xcframework \
    -library Libraries/RNNoise/.libs/librnnoise.a \
    -headers Libraries/RNNoise/include \
    -output RNNoise.xcframework
```

### Sign XCFramework
Before proceeding check for valid signature with `codesign -dvvv ./RNNoise.xcframework`
1. Find valid certificate name `security find-identity -p codesigning`
2. Sign xcframework with `codesign --force --sign "Your Certificate Name" --timestamp ./RNNoise.xcframework`



