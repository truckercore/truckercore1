# Regenerate package-lock.json on Windows (Node 18 / Linux parity)

This helper documents the Windows fallback used to regenerate `package-lock.json` when Docker/WSL is not available or you prefer a native Windows flow.

Overview
- Primary (recommended): run the Docker steps to regenerate a Linux-parity lockfile (see project README). Docker matches Vercel's Linux environment and avoids native rebuild surprises.
- Windows fallback: use the provided PowerShell helper `scripts/Regenerate-Lockfile.ps1` which detects and prefers WSL, then `nvm-windows`, then `volta`, and finally falls back to the current Windows Node (with warnings).

Why use this
- `npm install` writes lockfile metadata that can differ by Node/npm/platform; Vercel runs Linux with Node 18. This helper ensures you can produce a Node-18-compatible lockfile from Windows, using WSL when available for best parity.

Quick commands (from repo root)

Run the new npm script (Windows PowerShell):

```powershell
# Run PowerShell helper which prefers WSL -> nvm-windows -> volta -> current Node
npm run lockfile:regen:win
# (equivalent) powershell -ExecutionPolicy Bypass -File ./scripts/Regenerate-Lockfile.ps1
```

Docker (recommended for Linux parity)

```cmd
:: Windows cmd.exe (from repo root)
docker run --rm -v "%cd%":/workspace -w /workspace node:18-bullseye bash -lc "rm -rf node_modules package-lock.json && npm install --include=dev --legacy-peer-deps"
```

What the PowerShell helper does
- Detects WSL (`wsl.exe`) and attempts to run a Node-18 install inside WSL (ensuring Linux parity).
- If WSL is not available or fails, it tries `nvm` (nvm-windows) to install and use Node 18.
- If `volta` is present, it pins/installs `node@18` and runs install.
- If none are available, it warns about the current Node version and runs `npm install` locally.

Verification you should perform after regeneration
1. Confirm `package-lock.json` changed:
```bash
git status --porcelain
# should show: M package-lock.json
```
2. Confirm the lockfile was generated with Node 18 (if using Docker or WSL):
```bash
docker run --rm node:18-bullseye bash -lc "node -v && npm -v"
# or inside WSL: node -v && npm -v
```
3. Optional: run a quick smoke build locally (may be slow):
```bash
# inside Docker (Linux parity)
docker run --rm -v "%cd%":/workspace -w /workspace node:18-bullseye bash -lc "npm run vercel-build"
```

Troubleshooting
- If the PowerShell script reports `Failed to convert path to WSL path`, ensure WSL is installed and `wsl.exe` is on PATH. Run `wsl -l -v` and ensure a default distro is available.
- If `nvm` is detected but `nvm install 18` fails, ensure you are using nvm-windows (not the UNIX nvm) and run the install/usage manually.
- If `npm install` fails due to native rebuilds (e.g., `better-sqlite3`, `keytar`), prefer the Docker method to avoid Windows vs Linux mismatches when deploying to Vercel.

Notes
- After regenerating the lockfile, create a branch, commit the updated `package-lock.json`, and open a PR so Vercel will run a preview deploy with `npm ci --include=dev --legacy-peer-deps` (per `vercel.json`).
- The helper script supports a `-DryRun` flag to show what it would do without modifying files.

Example PR title / body
- Title: `chore(ci): regenerate package-lock.json using Node 18 (Linux parity)`
- Body: See README / PR template in repo for recommended verification steps.

If you want, I can add a short reference in the top-level `README.md` linking to this document; tell me if you'd like that update included.

