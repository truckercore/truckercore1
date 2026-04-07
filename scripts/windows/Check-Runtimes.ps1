param(
  [switch]$DeepScan
)

Write-Host "=== Windows Runtime Preflight Checks ===" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date)" -ForegroundColor Yellow

$ErrorActionPreference = 'Continue'

function Test-Command {
  param([string]$Name)
  $exists = Get-Command $Name -ErrorAction SilentlyContinue
  return $null -ne $exists
}

# 1) Basic OS info
Write-Host "--- OS Info ---" -ForegroundColor Green
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer, WindowsBuildLabEx | Format-List

# 2) .NET runtimes
Write-Host "--- .NET Runtimes ---" -ForegroundColor Green
try {
  if (Test-Path "$Env:ProgramFiles\dotnet\dotnet.exe") {
    & "$Env:ProgramFiles\dotnet\dotnet.exe" --info
  } elseif (Test-Path "$Env:ProgramFiles(x86)\dotnet\dotnet.exe") {
    & "$Env:ProgramFiles(x86)\dotnet\dotnet.exe" --info
  } else {
    Write-Warning ".NET SDK/runtime not found on PATH; some builds may require it."
  }
} catch { Write-Warning ".NET inspection failed: $($_.Exception.Message)" }

# 3) VC++ Redistributables (heuristic check by presence of common DLLs)
Write-Host "--- Visual C++ Redistributables (Heuristic) ---" -ForegroundColor Green
$vcDlls = @(
  'vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll','msvcp140_1.dll','concrt140.dll'
)
$systemDirs = @("$Env:WINDIR\System32","$Env:WINDIR\SysWOW64")
foreach ($dll in $vcDlls) {
  $found = $false
  foreach ($dir in $systemDirs) {
    if (Test-Path (Join-Path $dir $dll)) { $found = $true; break }
  }
  if ($found) { Write-Host "✓ $dll found" -ForegroundColor Green } else { Write-Warning "$dll not found (may be OK depending on app)" }
}

# 4) Node/npm presence
Write-Host "--- Node/npm Versions ---" -ForegroundColor Green
try { node -v } catch { Write-Warning "node not found" }
try { npm -v } catch { Write-Warning "npm not found" }

# 5) Permission sanity check in workspace
Write-Host "--- Workspace Permissions ---" -ForegroundColor Green
try {
  $testPath = Join-Path $PSScriptRoot "perm-test.tmp"
  Set-Content -Path $testPath -Value "ok" -Encoding UTF8 -Force
  Remove-Item $testPath -Force
  Write-Host "✓ Write permissions OK in repo" -ForegroundColor Green
} catch { Write-Warning "Write permission test failed: $($_.Exception.Message)" }

# 6) Optional deep system health checks
if ($DeepScan) {
  Write-Host "--- Deep System Health (SFC & DISM) ---" -ForegroundColor Green
  if (-not ([bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-Warning "DeepScan requires admin. Skipping SFC/DISM."
  } else {
    try {
      Write-Host "Running: sfc /scannow (this can take several minutes)" -ForegroundColor Yellow
      sfc /scannow
    } catch { Write-Warning "sfc failed: $($_.Exception.Message)" }
    try {
      Write-Host "Running: DISM /Online /Cleanup-Image /CheckHealth" -ForegroundColor Yellow
      DISM /Online /Cleanup-Image /CheckHealth
    } catch { Write-Warning "DISM failed: $($_.Exception.Message)" }
  }
}

Write-Host "Completed: $(Get-Date)" -ForegroundColor Yellow
