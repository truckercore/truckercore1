# scripts/pre-commit.ps1
flutter pub get
dart format --set-exit-if-changed .
dart fix --apply
flutter analyze
if ($LASTEXITCODE -ne 0) { exit 1 }
