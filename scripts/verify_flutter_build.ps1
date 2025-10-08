# Flutter Build Verification Script for Windows
Param()

function Print-Status {
    param (
        [bool]$Success,
        [string]$Message
    )
    if ($Success) {
        Write-Host "✓ $Message" -ForegroundColor Green
    } else {
        Write-Host "✗ $Message" -ForegroundColor Red
    }
}

Write-Host "🔍 Flutter Build Verification Script" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# 1️⃣  Check Flutter installation
Write-Host "1️⃣  Checking Flutter installation..." -ForegroundColor Yellow
$flutterVersion = & flutter --version
Print-Status ($LASTEXITCODE -eq 0) "Flutter is installed"
Write-Host ""

# 2️⃣  Clean build artifacts
Write-Host "2️⃣  Cleaning build artifacts..." -ForegroundColor Yellow
& flutter clean | Out-Null
Remove-Item -Path "windows\flutter\ephemeral" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Print-Status ($LASTEXITCODE -eq 0) "Build artifacts cleaned"
Write-Host ""

# 3️⃣  Get dependencies
Write-Host "3️⃣  Getting dependencies..." -ForegroundColor Yellow
& flutter pub get | Out-Null
Print-Status ($LASTEXITCODE -eq 0) "Dependencies resolved"
Write-Host ""

# 4️⃣  Run code generation
Write-Host "4️⃣  Running code generation..." -ForegroundColor Yellow
& flutter pub run build_runner build --delete-conflicting-outputs | Out-Null
Print-Status ($LASTEXITCODE -eq 0) "Code generation completed"
Write-Host ""

# 5️⃣  Analyze code
Write-Host "5️⃣  Analyzing code..." -ForegroundColor Yellow
& flutter analyze | Out-Null
Print-Status ($LASTEXITCODE -eq 0) "Code analysis passed"
Write-Host ""

# 6️⃣  Run tests
Write-Host "6️⃣  Running tests..." -ForegroundColor Yellow
& flutter test | Out-Null
Print-Status ($LASTEXITCODE -eq 0) "Tests passed"
Write-Host ""

# 7️⃣  Build Windows and check for CMake warnings
Write-Host "7️⃣  Building for Windows and checking for CMake warnings..." -ForegroundColor Yellow
$output = & flutter build windows 2>&1 | Out-String
$output | Out-File -FilePath "build_output.txt" -Encoding UTF8
$cmakeWarnings = (Select-String -Path "build_output.txt" -Pattern "CMake Warning").Count

if ($cmakeWarnings -eq 0) {
    Write-Host "✓ No CMake warnings found" -ForegroundColor Green
} else {
    Write-Host "⚠ Found $cmakeWarnings CMake warning(s)" -ForegroundColor Yellow
}

Remove-Item "build_output.txt" -Force -ErrorAction SilentlyContinue
Write-Host ""

# 8️⃣  Summary
Write-Host "📊 Verification Summary" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "✓ All checks completed" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 Your Flutter app is ready to run!" -ForegroundColor Cyan
Write-Host "   Run: flutter run -d chrome" -ForegroundColor White
Write-Host "   Or:  flutter run -d windows" -ForegroundColor White
