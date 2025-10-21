# Troubleshooting Guide

## Common Issues

### 1. npm Scripts Fail with ts-node Error

**Symptom:** `npx ts-node: command not found`

**Solution:**

```
# Install ts-node and dependencies
npm install --save-dev ts-node @types/node typescript

# Verify installation
npx ts-node --version
```

### 2. Coverage Thresholds Not Enforced in CI

**Symptom:** CI passes despite low coverage

**Solution:**

```
# Check workflow has coverage gate
cat .github/workflows/test.yml | grep "coverage:check"
# Should see step that runs: npm run coverage:check

# If missing, add to workflow:
- name: Fail if coverage thresholds not met
  if: matrix.node-version == '20.x'
  run: npm run coverage:check
```

### 3. Tests Pass Locally but Fail in CI

**Symptom:** Tests work locally but fail on GitHub Actions

**Solution:**

```
# Run in CI mode locally
npm run test:ci

# Check for environment differences
# Common issues:
# - Timezone differences
# - Missing environment variables
# - File path differences (case sensitivity)
```

### 4. Validation Scripts Not Executable

**Symptom:** `Permission denied` when running scripts

**Solution:**

```
# Make scripts executable
chmod +x verify-setup.sh
chmod +x validate-implementation.sh
chmod +x health-check.sh
chmod +x final-verification.sh

# Or all at once
chmod +x *.sh
```

### 5. GitHub Workflows Not Triggering

**Symptom:** No workflows appear in Actions tab

**Solution:**

```
# Check workflows exist
ls -la .github/workflows/

# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))"

# Ensure workflows are on default branch
git branch --show-current
# Push must be to branch that workflow monitors
```

### 6. Dependabot Not Creating PRs

**Symptom:** No Dependabot activity after a week

**Solution:**
1. Check: Settings → Code security and analysis → Dependabot
2. Ensure Dependabot is enabled
3. Check `.github/dependabot.yml` syntax
4. Wait for schedule (Mondays 9 AM UTC)
5. Check: Insights → Dependency graph → Dependabot

### 7. VSCode Vitest Extension Not Working

**Symptom:** Tests don't appear in VSCode sidebar

**Solution:**
1. Install extension: `ZixuanChen.vitest-explorer`
2. Reload window: Cmd/Ctrl+Shift+P → "Reload Window"
3. Check `.vscode/settings.json` exists
4. View → Output → Select "Vitest" from dropdown
5. Check for errors in Vitest output

### 8. Security Audit Fails

**Symptom:** `npm audit` or `security:metrics` fails

**Solution:**

```
# Clear cache and retry
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
npm audit

# Check for registry issues
npm config get registry
# Should be: https://registry.npmjs.org/
```

## Getting Help

1. **Check validation scripts:** `./health-check.sh`
2. **Review logs:** GitHub Actions → Select workflow → View logs
3. **Check documentation:** INFRASTRUCTURE.md, SECURITY.md
4. **Review this guide:** TROUBLESHOOTING.md
5. **Open issue:** Use GitHub Issues with relevant logs

## Quick Diagnostics

```
# Run complete diagnostic
./health-check.sh

# Check specific component
npm run test:run      # Tests
npm run test:coverage # Coverage
npm audit             # Security
git status           # Git
```