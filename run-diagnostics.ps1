Write-Host "=== TRUCKERCORE1 DIAGNOSTIC SCRIPT ===" -ForegroundColor Cyan
Write-Host "Starting at: $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

Write-Host "=== PHASE 1: Clean Reinstall ===" -ForegroundColor Green
Write-Host "Cleaning directories..."
Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
Remove-Item -Force package-lock.json -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .next -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .vercel -ErrorAction SilentlyContinue

Write-Host "Clearing npm cache..."
npm cache clean --force
npm cache verify

Write-Host "`nInstalling dependencies..."
npm install 2>&1 | Tee-Object -FilePath npm-install.txt
Write-Host "Installation complete. Log saved to npm-install.txt"

Write-Host "`n=== PHASE 2: Diagnostics ===" -ForegroundColor Green

Write-Host "`n--- 1. Check @json2csv/plainjs version ---"
npm list @json2csv/plainjs 2>&1

Write-Host "`n--- 2. Check json2csv resolution ---"
npm ls json2csv 2>&1

Write-Host "`n--- 3. Explain json2csv dependency chain ---"
npm explain json2csv 2>&1

Write-Host "`n--- 4. Check all json2csv occurrences ---"
Write-Host "First 20 lines only:"
npm ls json2csv --all 2>&1 | Select-Object -First 20

Write-Host "`n--- 5. Lock file analysis ---"
if (Test-Path package-lock.json) {
    $count = (Select-String -Path package-lock.json -Pattern '"json2csv"' -SimpleMatch).Count
    Write-Host "Total json2csv references in lock file: $count"
    
    Write-Host "`nChecking for v6 references:"
    $v6refs = Select-String -Path package-lock.json -Pattern 'json2csv.*"6\.' 
    if ($v6refs) {
        Write-Host "⚠️ WARNING: Found v6 references:" -ForegroundColor Red
        $v6refs | Select-Object -First 10
    } else {
        Write-Host "✓ No v6 references found" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ package-lock.json not found!" -ForegroundColor Red
}

Write-Host "`n--- 6. Verify Node and npm versions ---"
Write-Host "Node version: $(node -v)"
Write-Host "npm version: $(npm -v)"

Write-Host "`n=== PHASE 3: Build Test ===" -ForegroundColor Green
npm run build 2>&1

Write-Host "`n=== DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan
Write-Host "Finished at: $(Get-Date)" -ForegroundColor Yellow
Write-Host "`nFull install log saved to: npm-install.txt"
Write-Host "Full diagnostic log saved to: full-diagnostic.txt"