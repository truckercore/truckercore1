# Debug Signing Runbook (DevDebug)

Purpose: Ensure DevDebug builds always use the default Android debug keystore and recover quickly if signing errors appear.

## Where the default debug keystore lives
- Windows: %USERPROFILE%\.android\debug.keystore
- macOS/Linux: ~/.android/debug.keystore
- Alias: androiddebugkey
- Passwords: android (store + key)

## CI behavior
- The Windows DevDebug job ensures the debug.keystore exists (generates it if missing).
- The job writes keystore_info.txt with the path and SHA256 hash for traceability (non‑secret) and uploads it with artifacts.
- DevDebug APK and full build logs are uploaded as artifacts, alongside the first-error scan output.

## Common errors and fixes

### Missing signing config / keystore file not found
- Confirm you are building a debug variant (DevDebug) and not release.
- Ensure the default debug keystore exists under the profile directory above.
- On a new machine/runner, open Android Studio once and run a debug build or generate the keystore via keytool:
```
keytool -genkeypair -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```
- Re-run the DevDebug build.

### Failed to read key / password incorrect
- You may be pointing debug to a custom or release keystore.
- DevDebug must never reference release signing; revert to using the default debug configuration.

### V2/V3 signing mismatch
- This typically concerns release builds or misapplied custom signing. DevDebug should inherit the stock debug signing; do not override.

## Verification steps
1) Run scripts\run_dev_debug.ps1 locally. If it fails, run scripts\first_error.ps1 or scripts\extract_first_error.ps1 -Context 5.
2) In CI, inspect the devdebug-artifacts bundle:
   - build_full.log
   - first_error.txt (should indicate no error-like lines)
   - keystore_info.txt (path + SHA256)
   - APK file (devDebug)

## Policy
- PR builds may only use debug signing.
- Release signing is isolated to protected jobs with secrets and must not be referenced by any debug variant or job.
