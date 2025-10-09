param(
  [Parameter(Mandatory=$true)][string]$Version,
  [Parameter(Mandatory=$true)][string]$CdnBase
)
$newVer = $Version.TrimStart("v")
$appInstallerPath = "artifacts/TruckerCore.appinstaller"
@"
<?xml version="1.0" encoding="utf-8"?>
<AppInstaller Uri="$CdnBase/stable/TruckerCore.appinstaller" Version="$newVer.0"
  xmlns="http://schemas.microsoft.com/appx/appinstaller/2018">
  <MainPackage Name="com.truckercore.app" Publisher="CN=TruckerCore, Inc."
    Version="$newVer.0" ProcessorArchitecture="x64"
    Uri="$CdnBase/stable/$newVer/TruckerCore_${newVer}_x64.msixbundle" />
  <UpdateSettings>
    <OnLaunch HoursBetweenUpdateChecks="6" ShowPrompt="true" UpdateBlocksActivation="false" />
    <AutomaticBackgroundTask />
  </UpdateSettings>
</AppInstaller>
"@ | Out-File -Encoding utf8 $appInstallerPath
Write-Host "Wrote $appInstallerPath"
