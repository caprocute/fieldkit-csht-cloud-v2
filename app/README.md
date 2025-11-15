# 📱 FieldKit Mobile App

Get in-the-field readings and configure your FieldKit device with the FieldKit mobile app. Here's everything you need to get started to build the app.

This version is for contributors or developers, to download the [Android app](https://play.google.com/store/apps/details?id=com.fieldkit) or the [iOS app](https://apps.apple.com/us/app/fieldkit-org/id1463631293).

![screenshot of app](README_image.png)

## Table of Contents
- [App Architecture](#-app-architecture)
- [Prerequisites](#-prerequisites)
- [Setup and Dependencies](#-setup-and-dependencies)
- [Running the Code](#-running-the-code)
- [Running the Tests](#-running-the-tests)
- [Updating Strapi](#-updating-strapi)

## App Architecture 🏛️

### Overview 
This application leverages a multi-layered architecture integrating Flutter, Rust, SQLite, and Strapi to handle frontend operations, data management, and content handling. It interacts with stations for real-time data syncing and provides an efficient way to manage data locally on the device, while syncing relevant updates to a web portal.

1. [Flutter](https://flutter.dev/) / [Dart](https://dart.dev/) - App Frontend and Data Layer
- Handles all UI interactions.
- Handles Backend Logic and Data Management after conversion from Rust.

2. [Rust](https://www.rust-lang.org/) - Original Data Layer
- Manages data and database operations.
- Handles station synchronization.
- Interacts with the Web Portal API.
- Sets up and manages an SQLite database locally on the user's device.

Integration:
- Must be transpiled into Dart before running the app using [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge).

3. [SQLite](https://www.sqlite.org/) - Database
- Stores all necessary data locally on the user’s device.

4. [Strapi](https://strapi.io/) - CMS
- Stores content for tutorials throughout the app, Must update on the Strapi portal and sync to persistently keep data synced. See [updating strapi](#-updating-strapi).

## Prerequisites 🛠 

Before you get started, ensure you have the following installed:

- **Flutter SDK**: [Installation Guide](https://docs.flutter.dev/get-started/install) (for recommended version, see .fvmrc in project root)
- **Rust Language**: [Get Rustup](https://rustup.rs/)
- **Rust Targets**: For cross-compiling to your device. [Read More](https://rust-lang.github.io/rustup/cross-compilation.html)

### Android-Specific Dependencies:
- **cargo-ndk**: [Installation Instructions](https://github.com/bbqsrc/cargo-ndk#installing)
- **Android NDK 22**: After installation, set its path using:

```bash
echo "ANDROID_NDK=path/to/ndk" >> ~/.gradle/gradle.properties
```

## 📦 Setup and Dependencies

### Environment Configuration

1. **Create environment file**:
```bash
cp env.template .env
```

2. **Configure DeskPro API** (for issue reporting):
   - Get an API key from your DeskPro admin panel (Admin → Settings → API)
   - Edit `.env` and replace `YOUR_ACTUAL_DESKPRO_API_KEY_HERE` with your key
   - Format: `DESKPRO_API_KEY=2:your_actual_key_here`

### RustFK

By default, `rustfk` will be downloaded from git when building the native rust
library for the application.

If you're going to be making changes to the rust side of the application, it's
handy to develop against a local working copy of the `rustfk` library.

For most development you can build against the default git revision and no
local copy is necessary.

1. **Clone the Repository**:
```bash
git clone https://gitlab.com/fieldkit/libraries/rustfk
```

2. **Integrate your Rust code**: Edit `api.rs` as needed. Afterwards, get the "just" task runner:
```bash
cargo install just
```

3. **Generate Bridge Files**:
   First, ensure the codegen tool's version matches `flutter_rust_bridge` in `pubspec.yaml` and `flutter_rust_bridge` & `flutter_rust_bridge_macros` inside `native/Cargo.toml`.

```bash
cargo install -f --version 2.0.0-dev.28 flutter_rust_bridge_codegen
```

4. **Run gen**

```just gen```


> 🔧 **Tip**: Whenever you adjust the version in `pubspec.yaml`, ensure to run `flutter clean`.
> 🔧 **Tip2**: If running on Linux, run the following command before all else.
>```sudo apt-get install build-essential libssl-dev pkg-config libsqlite3-dev libsecret-1-dev```

### 🍏 iOS Troubleshooting

Facing build issues with iOS? Try the following:

- **Licensing issues**:
```bash
xcodebuild -license
```

- **Missing iOS platforms**:
```bash
xcodebuild -downloadPlatform iOS
```

- **Installing simulators**:
```bash
xcodebuild -runFirstLaunch
```

OR

```bash
xcodebuild -downloadAllPlatforms
```

## Running the Code 🏃 

Run the Flutter application with:

```bash
flutter run
```

Run on Linux, MacOS, iPhones, or Android.

### Android Development 🤖

To develop for release on Android make sure to [create a keystore](https://docs.flutter.dev/deployment/android#create-an-upload-keystore) and [build an apk](https://docs.flutter.dev/deployment/android#build-an-apk).

### Errors about `libffi` architecture

First of all, I'm so sorry this is happening to you because this was one of the
most frustrating errors I've ever gotten. There's a clue in the build log,
though, which is rare. It suggests this:

```
sudo gem uninstall ffi && sudo arch -x86_64 gem install ffi -- --enable-libffi-alloc
```

Somehwat related, if you find you get the opposite error, you may need to
specify the architecture then as well, for example:

```
arch -x86_64 pod repo update
```

### Errors about `#import <FlutterMacOS/FlutterMacOS.h>`

This is usually the `MACOS_DEPLOYMENT_TARGET` and friends.

Double check the `post_install` step of the `Podfile` and be sure that
`flutter_additional_macos_build_settings` is being called, or
`flutter_additional_ios_build_settings` for `iOS`.

## 🧪 Running the Tests

Test the Flutter application with:

```bash
flutter test
```

## 📖 Updating Strapi
To Update Strapi, or the static content, run:
```bash
just sync
```
then
```bash
just test
```
