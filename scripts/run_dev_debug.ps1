param(
  [switch]$Scan
)
# Build and run DevDebug, capture logs, then extract first error
$log = "build_full.log"
if (Test-Path $log) { Remove-Item $log -Force }

# Pre-check: ensure default Android debug keystore exists
$debugKs = Join-Path $env:USERPROFILE ".android\debug.keystore"
if (-not (Test-Path $debugKs)) {
  Write-Host "[DevDebug] Default debug keystore not found at $debugKs" -ForegroundColor Yellow
  Write-Host "[DevDebug] Android Studio normally generates this automatically. You can also create it with keytool." -ForegroundColor Yellow
}

Write-Host "[DevDebug] Building Flutter APK (dev debug) with verbose logs..." -ForegroundColor Cyan
# Use Flutter to ensure Dart build and Android wiring match
$buildCmd = "flutter build apk --debug --flavor dev -v"
if ($Scan) {
  # Enable Gradle build scan via env variable understood by Gradle Enterprise if configured
  $env:ORG_GRADLE_PROJECT_scan = "true"
}

# Run build and capture output
cmd /c "$buildCmd > $log 2>&1"
# Always write first_error.txt for parity with CI
$out = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\first_error.ps1
$out | Out-File -Encoding utf8 first_error.txt
if ($LASTEXITCODE -ne 0) {
  Write-Host "[DevDebug] Build failed. Extracting first error from $log ..." -ForegroundColor Yellow
  $out | Write-Output
  Write-Host "[Hint] If no error lines are found, try: pwsh -File scripts\extract_first_error.ps1 -LogPath $log -Context 5" -ForegroundColor Yellow
  exit 1
}

# Copy/rename APK to conventional name for easy install
$apkDir = "build\app\outputs\flutter-apk"
if (Test-Path $apkDir) {
  $apk = Get-ChildItem $apkDir -Recurse -Filter "*devDebug*.apk" | Select-Object -First 1
  if ($apk) {
    $ts = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $name = "app-devdebug--$ts.apk"
    Copy-Item $apk.FullName (Join-Path $apkDir $name) -Force
    Write-Host "[DevDebug] APK prepared: $(Join-Path $apkDir $name)" -ForegroundColor Green
  }
}

Write-Host "[DevDebug] Build succeeded. Launching app on a connected device/emulator..." -ForegroundColor Green
# Try to run the debug flavor directly
$runCmd = "flutter run --flavor dev -d all"
cmd /c $runCmd
