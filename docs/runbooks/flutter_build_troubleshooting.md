# Flutter Build Troubleshooting (Windows)

Common causes of `flutter.bat` exiting with code 1 include:
- Syntax errors or missing imports in Dart code
- Dependency conflicts in pubspec.yaml
- Incorrect assets paths in pubspec.yaml
- Outdated/corrupted Flutter SDK or misconfigured SDK path
- Interference by antivirus software

## Quick Steps

1. Clean and fetch dependencies
```
flutter clean
flutter pub get
```

2. Optionally upgrade dependencies to latest compatible versions
```
flutter pub upgrade --major-versions
```

3. Analyze code
```
dart analyze
```

4. Build with verbose logging to inspect errors
```
flutter build debug --verbose
```

## One‑click script
Run the helper script to automate the above on Windows PowerShell:
```
pwsh -File scripts/flutter_diagnose.ps1
```
Optional switches:
- `-Upgrade` to run `flutter pub upgrade --major-versions`
- `-VerboseBuild` to run a verbose build

Examples:
```
pwsh -File scripts/flutter_diagnose.ps1 -Upgrade -VerboseBuild
```

## Notes for this repo
- Analyzer status: passing (see analysis_output.txt).
- Assets configured: `assets/logo/` in pubspec.yaml.
- If builds fail on Android with AndroidX or Gradle issues, run `flutter doctor -v` and ensure Android toolchain is up-to-date, then re-run the script with `-VerboseBuild`.
