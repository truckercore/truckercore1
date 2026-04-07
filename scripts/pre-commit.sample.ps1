# Pre-commit hook sample for Windows/PowerShell
# Copy or symlink this file to .git/hooks/pre-commit and ensure it is executable.
# It will run Dart format and analyze; commit will be aborted on failures.

Write-Host "Running dart format check..." -ForegroundColor Cyan
$fmt = dart format --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) {
  Write-Host "dart format reported changes. Please format your code." -ForegroundColor Red
  exit 1
}

Write-Host "Running dart analyze..." -ForegroundColor Cyan
$an = dart analyze
if ($LASTEXITCODE -ne 0) {
  Write-Host "dart analyze found issues. Please fix them before committing." -ForegroundColor Red
  exit 1
}

Write-Host "Pre-commit checks passed." -ForegroundColor Green
exit 0
