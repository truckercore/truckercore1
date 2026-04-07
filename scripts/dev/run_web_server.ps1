# Runs the Flutter app on the Web Server device without auto-launching Chrome/Edge.
# Usage (PowerShell):
#   .\scripts\dev\run_web_server.ps1 -Port 52848 -Host localhost
# Environment vars SUPABASE_URL, SUPABASE_ANON, MAPBOX_TOKEN are forwarded as dart-defines.
param(
  [int]$Port = 52848,
  [string]$Host = "localhost"
)

$envArgs = @()
if ($env:SUPABASE_URL)  { $envArgs += "--dart-define=SUPABASE_URL=$($env:SUPABASE_URL)" }
if ($env:SUPABASE_ANON) { $envArgs += "--dart-define=SUPABASE_ANON=$($env:SUPABASE_ANON)" }
if ($env:MAPBOX_TOKEN)  { $envArgs += "--dart-define=MAPBOX_TOKEN=$($env:MAPBOX_TOKEN)" }

$cmd = @(
  "flutter", "run", "-d", "web-server",
  "--web-port", "$Port",
  "--web-hostname", "$Host"
) + $envArgs

Write-Host "[run_web_server] Launching: $($cmd -join ' ')"
& $cmd

if ($LASTEXITCODE -eq 0) {
  Write-Host "[run_web_server] Open http://$Host:$Port in your browser."
} else {
  Write-Error "[run_web_server] Flutter exited with code $LASTEXITCODE"
}
