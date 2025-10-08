# NPM Audit & Dependency Hygiene Runbook

This runbook explains how to handle npm warnings/vulnerabilities in this monorepo (Windows-friendly instructions included).

## Summary
- You may see a deprecation warning for `lodash.get@4.4.2`. It is not directly used by our code; it is a transitive dependency pulled in by upstream packages. It is safe to ignore, but keep dependencies updated to reduce noise.
- If `npm audit` reports vulnerabilities, prefer targeted upgrades and non‑breaking fixes first. Use `--force` only as a last resort.

## Quick Commands

- Show advisories:
  - Windows PowerShell:
    - `npm audit`
  - JSON report:
    - `npm audit --json > reports\\npm-audit.json`

- Attempt non‑breaking fixes:
  - `npm run audit:fix`

- As a last resort (may introduce breaking changes):
  - `npm run audit:fix:force`

## Recommended Procedure

1. Inspect current issues
   - Run `npm audit` at the repo root (it will traverse workspaces if configured).
   - Review the list of vulnerable packages, severity, and dependency paths.

2. Prefer direct, non‑breaking updates
   - If a vulnerable package is listed as a direct dependency in `package.json`, bump to the latest compatible patch/minor version.
   - Re‑run `npm install` and `npm audit`.

3. For transitive vulnerabilities
   - Check if your direct dependency has released a fix. Bump that dependency to a version that includes a patched transitive tree.
   - If upstream hasn’t cut a release yet and a safe override exists, consider using npm `overrides` in the root `package.json` to pin a patched transitive dependency.
   - Example (add to the root package.json):
     ```json
     {
       "overrides": {
         "some-transitive-package": "^1.2.3"
       }
     }
     ```
   - Avoid broad overrides that risk breaking Electron/Next.js.

4. Verify locally
   - `npm install` (regenerates lockfile respecting overrides).
   - `npm audit` (ensure findings are reduced/cleared).
   - Run key scripts to verify nothing broke:
     - `npm run typecheck`
     - `npm run build`
     - Desktop postinstall hook should complete: `electron-builder install-app-deps`.

5. Track changes
   - Commit updated `package-lock.json` and any `package.json` bumps/overrides.
   - Reference this runbook in PR description. Include the before/after `npm audit` counts and a note if any high/critical advisories remain (and why).

## Notes
- `lodash.get` deprecation: This is an upstream deprecation notice. We do not import `lodash.get` directly in the repo; it appears only in the lockfile via nested dependencies. Keeping top‑level packages modern is the best way to eliminate it.
- Electron + Windows: After dependency changes, ensure the postinstall step still succeeds:
  - `electron-builder install-app-deps` should rebuild native modules (e.g., keytar) without errors.

## Troubleshooting
- If `npm audit fix` proposes breaking semver jumps:
  - Prefer targeted manual bumps instead of `--force`.
  - Test the web app (`next dev`, `next build`) and Electron app launch before committing.
- If an override is necessary but causes build/runtime issues:
  - Revert the override and instead pin the direct dependency to a version that contains the upstream fix.

---
Maintainers: Update this document with package‑specific guidance as needed (e.g., known safe versions of Next.js, Electron, or other key libraries that address security advisories).