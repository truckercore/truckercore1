<#!
.SYNOPSIS
  Enhanced Windows run script for the Flutter app.

.DESCRIPTION
  Provides a quick way to run the app with automatic dependency installation,
  device selection, mock/real data toggle, Supabase credential overrides,
  colored output, and clear error handling.

.PARAMETER Device
  Target device/platform. One of: windows | android | ios | chrome | edge. Defaults to windows.

.PARAMETER Mock
  If present, runs the app with mock data (no backend required).

.PARAMETER SupabaseUrl
  Optional Supabase project URL to override the default or environment variable.

.PARAMETER SupabaseAnon
  Optional Supabase anon key to override the default or environment variable.

.EXAMPLE
  .\scripts\run.ps1 -Mock
  Runs the app using mock data on Windows desktop.

.EXAMPLE
  .\scripts\run.ps1 -Device android
  Runs the app on an attached Android device/emulator with real backend.

.EXAMPLE
  .\scripts\run.ps1 -Device chrome -SupabaseUrl "https://staging.supabase.co" -SupabaseAnon "staging-key"
  Runs the app on Chrome using custom Supabase credentials.
#>

param(
  [ValidateSet('windows','android','ios','chrome','edge')]
  [string]$Device = 'windows',
  [switch]$Mock,
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$SupabaseAnon = $env:SUPABASE_ANON
)

$ErrorActionPreference = 'Stop'

function Write-Step {
  param(
    [Parameter(Mandatory=$true)][string]$Message,
    [bool]$Ok = $true
  )
  if ($Ok) {
    Write-Host ("  ✓ " + $Message) -ForegroundColor Green
  } else {
    Write-Host ("  ✗ " + $Message) -ForegroundColor Red
  }
}

function Write-Info {
  param([string]$Message)
  Write-Host $Message -ForegroundColor Cyan
}

Write-Info "[run.ps1] TruckerCore launcher"
Write-Info "[run.ps1] Device='$Device' Mock='$($Mock.IsPresent)'"

# Ensure Flutter is available
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
  Write-Step "Flutter CLI not found. Install Flutter: https://docs.flutter.dev/get-started/install" $false
  exit 127
}

# Resolve Supabase settings when not in mock mode
if (-not $Mock) {
  if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
    $SupabaseUrl = 'https://viqrwlzdtosxjzjvtxnr.supabase.co'
  }
  if ([string]::IsNullOrWhiteSpace($SupabaseAnon)) {
    $SupabaseAnon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpcXJ3bHpkdG9zeGp6anZ0eG5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MzUwNDgsImV4cCI6MjA3MDUxMTA0OH0.AQmHjD7UZT3vzkXYggUsi8XBEYWGQtXdFes6MDcUddk'
  }
  if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or [string]::IsNullOrWhiteSpace($SupabaseAnon)) {
    Write-Step "Missing Supabase URL or Anon key. Provide -SupabaseUrl and -SupabaseAnon or set env vars SUPABASE_URL/SUPABASE_ANON." $false
    exit 2
  }
}

# Install dependencies
Write-Info "[run.ps1] Running flutter pub get..."
try {
  flutter pub get | Out-Null
  Write-Step "Dependencies updated"
} catch {
  Write-Step ("flutter pub get failed: " + $_.Exception.Message) $false
  Write-Host "  Hint: Try 'flutter clean' then rerun this script." -ForegroundColor Yellow
  exit 1
}

# Build dart-define list
$defines = @()
if ($Mock) {
  $defines += '--dart-define=USE_MOCK_DATA=true'
  Write-Info "[run.ps1] Starting app with mock data (no backend)"
} else {
  $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl"
  $defines += "--dart-define=SUPABASE_ANON=$SupabaseAnon"
  $defines += '--dart-define=USE_MOCK_DATA=false'
  Write-Info "[run.ps1] Connecting to Supabase..."
}

# Map device selection
$deviceId = switch ($Device) {
  'windows' { 'windows' }
  'android' { 'android' }
  'ios'     { 'ios' }
  'chrome'  { 'chrome' }
  'edge'    { 'edge' }
  default   { 'windows' }
}

# Compose and run command
$cmd = @('flutter','run','-d', $deviceId) + $defines
Write-Host ("[run.ps1] Executing: " + ($cmd -join ' ')) -ForegroundColor Green

& $cmd[0] $cmd[1..($cmd.Length-1)]
$code = $LASTEXITCODE

if ($code -ne 0) {
  Write-Step "Flutter run failed (exit code $code)" $false
  Write-Host "  If no devices were found, the script defaults to Windows. You can list devices with: flutter devices" -ForegroundColor Yellow
} else {
  Write-Step "Build finished"
}

exit $code
