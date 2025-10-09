param(
  [switch]$SkipClean,
  [switch]$NoBuild
)

Write-Host "=== TruckerCore Dependency & Build Diagnostic ===" -ForegroundColor Green
Write-Host "Working directory: $(Get-Location)" -ForegroundColor DarkGray

# Phase 1: Clean Reinstall
if (-not $SkipClean) {
  Write-Host "`n=== PHASE 1: Clean Reinstall ===" -ForegroundColor Green
  try {
    Write-Host "Cleaning directories..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
    Remove-Item -Force package-lock.json -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force .next -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force .vercel -ErrorAction SilentlyContinue

    Write-Host "Clearing npm cache..." -ForegroundColor Cyan
    npm cache clean --force
    npm cache verify

    Write-Host "`nInstalling dependencies..." -ForegroundColor Cyan
    npm install 2>&1 | Tee-Object -FilePath npm-install.txt
  }
  catch {
    Write-Host "[ERROR] Clean reinstall failed: $_" -ForegroundColor Red
  }
} else {
  Write-Host "Skipping clean reinstall as requested (--SkipClean)" -ForegroundColor Yellow
}

# Phase 2: Diagnostics
Write-Host "`n=== PHASE 2: Diagnostics ===" -ForegroundColor Green

Write-Host "`n--- npm list @json2csv/plainjs ---" -ForegroundColor Cyan
try { npm list @json2csv/plainjs } catch { Write-Host $_ -ForegroundColor Yellow }

Write-Host "`n--- npm ls json2csv ---" -ForegroundColor Cyan
try { npm ls json2csv } catch { Write-Host $_ -ForegroundColor Yellow }

Write-Host "`n--- npm explain json2csv ---" -ForegroundColor Cyan
try { npm explain json2csv } catch { Write-Host $_ -ForegroundColor Yellow }

Write-Host "`n--- npm ls json2csv --all ---" -ForegroundColor Cyan
try { npm ls json2csv --all } catch { Write-Host $_ -ForegroundColor Yellow }

# Lock file analysis
if (Test-Path package-lock.json) {
  Write-Host "`n--- Lock file analysis ---" -ForegroundColor Cyan
  $count = (Select-String -Path package-lock.json -Pattern '"json2csv"' -SimpleMatch).Count
  Write-Host "Total json2csv references: $count"
  Write-Host "`nSearching for v6 references:" -ForegroundColor Cyan
  $v6 = Select-String -Path package-lock.json -Pattern 'json2csv.*6\.'
  if ($v6) {
    $v6 | Select-Object -First 10 | ForEach-Object { Write-Host ("Line {0}: {1}" -f $_.LineNumber, $_.Line.Trim()) -ForegroundColor Yellow }
  } else {
    Write-Host "No v6 references found ✓" -ForegroundColor Green
  }
} else {
  Write-Host "package-lock.json not found (installation may have failed)" -ForegroundColor Yellow
}

# Phase 3: Verify configuration files
Write-Host "`n=== PHASE 3: Verify Configuration Files ===" -ForegroundColor Green
try {
  $pkg = Get-Content package.json -Raw | ConvertFrom-Json
  Write-Host "`n=== @json2csv/plainjs dependency ===" -ForegroundColor Cyan
  $pkg.dependencies.'@json2csv/plainjs'
  Write-Host "`n=== Overrides ===" -ForegroundColor Cyan
  $pkg.overrides | ConvertTo-Json
  Write-Host "`n=== Engines ===" -ForegroundColor Cyan
  $pkg.engines | ConvertTo-Json
} catch {
  Write-Host "[WARN] Could not parse package.json: $_" -ForegroundColor Yellow
}

if (Test-Path vercel.json) {
  try {
    Write-Host "`n=== Vercel Configuration ===" -ForegroundColor Cyan
    Get-Content vercel.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
  } catch {
    Write-Host "[WARN] Could not parse vercel.json: $_" -ForegroundColor Yellow
  }
} else {
  Write-Host "vercel.json not found" -ForegroundColor Yellow
}

# Phase 4: Build
if (-not $NoBuild) {
  Write-Host "`n=== PHASE 4: Build Test ===" -ForegroundColor Green
  try {
    npm run build 2>&1
  } catch {
    Write-Host "[ERROR] Build failed: $_" -ForegroundColor Red
  }
} else {
  Write-Host "Skipping build as requested (--NoBuild)" -ForegroundColor Yellow
}

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Green
Write-Host "Install log (if created): npm-install.txt" -ForegroundColor DarkGray
