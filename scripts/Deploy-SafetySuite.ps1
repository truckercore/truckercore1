<#
.SYNOPSIS
    Deploys TruckerCore Safety Summary Suite (SQL + Edge Functions + Web)
.DESCRIPTION
    Automated deployment script for Windows that handles:
    - Preflight checks
    - SQL migration
    - Edge Functions deployment
    - Web app build
    - Post-deploy verification
    - Endpoint warmup
.PARAMETER DryRun
    Run in dry-run mode without making changes
.PARAMETER SkipBuild
    Skip web app build step
.PARAMETER SkipVerify
    Skip post-deployment verification
.EXAMPLE
    .\scripts\Deploy-SafetySuite.ps1
.EXAMPLE
    .\scripts\Deploy-SafetySuite.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipBuild,
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors
$ColorInfo = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorStep = "Magenta"

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $ColorInfo
}

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor $ColorSuccess
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor $ColorWarning
}

function Write-Err {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor $ColorError
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $ColorStep
    Write-Host $Message -ForegroundColor $ColorStep
    Write-Host ("=" * 60) -ForegroundColor $ColorStep
}

# Command execution helper
function Invoke-Command-Safe {
    param(
        [string]$Command,
        [string]$Step,
        [switch]$IgnoreError
    )
    
    Write-Info "Running: $Command"
    
    if ($DryRun) {
        Write-Warn "[DRY-RUN] Would execute: $Command"
        return @{ Success = $true; Output = ""; Error = "" }
    }
    
    try {
        $output = Invoke-Expression $Command 2>&1
        if ($LASTEXITCODE -ne 0 -and -not $IgnoreError) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
        return @{ Success = $true; Output = $output; Error = "" }
    }
    catch {
        if ($IgnoreError) {
            Write-Warn "Command failed but continuing: $_"
            return @{ Success = $false; Output = ""; Error = $_.ToString() }
        }
        throw "[$Step] $($_.Exception.Message)"
    }
}

# Check if command exists
function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Step 1: Preflight checks
function Step-Preflight {
    Write-Step "Preflight Checks"
    
    # Check Supabase CLI
    if (-not (Test-CommandExists "supabase")) {
        throw "Supabase CLI not found. Install: npm install -g supabase"
    }
    
    $version = Invoke-Expression "supabase --version" 2>&1
    Write-Success "Supabase CLI found: $version"
    
    # Check Node.js
    if (-not (Test-CommandExists "node")) {
        throw "Node.js not found. Install from https://nodejs.org"
    }
    
    $nodeVersion = Invoke-Expression "node --version" 2>&1
    $nodeMajor = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
    if ($nodeMajor -lt 18) {
        throw "Node.js $nodeVersion detected. Require >=18 for Edge Functions."
    }
    Write-Success "Node.js $nodeVersion (OK)"
    
    # Check npm
    if (-not (Test-CommandExists "npm")) {
        throw "npm not found"
    }
    Write-Success "npm found"
    
    # Check project link
    if (-not (Test-Path "supabase\.branches\_current_branch") -and -not (Test-Path ".git")) {
        Write-Warn "Not linked to Supabase project. Run: supabase link --project-ref YOUR_REF"
    }
    
    # Check environment variables
    $requiredVars = @(
        "SUPABASE_URL",
        "SUPABASE_SERVICE_ROLE_KEY"
    )
    
    $missing = @()
    foreach ($var in $requiredVars) {
        if (-not [Environment]::GetEnvironmentVariable($var)) {
            # Check alternate names
            $alt = "NEXT_PUBLIC_$var"
            if (-not [Environment]::GetEnvironmentVariable($alt)) {
                $missing += $var
            }
        }
    }
    
    if ($missing.Count -gt 0) {
        throw "Missing environment variables: $($missing -join ', ')"
    }
    Write-Success "Required environment variables present"
    
    Write-Success "Preflight checks passed"
}

# Step 2: SQL Migration
function Step-Migration {
    Write-Step "SQL Migration"
    
    $migrationFile = "supabase\migrations\20250928_refresh_safety_summary.sql"
    
    if (-not (Test-Path $migrationFile)) {
        Write-Warn "Migration file not found: $migrationFile"
        Write-Info "Creating migration file..."
        
        # Ensure directory exists
        $migrationDir = Split-Path $migrationFile -Parent
        if (-not (Test-Path $migrationDir)) {
            New-Item -ItemType Directory -Path $migrationDir -Force | Out-Null
        }
        
        $migrationSQL = @"
-- Safety Summary + Risk Corridors Migration
-- Enable PostGIS already ensured by 00_extensions.sql

-- Safety summary materialized view (per org/day)
create table if not exists public.safety_daily_summary (
  org_id uuid not null,
  summary_date date not null,
  total_alerts integer not null default 0,
  urgent_alerts integer not null default 0,
  unique_drivers integer not null default 0,
  top_types jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (org_id, summary_date)
);

create index if not exists idx_safety_summary_org_date on public.safety_daily_summary (org_id, summary_date desc);

alter table public.safety_daily_summary enable row level security;

create policy "safety_summary_read_org" on public.safety_daily_summary 
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- CSV export view
create or replace view public.v_export_alerts as
select
  a.id,
  a.org_id,
  a.user_id as driver_id,
  a.source,
  a.event_type::text as event_type,
  a.title,
  a.message,
  a.severity::text as severity,
  st_x(a.geom) as lon,
  st_y(a.geom) as lat,
  a.context,
  a.created_at
from public.alert_events a;

alter view public.v_export_alerts owner to postgres;
grant select on public.v_export_alerts to anon, authenticated;

-- Risk corridor cells
create table if not exists public.risk_corridor_cells (
  id bigserial primary key,
  org_id uuid,
  cell geometry(Polygon, 4326) not null,
  alert_count int not null default 0,
  urgent_count int not null default 0,
  types jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists risk_corridor_cells_gix on public.risk_corridor_cells using gist (cell);
create index if not exists idx_risk_corridor_org on public.risk_corridor_cells (org_id, urgent_count desc);

alter table public.risk_corridor_cells enable row level security;

create policy "risk_corridor_read_org" on public.risk_corridor_cells
for select to authenticated
using (org_id is null or org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Refresh function
create or replace function public.refresh_safety_summary(p_org uuid default null, p_days int default 7)
returns void
language plpgsql
security definer
set search_path = public
as `$`$
declare
  d date;
  org uuid;
begin
  -- Rebuild daily summaries
  for d in select generate_series((current_date - (p_days::int - 1)), current_date, interval '1 day')::date loop
    for org in
      select distinct org_id from public.alert_events
      where (p_org is null or org_id = p_org)
        and created_at >= d::timestamptz
        and created_at < (d + 1)::timestamptz
    loop
      insert into public.safety_daily_summary as s (org_id, summary_date, total_alerts, urgent_alerts, unique_drivers, top_types, updated_at)
      select
        org,
        d,
        count(*)::int,
        count(*) filter (where severity = 'URGENT')::int,
        count(distinct user_id)::int,
        (
          select jsonb_agg(t order by t.ct desc)
          from (
            select event_type::text as type, count(*) as ct
            from public.alert_events
            where org_id = org
              and created_at >= d::timestamptz
              and created_at < (d + 1)::timestamptz
              and event_type is not null
            group by event_type
            order by count(*) desc
            limit 5
          ) t
        ) as top_types,
        now()
      on conflict (org_id, summary_date) do update
      set total_alerts = excluded.total_alerts,
          urgent_alerts = excluded.urgent_alerts,
          unique_drivers = excluded.unique_drivers,
          top_types = excluded.top_types,
          updated_at = now();
    end loop;
  end loop;

  -- Rebuild corridor risk cells
  delete from public.risk_corridor_cells where (p_org is null or org_id = p_org);
  
  insert into public.risk_corridor_cells (org_id, cell, alert_count, urgent_count, types, updated_at)
  with recent as (
    select *
    from public.alert_events
    where created_at >= now() - interval '30 days'
      and geom is not null
      and (p_org is null or org_id = p_org)
  ), grid as (
    select
      r.org_id,
      st_snaptogrid(r.geom::geometry, 0.05, 0.05) as g,
      r.event_type::text as type,
      r.severity
    from recent r
  ), agg as (
    select
      org_id,
      g,
      count(*) as alert_count,
      count(*) filter (where severity = 'URGENT') as urgent_count,
      jsonb_object_agg(type, cnt) as types
    from (
      select org_id, g, severity, type, count(*) as cnt
      from grid
      where type is not null
      group by org_id, g, severity, type
    ) t
    group by org_id, g
  )
  select
    org_id,
    st_makeenvelope(
      st_x(g) - 0.025, st_y(g) - 0.025,
      st_x(g) + 0.025, st_y(g) + 0.025,
      4326
    )::geometry(Polygon,4326),
    alert_count::int,
    urgent_count::int,
    types,
    now()
  from agg
  where alert_count > 0;
end `$`$;

revoke all on function public.refresh_safety_summary(uuid,int) from public;
grant execute on function public.refresh_safety_summary(uuid,int) to service_role;
"@
        
        Set-Content -Path $migrationFile -Value $migrationSQL -Encoding UTF8
        Write-Success "Migration file created"
    }
    
    # Run migration
    Write-Info "Pushing migration to Supabase..."
    Invoke-Command-Safe -Command "supabase db push" -Step "migration"
    
    Write-Success "Migration applied successfully"
}

# Step 3: Deploy Edge Functions
function Step-EdgeFunctions {
    Write-Step "Edge Functions Deployment"
    
    $functionDir = "supabase\functions\refresh-safety-summary"
    
    # Ensure function exists
    if (-not (Test-Path $functionDir)) {
        Write-Info "Creating Edge Function..."
        New-Item -ItemType Directory -Path $functionDir -Force | Out-Null
        
        $functionCode = @"
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  const url = new URL(req.url);
  const isCron = req.headers.get("x-supabase-webhook") === "cron";
  const orgId = url.searchParams.get("org_id");

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  
  if (!supabaseUrl) return new Response("Missing SUPABASE_URL", { status: 500 });
  if (!serviceKey) return new Response("Missing service role key", { status: 500 });

  try {
    const resp = await fetch(`${supabaseUrl}/rest/v1/rpc/refresh_safety_summary`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
        Prefer: "params=single-object",
      },
      body: JSON.stringify({
        p_org: orgId,
        p_days: 14,
      }),
    });

    if (!resp.ok) {
      const text = await resp.text();
      console.error(`RPC failed: ${resp.status} ${text}`);
      return new Response(`RPC failed: ${resp.status}`, { status: 500 });
    }

    const duration = resp.headers.get("x-response-time") || "unknown";
    console.log(`[ok] refresh completed in ${duration}`);

    return new Response(
      JSON.stringify({ 
        success: true, 
        cron: isCron, 
        org_id: orgId,
        timestamp: new Date().toISOString() 
      }),
      { 
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    );
  } catch (err) {
    console.error("Function error:", err);
    return new Response(`Error: ${err.message}`, { status: 500 });
  }
});
"@
        
        Set-Content -Path "$functionDir\index.ts" -Value $functionCode -Encoding UTF8
        Write-Success "Edge Function code created"
    }
    
    # Deploy function
    Write-Info "Deploying refresh-safety-summary..."
    Invoke-Command-Safe -Command "supabase functions deploy refresh-safety-summary --no-verify-jwt" -Step "edgeFunctions"
    
    Write-Success "Edge Function deployed"
}

# Step 4: Build Web App
function Step-WebBuild {
    if ($SkipBuild) {
        Write-Warn "Skipping web build (--SkipBuild flag)"
        return
    }
    
    Write-Step "Web App Build"
    
    # Check if Next.js app exists
    if (-not (Test-Path "apps\web\package.json") -and -not (Test-Path "package.json")) {
        Write-Warn "No web app detected, skipping build"
        return
    }
    
    Write-Info "Installing dependencies..."
    Invoke-Command-Safe -Command "npm install" -Step "webBuild" -IgnoreError
    
    Write-Info "Building Next.js app..."
    Invoke-Command-Safe -Command "npm run build" -Step "webBuild"
    
    Write-Success "Web app built successfully"
}

# Step 5: Verification
function Step-Verification {
    if ($SkipVerify) {
        Write-Warn "Skipping verification (--SkipVerify flag)"
        return
    }
    
    Write-Step "Post-Deployment Verification"
    
    $supabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL")
    if (-not $supabaseUrl) {
        $supabaseUrl = [Environment]::GetEnvironmentVariable("NEXT_PUBLIC_SUPABASE_URL")
    }
    
    $serviceKey = [Environment]::GetEnvironmentVariable("SUPABASE_SERVICE_ROLE_KEY")
    
    if (-not $supabaseUrl -or -not $serviceKey) {
        Write-Warn "Missing credentials for verification"
        return
    }
    
    # Test 1: Check tables exist
    Write-Info "Verifying tables..."
    $tables = @("safety_daily_summary", "risk_corridor_cells", "v_export_alerts")
    
    foreach ($table in $tables) {
        try {
            $headers = @{
                "apikey" = $serviceKey
                "Authorization" = "Bearer $serviceKey"
            }
            $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/$table`?limit=1" -Headers $headers -ErrorAction Stop
            Write-Success "✓ Table $table accessible"
        }
        catch {
            Write-Err "✗ Table $table check failed: $($_.Exception.Message)"
        }
    }
    
    # Test 2: Invoke Edge Function
    Write-Info "Testing Edge Function..."
    try {
        $headers = @{
            "Authorization" = "Bearer $serviceKey"
        }
        $response = Invoke-RestMethod -Uri "$supabaseUrl/functions/v1/refresh-safety-summary?org_id=" -Method Post -Headers $headers -ErrorAction Stop
        Write-Success "✓ Edge Function invokable"
    }
    catch {
        Write-Warn "Edge Function test: $($_.Exception.Message)"
    }
    
    # Test 3: Check RPC
    Write-Info "Testing RPC refresh_safety_summary..."
    try {
        $headers = @{
            "apikey" = $serviceKey
            "Authorization" = "Bearer $serviceKey"
            "Content-Type" = "application/json"
            "Prefer" = "params=single-object"
        }
        $body = @{
            p_org = $null
            p_days = 7
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/refresh_safety_summary" -Method Post -Headers $headers -Body $body -ErrorAction Stop
        Write-Success "✓ RPC refresh_safety_summary works"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 204) {
            Write-Success "✓ RPC refresh_safety_summary works (204)"
        }
        else {
            Write-Warn "RPC test: $($_.Exception.Message)"
        }
    }
    
    Write-Success "Verification complete"
}

# Step 6: Warmup
function Step-Warmup {
    Write-Step "Endpoint Warmup"
    
    $supabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL")
    if (-not $supabaseUrl) {
        $supabaseUrl = [Environment]::GetEnvironmentVariable("NEXT_PUBLIC_SUPABASE_URL")
    }
    
    $anonKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY")
    if (-not $anonKey) {
        $anonKey = [Environment]::GetEnvironmentVariable("NEXT_PUBLIC_SUPABASE_ANON_KEY")
    }
    
    if (-not $supabaseUrl -or -not $anonKey) {
        Write-Warn "Skipping warmup: missing credentials"
        return
    }
    
    $endpoints = @(
        "/rest/v1/safety_daily_summary?limit=1",
        "/rest/v1/risk_corridor_cells?limit=5",
        "/rest/v1/v_export_alerts?limit=1"
    )
    
    foreach ($path in $endpoints) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $headers = @{ "apikey" = $anonKey }
            $response = Invoke-RestMethod -Uri "$supabaseUrl$path" -Headers $headers -ErrorAction Stop
            $sw.Stop()
            Write-Info "$path : 200 ($($sw.ElapsedMilliseconds)ms)"
        }
        catch {
            Write-Warn "Warmup $path failed: $($_.Exception.Message)"
        }
    }
    
    Write-Success "Warmup complete"
}

# Main execution
function Main {
    $startTime = Get-Date
    $results = @{}
    
    try {
        if ($DryRun) {
            Write-Warn "=== DRY RUN MODE ==="
        }
        
        Step-Preflight
        $results["preflight"] = "ok"
        
        Step-Migration
        $results["migration"] = "ok"
        
        Step-EdgeFunctions
        $results["edgeFunctions"] = "ok"
        
        Step-WebBuild
        $results["webBuild"] = "ok"
        
        Step-Verification
        $results["verification"] = "ok"
        
        Step-Warmup
        $results["warmup"] = "ok"
        
        $elapsed = (Get-Date) - $startTime
        $elapsedSeconds = [math]::Round($elapsed.TotalSeconds, 1)
        
        Write-Step "DEPLOYMENT COMPLETE"
        Write-Success "All steps completed in $elapsedSeconds seconds"
        Write-Host ""
        Write-Host "Results:" -ForegroundColor Cyan
        $results | ConvertTo-Json | Write-Host
        
        Write-Host ""
        Write-Host "📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Schedule daily CRON: supabase functions schedule refresh-safety-summary \"0 6 * * *\""
        Write-Host "2. Add UI components to dashboard pages"
        Write-Host "3. Test CSV export via /api/export-alerts.csv"
        Write-Host "4. Verify Risk Corridors map in Enterprise dashboard"
        
        exit 0
    }
    catch {
        Write-Step "DEPLOYMENT FAILED"
        Write-Err $_.Exception.Message
        Write-Host ""
        Write-Host "Stack Trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace
        exit 1
    }
}

# Run main
Main
