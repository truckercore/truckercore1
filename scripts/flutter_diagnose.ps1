# flutter_diagnose.ps1
# Helper script to troubleshoot common build failures on Windows.
# Usage: Right-click -> Run with PowerShell, or run: pwsh -File scripts/flutter_diagnose.ps1

param(
  [switch]$Upgrade,
  [switch]$VerboseBuild
)

Write-Host "[flutter_diagnose] Starting..." -ForegroundColor Cyan

function Run-Step($name, $cmd){
  Write-Host "[STEP] $name" -ForegroundColor Yellow
  try{ & $cmd } catch { Write-Host "[ERROR] $_" -ForegroundColor Red; throw }
}

# Verify Flutter is on PATH
Run-Step "flutter --version" { flutter --version }

# Clean previous artifacts
Run-Step "flutter clean" { flutter clean }

# Get deps
Run-Step "flutter pub get" { flutter pub get }

if ($Upgrade) {
  Run-Step "flutter pub upgrade --major-versions" { flutter pub upgrade --major-versions }
}

# Analyzer quick check
Run-Step "dart analyze" { dart analyze }

# Build with or without verbosity
if ($VerboseBuild) {
  Run-Step "flutter build apk --debug --verbose" { flutter build apk --debug --verbose }
} else {
  Run-Step "flutter build apk --debug" { flutter build apk --debug }
}

Write-Host "[flutter_diagnose] Done." -ForegroundColor Green
