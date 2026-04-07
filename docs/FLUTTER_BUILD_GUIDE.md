# Flutter Build Guide - TruckerCore

Last Updated: 2025-10-06

## System Requirements

### Windows
- Windows 10 or later (64-bit)
- Visual Studio 2022 with "Desktop development with C++" workload
- Flutter SDK 3.0.0 or later
- CMake 3.14 or later

### macOS
- macOS 10.14 or later
- Xcode 12 or later
- CocoaPods 1.11 or later
- Flutter SDK 3.0.0 or later

### Linux
- Ubuntu 18.04 or later (or equivalent)
- Clang or GCC
- GTK 3.0 development files
- Flutter SDK 3.0.0 or later

---

## Quick Start

### 1) Install & get dependencies
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2) Run in development
```bash
# Web
flutter run -d chrome

# Windows Desktop
flutter config --enable-windows-desktop
flutter run -d windows

# Android / iOS
flutter run -d android
flutter run -d ios
```

### 3) Build for production
```bash
# Web
flutter build web --release

# Windows
flutter build windows --release

# Android APK / AAB
aflutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## CMake Configuration (Windows)

We proactively set modern policies to avoid plugin warnings.

- CMP0175 (NEW): add_custom_command rejects invalid arguments
- CMP0153 (NEW): exec_program should not be called (use execute_process)

These are pre-configured in `windows/CMakeLists.txt` before the `project()` call.

---

## Build Optimization

### Debug / Profile / Release
```bash
flutter run --debug -d windows
flutter run --profile -d windows
flutter build windows --release
```

### Useful flags
```bash
# Verbose output
flutter build windows --verbose

# Tree shake icons
flutter build windows --tree-shake-icons

# Analyze bundle size
flutter build windows --analyze-size

# Obfuscation example
flutter build windows --obfuscate --split-debug-info=./debug-info
```

---

## Code Generation

We use Freezed/JsonSerializable. Generate with:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
# or
flutter pub run build_runner watch --delete-conflicting-outputs
```

To clean generated outputs:
```bash
flutter pub run build_runner clean
```

---

## Troubleshooting

### CMake warnings persist
1. Clean everything
```bash
flutter clean
rm -rf windows/flutter/ephemeral
rm -rf build
```
2. Verify CMake policies are set before `project()` in `windows/CMakeLists.txt`.
3. Update plugins
```bash
flutter pub upgrade
flutter pub outdated
```

### Build fails
1. Check Visual Studio toolchain
```powershell
where cl.exe
```
2. Verify Flutter setup
```bash
flutter doctor -v
```
3. Clean and rebuild
```bash
flutter clean && flutter pub get && flutter build windows
```

### Plugin errors
```bash
flutter clean && flutter pub get
```

---

## Continuous Integration (Windows example)
```yaml
name: Flutter Windows Build
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - name: Install dependencies
        run: flutter pub get
      - name: Generate code
        run: flutter pub run build_runner build --delete-conflicting-outputs
      - name: Analyze
        run: flutter analyze
      - name: Test
        run: flutter test
      - name: Build Windows (Release)
        run: flutter build windows --release
```

---

## Verification Scripts

Use the prebuilt scripts to validate your local environment quickly:

- Linux/macOS:
```bash
chmod +x scripts/verify_flutter_build.sh
./scripts/verify_flutter_build.sh
```

- Windows PowerShell:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./scripts/verify_flutter_build.ps1
```

---

## Support
- Run `flutter doctor -v` and address any reported issues.
- File issues in the repository with logs and environment details.
