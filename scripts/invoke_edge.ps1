param(
  [Parameter(Mandatory=$true)][string]$FunctionName,
  [string]$ProjectRef,
  [int]$Drivers = 100,
  [int]$Hours = 24,
  [int]$Chunk = 2000,
  [string]$Org
)

# Usage examples:
#   powershell -File scripts/invoke_edge.ps1 -FunctionName org_queue_worker -ProjectRef abcdefghijklmnop
#   powershell -File scripts/invoke_edge.ps1 -FunctionName admin_diagnostics_json -ProjectRef abcdefghijklmnop
#   powershell -File scripts/invoke_edge.ps1 -FunctionName synthetic_load -ProjectRef abcdefghijklmnop -Drivers 100 -Hours 24 -Chunk 2000 -Org <org-uuid>
# Env:
#   $env:SUPABASE_SERVICE_ROLE_KEY should be set for protected functions.

if (-not $ProjectRef) {
  Write-Error "ProjectRef is required."
  exit 2
}

$baseUrl = "https://$ProjectRef.functions.supabase.co"
$headers = @{}
if ($env:SUPABASE_SERVICE_ROLE_KEY) {
  $headers['Authorization'] = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
}

$method = 'GET'
$url = "$baseUrl/$FunctionName"
if ($FunctionName -eq 'org_queue_worker') { $method = 'POST' }

if ($FunctionName -eq 'synthetic_load') {
  $params = @{
    drivers = $Drivers
    hours = $Hours
    chunk = $Chunk
  }
  if ($Org) { $params['org'] = $Org }
  $qs = ($params.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join '&'
  $url = "$url?$qs"
}

try {
  $resp = Invoke-RestMethod -Method $method -Uri $url -Headers $headers -ContentType 'application/json'
  Write-Output $resp | ConvertTo-Json -Depth 6
} catch {
  Write-Error $_
  exit 1
}
