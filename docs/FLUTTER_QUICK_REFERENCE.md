# Flutter Quick Reference - TruckerCore

## Essential Commands

### Setup
```bash
flutter doctor                              # Check installation
flutter pub get                             # Get dependencies
flutter pub upgrade                         # Upgrade packages
```

### Code Generation
```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter pub run build_runner watch          # Watch mode
flutter pub run build_runner clean          # Clean generated files
```

### Development
```bash
flutter run -d chrome                       # Run on Chrome
flutter run -d windows                      # Run on Windows
flutter run -d android                      # Run on Android
flutter run --debug                         # Debug mode
flutter run --profile                       # Profile mode
flutter run --release                       # Release mode
```

### Testing
```bash
flutter test                                # Run all tests
flutter test test/widget_test.dart          # Run specific test
flutter test --coverage                     # Generate coverage
flutter analyze                             # Analyze code
```

### Building
```bash
flutter build web                           # Build web app
flutter build windows                       # Build Windows app
flutter build apk                           # Build Android APK
flutter build appbundle                     # Build Android bundle
flutter build ios                           # Build iOS app
```

### Cleaning
```bash
flutter clean                               # Clean build files
flutter pub cache repair                    # Repair pub cache
rm -rf .dart_tool build                     # Manual clean
```

### Hot Reload/Restart
```
r                                           # Hot reload (in running app)
R                                           # Hot restart
q                                           # Quit
```

### DevTools
```bash
flutter pub global activate devtools        # Install DevTools
flutter pub global run devtools             # Run DevTools
```

### Package Management
```bash
flutter pub add package_name                # Add package
flutter pub remove package_name             # Remove package
flutter pub outdated                        # Check outdated packages
flutter pub upgrade package_name            # Upgrade specific package
```

### Platform Specific
```bash
# Windows
flutter config --enable-windows-desktop

# macOS
flutter config --enable-macos-desktop

# Linux
flutter config --enable-linux-desktop

# Web
flutter config --enable-web
```

### Troubleshooting
```bash
flutter doctor -v                           # Verbose doctor output
flutter clean && flutter pub get            # Clean and reinstall
flutter pub cache repair                    # Repair cache
flutter channel stable && flutter upgrade   # Update Flutter
```

### Performance
```bash
flutter run --profile                       # Profile performance
flutter build --analyze-size                # Analyze bundle size
flutter run --trace-startup                 # Trace startup time
```

### Debugging
```bash
flutter logs                                # Show logs
flutter screenshot                          # Take screenshot
flutter symbolize <stack_trace.txt>         # Symbolize stack trace
```

### Keyboard Shortcuts (in running app)
Key  | Action
---- | ------
r    | Hot reload
R    | Hot restart
h    | Help
c    | Clear screen
q    | Quit
d    | Detach
s    | Save screenshot
w    | Dump widget hierarchy
t    | Dump rendering tree
L    | Dump layer tree
S    | Dump accessibility tree
U    | Dump Semantics tree
i    | Toggle widget inspector
p    | Toggle performance overlay
P    | Toggle platform mode
o    | Simulate OS accessibility
b    | Toggle brightness

### Build Variants
- Debug: Assertions enabled, service extensions enabled, debugging enabled, JIT compilation
- Profile: Some assertions disabled, service extensions enabled, tracing enabled, AOT compilation
- Release: Assertions disabled, debugging disabled, optimized for performance, AOT compilation

### Environment Variables
```bash
# Flutter SDK path
export FLUTTER_ROOT=/path/to/flutter

# Android SDK
export ANDROID_HOME=/path/to/android-sdk

# Disable analytics
export FLUTTER_ANALYTICS_DISABLED=1

# Enable verbose logging
export FLUTTER_VERBOSE=1
```

Tip: Add these to your shell profile (.bashrc, .zshrc, etc.) for persistent configuration.
