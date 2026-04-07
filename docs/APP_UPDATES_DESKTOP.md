# Desktop App Updates: Options and Recommended Approach

This document outlines options to add an app update mechanism for desktop (Windows, macOS, Linux) and provides a recommended path with minimal maintenance burden.

## Goals
- Provide safe, signed updates
- Keep infrastructure simple and cost-effective
- Integrate smoothly with existing CI/CD

## Options Overview

### Windows
1) MSIX + App Installer (Recommended)
- Package as MSIX and publish to a CDN
- Provide an .appinstaller XML that points to your MSIX with version and update policy
- Windows checks the URL and prompts users to update
- Pros: Native, signed, background checks; Cons: Requires hosting and correct XML

2) WinGet / Microsoft Store
- Publish via Store or WinGet; auto-updates handled by the ecosystem
- Pros: Seamless updates; Cons: Store compliance/reviews, onboarding

3) Squirrel.Windows / custom updaters
- Third-party updaters, more control but more moving parts

### macOS
1) Sparkle (Recommended for outside Mac App Store)
- De facto standard for notarized DMG/ZIP updates
- Hosted appcast.xml with versioned releases and DSA/EdDSA signatures
- Pros: Mature, battle-tested; Cons: Requires embedding and maintaining Sparkle

2) Mac App Store
- Ship via App Store; updates handled by Apple
- Pros: Seamless; Cons: Store review, sandboxing limits

### Linux
1) AppImage + AppImageUpdate (zsync)
- Self-updating AppImages using zsync metadata
- Pros: Simple hosting; Cons: AppImage ecosystem expectations

2) Flatpak (Flathub or self-hosted repo)
- Updates via flatpak remotes
- Pros: Sandboxed, widely used; Cons: Different packaging model

3) Deb/RPM + repository updates
- Traditional distro packaging; updates via apt/yum repos

## Recommended Path
- Windows: MSIX + App Installer (.appinstaller) hosted on a CDN
- macOS: Sparkle with appcast.xml hosted on a CDN; continue to codesign + notarize releases
- Linux: AppImage with zsync metadata or Flatpak if you already distribute via Flathub

## Versioning & Channels
- Use semantic versions (e.g. 1.12.3) and append build metadata in CI
- Maintain channels (stable, beta, canary) by hosting separate feeds:
  - https://cdn.example.com/truckercore/stable/appinstaller.xml
  - https://cdn.example.com/truckercore/beta/appinstaller.xml
  - https://cdn.example.com/truckercore/sparkle/appcast-stable.xml

## CI/CD Outline
1) Build desktop artifacts (see INSTALLER_BUILD_SIGNING.md)
2) Sign/notarize as appropriate
3) Generate feed files:
   - Windows: appinstaller.xml with latest version and file URL
   - macOS: Sparkle appcast.xml with enclosure URLs and signatures
   - Linux: .zsync for AppImage
4) Upload binaries and feed files to CDN with cache-busting headers
5) Publish release notes and checksums (SHA256)

## Minimal Implementation Snippets

### Windows App Installer XML (example)
```xml
<AppInstaller Uri="https://cdn.example.com/truckercore/stable/appinstaller.xml" Version="1.12.3.0" xmlns="http://schemas.microsoft.com/appx/appinstaller/2018">
  <MainPackage Name="com.yourco.truckercore" Version="1.12.3.0" Publisher="CN=Your Company, O=Your Company, C=US" ProcessorArchitecture="x64" Uri="https://cdn.example.com/truckercore/stable/TruckerCore_1.12.3.0_x64.msix" />
  <UpdateSettings>
    <OnLaunch HoursBetweenUpdateChecks="24" ShowPrompt="true"/>
  </UpdateSettings>
</AppInstaller>
```

### Sparkle Appcast item (example)
```xml
<item>
  <title>1.12.3</title>
  <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
  <enclosure url="https://cdn.example.com/truckercore/sparkle/TruckerCore-1.12.3.dmg" sparkle:version="1.12.3" length="123456789" type="application/octet-stream" sparkle:edSignature="BASE64EDSIGNATURE"/>
  <sparkle:releaseNotesLink>https://cdn.example.com/truckercore/notes/1.12.3.html</sparkle:releaseNotesLink>
</item>
```

### AppImage zsync generation
```
appimagetool --comp zsync TruckerCore.AppDir TruckerCore-x86_64.AppImage
# Generates TruckerCore-x86_64.AppImage.zsync
```

## In-App Integration (Optional)
- Show an "Update available" banner by periodically polling the feed (App Installer or Sparkle appcast)
- Provide a button to open the OS-native updater (Windows App Installer URI, Sparkle check now)
- Ensure checks are throttled (daily) and disabled in offline mode

## Telemetry
- Track update checks and completions with breadcrumbs/events (see app_open and navigation breadcrumbs in the app). Add identifiers: version, channel, platform.
