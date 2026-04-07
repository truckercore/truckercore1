param(
  [string]$LogPath = "build_full.log",
  [int]$Context = 0
)

if (-not (Test-Path $LogPath)) {
  Write-Error "Log file not found: $LogPath"
  exit 1
}

# Primary patterns per guidance (Dart/Gradle/Java runtime/build failures)
$primaryPattern = '^[\s]*e: |^[\s]*error: |A problem occurred|FAILURE: Build failed|\[[\s]+\d+ ms\] Exception|Unhandled exception|cannot find symbol|NoSuchMethodError|Compilation failed'
# Fallback patterns often seen in Android signing/config failures (common on Windows envs)
$fallbackPattern = 'keystore|signing|storeFile|keyAlias|RemoteException|No matching client found|minSdk|targetSdk|manifest merger|duplicate class'

function Write-MatchWithContext {
  param(
    [Microsoft.PowerShell.Commands.MatchInfo]$Match,
    [int]$Ctx
  )
  if ($Ctx -le 0) {
    Write-Output ("{0}: {1}" -f $Match.LineNumber, $Match.Line)
    return
  }
  $start = [Math]::Max(1, $Match.LineNumber - $Ctx)
  $end   = $Match.LineNumber + $Ctx
  $idx = 1
  Get-Content $LogPath | ForEach-Object {
    if ($idx -ge $start -and $idx -le $end) {
      $prefix = if ($idx -eq $Match.LineNumber) { '>' } else { ' ' }
      Write-Output ("{0}{1,6}: {2}" -f $prefix, $idx, $_)
    }
    $idx++
  }
}

# Try primary pattern first
$match = Select-String -Path $LogPath -Pattern $primaryPattern -CaseSensitive:$false | Select-Object -First 1
if ($null -ne $match) {
  Write-MatchWithContext -Match $match -Ctx $Context
  exit 0
}

# Fallback pattern
$fallback = Select-String -Path $LogPath -Pattern $fallbackPattern -CaseSensitive:$false | Select-Object -First 1
if ($null -ne $fallback) {
  Write-Host "[Note] No primary error-like lines found. Showing first fallback match (env/config likely):" -ForegroundColor Yellow
  Write-MatchWithContext -Match $fallback -Ctx $Context
  exit 0
}

Write-Output "No error-like lines found in $LogPath"
