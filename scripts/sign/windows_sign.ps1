param(
  [Parameter(Mandatory=$false)][string]$ExePath = "build\windows\runner\Release\truckercore1.exe",
  [Parameter(Mandatory=$false)][string]$MsixPath = ""
)

# windows_sign.ps1
# Signs Windows binaries using signtool with a timestamp server and verifies them.
# Requirements (CI secrets):
#  - WIN_CERT_PFX: base64-encoded PFX certificate
#  - WIN_CERT_PASSWORD: password for the PFX
#  - TIMESTAMP_URL: timestamp server URL (e.g., http://timestamp.acs.microsoft.com)

$ErrorActionPreference = "Stop"

if (-not $env:WIN_CERT_PFX -or -not $env:WIN_CERT_PASSWORD -or -not $env:TIMESTAMP_URL) {
  Write-Error "Missing one or more required env vars: WIN_CERT_PFX, WIN_CERT_PASSWORD, TIMESTAMP_URL"
}

$work = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine($env:TEMP, "sign-$(Get-Random)")) -Force
$pfxPath = Join-Path $work.FullName 'cert.pfx'

[IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($env:WIN_CERT_PFX))

if (-not (Get-Command signtool -ErrorAction SilentlyContinue)) {
  Write-Host "signtool not found in PATH. Ensure Windows SDK is available on runner."
}

# Sign EXE if exists
if (Test-Path $ExePath) {
  Write-Host "Signing $ExePath"
  & signtool sign /f $pfxPath /p $env:WIN_CERT_PASSWORD /tr $env:TIMESTAMP_URL /td SHA256 /fd SHA256 $ExePath
  Write-Host "Verifying $ExePath"
  & signtool verify /pa /v $ExePath
} else {
  Write-Host "EXE not found at $ExePath; skipping."
}

# Sign MSIX if provided and exists
if ($MsixPath -and (Test-Path $MsixPath)) {
  Write-Host "Signing $MsixPath"
  & signtool sign /f $pfxPath /p $env:WIN_CERT_PASSWORD /tr $env:TIMESTAMP_URL /td SHA256 /fd SHA256 $MsixPath
  Write-Host "Verifying $MsixPath"
  & signtool verify /pa /v $MsixPath
}

Write-Host "Windows signing and verification complete."
