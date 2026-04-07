param(
  [switch]$SkipMigrations
)

# scripts/deploy_supabase_schemas.ps1
# Deploy all Supabase schemas for this repository.
# - Applies migrations in supabase/migrations via `supabase db push` (unless -SkipMigrations)
# - Applies standalone SQL files in docs/supabase via `supabase db query -f <file.sql>` in sorted order
#
# Prerequisites:
#   - Supabase CLI installed and authenticated (supabase login)
#   - Project linked or provide flags as needed (CLI will prompt)
#
# Usage:
#   powershell -File scripts/deploy_supabase_schemas.ps1
#   powershell -File scripts/deploy_supabase_schemas.ps1 -SkipMigrations

$ErrorActionPreference = 'Stop'

function Invoke-Supabase {
  param([string[]]$Args)
  Write-Host ("[deploy_schemas] supabase " + ($Args -join ' ')) -ForegroundColor DarkGray
  supabase @Args
}

# 1) Apply migrations
if (-not $SkipMigrations) {
  Write-Host "[deploy_schemas] Applying migrations via 'supabase db push'..." -ForegroundColor Cyan
  Invoke-Supabase @('db','push')
  Write-Host "[deploy_schemas] Migrations applied." -ForegroundColor Green
} else {
  Write-Host "[deploy_schemas] Skipping migrations (per flag)." -ForegroundColor Yellow
}

# 2) Apply standalone SQL files under docs/supabase (sorted for determinism)
$docsDir = Join-Path $PSScriptRoot '..' 'docs' 'supabase'
if (Test-Path $docsDir) {
  $sqlFiles = Get-ChildItem -Path $docsDir -Filter '*.sql' | Sort-Object Name
  if ($sqlFiles.Count -eq 0) {
    Write-Host "[deploy_schemas] No *.sql files found under docs/supabase." -ForegroundColor Yellow
  } else {
    Write-Host "[deploy_schemas] Applying $($sqlFiles.Count) SQL file(s) from docs/supabase..." -ForegroundColor Cyan
    foreach ($f in $sqlFiles) {
      Write-Host "[deploy_schemas] Applying: $($f.Name)" -ForegroundColor DarkCyan
      Invoke-Supabase @('db','query','-f', $f.FullName)
    }
    Write-Host "[deploy_schemas] docs/supabase SQL applied." -ForegroundColor Green
  }
} else {
  Write-Host "[deploy_schemas] docs/supabase directory not found (skipping)." -ForegroundColor Yellow
}

Write-Host "[deploy_schemas] Done." -ForegroundColor Cyan
