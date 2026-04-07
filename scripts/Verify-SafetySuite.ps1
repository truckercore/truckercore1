<#
.SYNOPSIS
    Verifies Safety Summary Suite deployment
.DESCRIPTION
    Standalone verification script for Safety Summary components
#>

$ErrorActionPreference = "Stop"

$SUPABASE_URL = $env:SUPABASE_URL
if (-not $SUPABASE_URL) { $SUPABASE_URL = $env:NEXT_PUBLIC_SUPABASE_URL }

$SERVICE_KEY = $env:SUPABASE_SERVICE_ROLE_KEY
$ANON_KEY = $env:SUPABASE_ANON_KEY
if (-not $ANON_KEY) { $ANON_KEY = $env:NEXT_PUBLIC_SUPABASE_ANON_KEY }

$passed = 0
$failed = 0

function Test-Feature {
    param(
        [string]$Name,
        [scriptblock]$TestBlock
    )
    
    Write-Host -NoNewline "$Name... "
    try {
        & $TestBlock
        Write-Host "✓" -ForegroundColor Green
        $script:passed++
    }
    catch {
        Write-Host "✗ $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
}

if (-not $SUPABASE_URL -or -not $SERVICE_KEY) {
    Write-Host "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" -ForegroundColor Red
    exit 1
}

Write-Host "Running Safety Summary Suite Verification`n" -ForegroundColor Cyan

# Test tables
Test-Feature "safety_daily_summary exists" {
    $headers = @{
        "apikey" = $SERVICE_KEY
        "Authorization" = "Bearer $SERVICE_KEY"
    }
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/safety_daily_summary?limit=0" -Headers $headers
}

Test-Feature "risk_corridor_cells exists" {
    $headers = @{
        "apikey" = $SERVICE_KEY
        "Authorization" = "Bearer $SERVICE_KEY"
    }
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/risk_corridor_cells?limit=0" -Headers $headers
}

Test-Feature "v_export_alerts view accessible" {
    $headers = @{ "apikey" = if ($ANON_KEY) { $ANON_KEY } else { $SERVICE_KEY } }
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/v_export_alerts?limit=1" -Headers $headers
}

# Test RPC
Test-Feature "refresh_safety_summary RPC" {
    $headers = @{
        "apikey" = $SERVICE_KEY
        "Authorization" = "Bearer $SERVICE_KEY"
        "Content-Type" = "application/json"
        "Prefer" = "params=single-object"
    }
    $body = @{ p_org = $null; p_days = 1 } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/rpc/refresh_safety_summary" -Method Post -Headers $headers -Body $body
}

# Test Edge Function
Test-Feature "refresh-safety-summary Edge Function" {
    $headers = @{ "Authorization" = "Bearer $SERVICE_KEY" }
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/functions/v1/refresh-safety-summary" -Method Post -Headers $headers
}

# Data integrity
Test-Feature "safety_daily_summary data integrity" {
    $headers = @{
        "apikey" = $SERVICE_KEY
        "Authorization" = "Bearer $SERVICE_KEY"
    }
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/safety_daily_summary?limit=1" -Headers $headers
    # Should parse JSON without error
}

Write-Host "`n$passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
exit $(if ($failed -gt 0) { 1 } else { 0 })
