# TruckerCore 404 Fix Verification (Windows)
# Usage: npm run verify:fix

# Ensure TLS 1.2 for HTTPS requests on older PowerShell versions
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

Write-Host "==== TruckerCore 404 Fix Verification ===="
Write-Host ""

$allPassed = $true

# 1) Local file structure
Write-Host "1. Local File Structure"
Write-Host ""
$files = @(
  "pages/index.tsx",
  "pages/_app.tsx",
  "pages/_document.tsx",
  "next.config.js",
  "package.json"
)
foreach ($file in $files) {
  Write-Host -NoNewline "   $file... "
  if (Test-Path $file) { Write-Host "[OK]" } else { Write-Host "[Missing]"; $allPassed = $false }
}

# 2) Router configuration (prefer Pages Router, ensure no app/ conflicts)
Write-Host ""
Write-Host "2. Router Configuration"
Write-Host ""
Write-Host -NoNewline "   app/ directory (should not exist)... "
if (Test-Path "app") { Write-Host "[WARN] Exists (ensure not conflicting with pages/)" } else { Write-Host "[OK] Not present" }
Write-Host -NoNewline "   pages/ directory... "
if (Test-Path "pages") { Write-Host "[OK] Exists" } else { Write-Host "[Missing]"; $allPassed = $false }

# 3) Build test
Write-Host ""
Write-Host "3. Build Test"
Write-Host ""
Write-Host "   Cleaning previous build..."
try { Remove-Item -Recurse -Force .next -ErrorAction SilentlyContinue } catch {}
Write-Host "   Building..."
$buildOutput = npm run build 2>&1
if ($LASTEXITCODE -eq 0) { Write-Host "   [OK] Build successful" } else { Write-Host "   [FAIL] Build failed"; Write-Host "   $buildOutput"; $allPassed = $false }

# 4) Local server test
Write-Host ""
Write-Host "4. Local Server Test"
Write-Host ""
Write-Host "   Starting server..."
$job = Start-Job -ScriptBlock { npm run start }
Start-Sleep -Seconds 5
try {
  $response = Invoke-WebRequest -Uri "http://localhost:3000" -Method Head -TimeoutSec 10
  if ($response.StatusCode -eq 200) { Write-Host "   [OK] Local server returns 200" } else { Write-Host "   [WARN] Local server returns $($response.StatusCode)" }
} catch {
  Write-Host "   [FAIL] Cannot connect to local server"
  $allPassed = $false
} finally {
  Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
  Remove-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
}

# 5) Production test
Write-Host ""
Write-Host "5. Production Test"
Write-Host ""
try {
  $resp = Invoke-WebRequest -Uri "https://truckercore.com" -Method Head -TimeoutSec 15
  Write-Host -NoNewline "   https://truckercore.com... "
  if ($resp.StatusCode -eq 200) { Write-Host "[OK] 200" } else { Write-Host "[WARN] $($resp.StatusCode)" }
} catch {
  Write-Host "   [FAIL] Error: $($_.Exception.Message)"
  $allPassed = $false
}

# 6) Content validation
Write-Host ""
Write-Host "6. Content Validation"
Write-Host ""
try {
  $html = Invoke-WebRequest -Uri "https://truckercore.com" -TimeoutSec 15
  Write-Host -NoNewline "   Checking for 'TruckerCore'... "
  if ($html.Content -match "TruckerCore") { Write-Host "[OK] Found" } else { Write-Host "[FAIL] Not found"; $allPassed = $false }
} catch {
  Write-Host "[FAIL] Cannot fetch content"
  $allPassed = $false
}

# Summary
Write-Host '----------------------------------------'
if ($allPassed) {
  Write-Host '✅ All verification checks passed!'
  Write-Host 'Your site is LIVE: https://truckercore.com'
  Write-Host ''
  exit 0
} else {
  Write-Host 'Some checks failed'
  Write-Host ''
  Write-Host 'Next steps:'
  Write-Host '  1. Fix issues shown above'
  Write-Host '  2. Run: npm run fix:404'
  Write-Host '  3. Commit and push changes'
  Write-Host '  4. Wait 2 minutes and re-run this script'
  Write-Host ""
  exit 1
}