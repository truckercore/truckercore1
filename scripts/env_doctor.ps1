param(
  [switch]$Quiet
)

function Write-Section($title) {
  if (-not $Quiet) {
    Write-Host ("`n=== $title ===") -ForegroundColor Cyan
  }
}

# Step 4 — Confirm your environment (rules out toolchain issues)
Write-Section "Flutter doctor -v"
try {
  flutter doctor -v
} catch {
  Write-Host "Flutter not found on PATH. Please install Flutter and ensure it's on PATH." -ForegroundColor Red
}

Write-Section "Android SDK path (from local.properties)"
$localProps = Join-Path -Path (Get-Location) -ChildPath "local.properties"
if (Test-Path $localProps) {
  $sdkDir = Select-String -Path $localProps -Pattern '^sdk.dir=' | Select-Object -First 1
  if ($sdkDir) {
    $val = $sdkDir.Line.Split('=')[1]
    Write-Output ("sdk.dir: {0}" -f $val)
    if (-not (Test-Path $val)) {
      Write-Host "[WARN] Path does not exist: $val" -ForegroundColor Yellow
    }
  } else {
    Write-Host "[WARN] sdk.dir not found in local.properties" -ForegroundColor Yellow
  }
} else {
  Write-Host "[WARN] local.properties not found at project root" -ForegroundColor Yellow
}

Write-Section "Gradle and Java version (expect Java 17)"
$androidDir = Join-Path -Path (Get-Location) -ChildPath "android"
$gradlew = Join-Path $androidDir "gradlew.bat"
if (Test-Path $gradlew) {
  Push-Location $androidDir
  try {
    $out = & .\gradlew -v 2>&1
    $out | Write-Output
    # Try to detect Java version line
    $javaLine = $out | Select-String -Pattern 'JVM:|Java (version|Version)|JDK' -CaseSensitive:$false | Select-Object -First 1
    if ($javaLine) {
      Write-Host ("Detected: {0}" -f $javaLine.Line) -ForegroundColor Green
      if ($javaLine.Line -notmatch '17') {
        Write-Host "[WARN] Gradle does not appear to be using Java 17. Ensure JAVA_HOME points to a JDK 17 and Gradle uses it." -ForegroundColor Yellow
      }
    } else {
      Write-Host "[INFO] Could not parse Java version from gradle -v output. Manually verify it's Java 17." -ForegroundColor Yellow
    }
  } catch {
    Write-Host "[WARN] Failed to run gradlew -v. Ensure Gradle wrapper is present and executable." -ForegroundColor Yellow
  } finally {
    Pop-Location
  }
} else {
  Write-Host "[WARN] android\\gradlew.bat not found. Skipping Gradle/Java version check." -ForegroundColor Yellow
}

Write-Section "Tips"
Write-Output "- If any red errors appear above, resolve toolchain issues before rebuilding."
Write-Output "- On Windows, ensure JAVA_HOME points to JDK 17 and PATH includes %JAVA_HOME%\\bin."
Write-Output "- In Android Studio, verify Gradle JDK is set to 17 (File > Settings > Build, Execution, Deployment > Build Tools > Gradle)."
