# Installer Hardening Guide

Summary
- Sign all installers and binaries (Windows EXE/MSI/MSIX, macOS DMG/PKG). Notarize on macOS.
- Least privilege: install binaries to protected dirs; user data in user profile; avoid AlwaysInstallElevated.
- Prefer MSIX on Windows; requires signing; supports containerization and safer updates.
- Secure custom actions; avoid secrets in properties; lock file/registry permissions.
- Maintain update pipeline; enable logs and leverage platform protections.

Windows
- Code signing: EV Code Signing cert preferred; sign EXE/MSI; timestamp with RFC3161.
- Least privilege: binaries 3%ProgramFiles%; user data 3%AppData%; custom actions deferred/limited.
- MSIX: require signing; containerization; reliable updates.
- MSI best practices:
  - No secrets in properties; enable verbose logs via `/L*v`.
  - Use LockPermissions table for installed resources.
  - Clean uninstall; remove files/registry; validate with QA.
  - Do not set AlwaysInstallElevated.
- Supply chain: store sources in restricted repos; verify hashes for CABs; enable Defender/SmartScreen.

macOS
- Sign with Developer ID; protect certs; enable hardened runtime.
- Notarize; staple tickets; verify with `spctl -a -vv` and `xcrun stapler validate`.
- Gatekeeper: respect first-launch policies; avoid quarantine flags by stapling.
- Sandbox where reasonable; user data in ~/Library/Application Support/<App>.

Linux
- Use native packages (.deb/.rpm); sign repos (GPG).
- Follow FHS; least privilege; set explicit perms (chmod/chown).
- Use SELinux/AppArmor profiles when applicable.
- Sanitize installer input; remove unused dependencies; clean uninstall.

CI/CD
- Isolated signing step with HSM or cloud signing (AAD/Intune/Apple).
- Two-person review for installer changes.
- SBOM + provenance (SLSA) for release artifacts.
- Automated install/uninstall tests on Windows/macOS/Linux VMs.

Checklists
- Windows MSI/MSIX
  - [ ] Sign binaries and installer; timestamp.
  - [ ] No AlwaysInstallElevated; no secrets in MSI properties.
  - [ ] LockPermissions for install dir and registry keys.
  - [ ] Create Start Menu shortcuts with minimal privileges (see src-tauri/wix/extra-shortcuts.wxs).
  - [ ] Verify upgrade/uninstall removes all files/keys.
- macOS DMG/PKG
  - [ ] Hardened runtime, signed with Developer ID.
  - [ ] Notarized and stapled; Gatekeeper validation passes.
  - [ ] Install paths respect macOS conventions; no privileged writes.
- Linux DEB/RPM
  - [ ] Packages signed; repository signed with GPG.
  - [ ] Files placed per FHS; postinst/prerm scripts minimal and audited.

Operational
- [ ] Monitor update feed integrity and signature verification.
- [ ] Rotate signing keys per policy; store in HSM/KMS.
- [ ] Maintain reproducible build logs and artifact hashes.
