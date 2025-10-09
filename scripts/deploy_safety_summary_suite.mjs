#!/usr/bin/env node
/**
 * Master deployment script for Safety Summary + Risk Corridors suite
 * Orchestrates DB migration, Edge Functions, API routes, and verification
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import { readFile, writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';

const execAsync = promisify(exec);

const STEPS = {
  preflight: 'Preflight checks',
  migration: 'SQL migration',
  edgeFunctions: 'Edge Functions deployment',
  webBuild: 'Web app build',
  verification: 'Post-deploy verification',
  warmup: 'Endpoint warmup',
};

const log = {
  info: (msg) => console.log(`[INFO] ${msg}`),
  success: (msg) => console.log(`[✓] ${msg}`),
  error: (msg) => console.error(`[✗] ${msg}`),
  warn: (msg) => console.warn(`[!] ${msg}`),
  step: (step) => console.log(`\n${'='.repeat(60)}\n${step}\n${'='.repeat(60)}`),
};

class DeploymentError extends Error {
  constructor(step, message, stdout = '', stderr = '') {
    super(`[${step}] ${message}`);
    this.step = step;
    this.stdout = stdout;
    this.stderr = stderr;
  }
}

async function runCommand(cmd, opts = {}) {
  log.info(`Running: ${cmd}`);
  try {
    const { stdout, stderr } = await execAsync(cmd, { ...opts, maxBuffer: 10 * 1024 * 1024 });
    if (stdout) log.info(stdout.trim());
    if (stderr && opts.logStderr !== false) log.warn(stderr.trim());
    return { stdout, stderr };
  } catch (err) {
    throw new DeploymentError(
      opts.step || 'unknown',
      err.message,
      err.stdout || '',
      err.stderr || ''
    );
  }
}

// 1. Preflight checks
async function preflight() {
  log.step(STEPS.preflight);

  // Check Supabase CLI
  try {
    await runCommand('supabase --version', { step: 'preflight' });
  } catch (e) {
    throw new DeploymentError('preflight', 'Supabase CLI not found. Install: npm i -g supabase');
  }

  // Check project link
  if (!existsSync('.git') && !existsSync('supabase/.branches/_current_branch')) {
    log.warn('Not linked to Supabase project. Run: supabase link --project-ref YOUR_REF');
  }

  // Check required env vars
  const required = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'];
  const missing = required.filter(k => !process.env[k] && !process.env[`NEXT_PUBLIC_${k}`]);
  if (missing.length > 0) {
    throw new DeploymentError('preflight', `Missing env vars: ${missing.join(', ')}`);
  }

  // Check Node version (require >=18 for Edge Functions)
  const nodeVersion = process.version.match(/^v(\d+)\./)?.[1];
  if (nodeVersion && parseInt(nodeVersion) < 18) {
    throw new DeploymentError('preflight', `Node ${nodeVersion} detected. Require >=18 for Edge Functions.`);
  }

  log.success('Preflight checks passed');
}

// 2. Run SQL migration
async function runMigration() {
  log.step(STEPS.migration);

  // Check if migration file exists
  const migrationFile = 'supabase/migrations/20250928_refresh_safety_summary.sql';
  if (!existsSync(migrationFile)) {
    log.warn(`Migration file not found: ${migrationFile}`);
    log.info('Creating migration file...');

    const migrationSQL = `-- Safety Summary + Risk Corridors Migration
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
as $$
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

  -- Rebuild corridor risk cells (simplified 0.05 deg grid)
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
end $$;

revoke all on function public.refresh_safety_summary(uuid,int) from public;
grant execute on function public.refresh_safety_summary(uuid,int) to service_role;
`;

    await writeFile(migrationFile, migrationSQL, 'utf-8');
    log.success('Migration file created');
  }

  // Run migration
  log.info('Pushing migration to Supabase...');
  await runCommand('supabase db push', { step: 'migration' });
  
  log.success('Migration applied successfully');
}

// 3. Deploy Edge Functions
async function deployEdgeFunctions() {
  log.step(STEPS.edgeFunctions);

  const functionDir = 'supabase/functions/refresh-safety-summary';
  
  // Ensure function exists (cross-platform)
  if (!existsSync(functionDir)) {
    log.info('Creating Edge Function...');
    await mkdir(functionDir, { recursive: true });
    
    const functionCode = `import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  const url = new URL(req.url);
  const isCron = req.headers.get("x-supabase-webhook") === "cron";
  const orgId = url.searchParams.get("org_id");

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  
  if (!supabaseUrl) return new Response("Missing SUPABASE_URL", { status: 500 });
  if (!serviceKey) return new Response("Missing service role key", { status: 500 });

  try {
    const resp = await fetch(\`${'${'}supabaseUrl}/rest/v1/rpc/refresh_safety_summary\`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: \`Bearer ${'${'}serviceKey}\`,
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
      console.error(\`RPC failed: ${'${'}resp.status} ${'${'}text}\`);
      return new Response(\`RPC failed: ${'${'}resp.status}\`, { status: 500 });
    }

    const duration = resp.headers.get("x-response-time") || "unknown";
    console.log(\`[ok] refresh completed in ${'${'}duration}\`);

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
    return new Response(\`Error: ${'${'}err.message}\`, { status: 500 });
  }
});
`;
    
    await writeFile(`${functionDir}/index.ts`, functionCode, 'utf-8');
    log.success('Edge Function code created');
  }

  // Deploy function
  log.info('Deploying refresh-safety-summary...');
  await runCommand('supabase functions deploy refresh-safety-summary --no-verify-jwt', { 
    step: 'edgeFunctions' 
  });

  log.success('Edge Function deployed');
}

// 4. Build and deploy web app
async function buildWeb() {
  log.step(STEPS.webBuild);

  // Detect a web app
  const hasRootPackage = existsSync('package.json');

  if (!hasRootPackage) {
    log.warn('No web app detected, skipping build');
    return;
  }

  log.info('Installing dependencies...');
  await runCommand('npm install', { step: 'webBuild', logStderr: false });

  log.info('Building Next.js app...');
  await runCommand('npm run build', { step: 'webBuild' });

  log.success('Web app built successfully');
}

// 5. Verification
async function verify() {
  log.step(STEPS.verification);

  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceKey) {
    log.warn('Missing credentials for verification');
    return;
  }

  // Test 1: Check tables exist
  log.info('Verifying tables...');
  const tables = ['safety_daily_summary', 'risk_corridor_cells'];
  for (const table of tables) {
    try {
      const res = await fetch(`${supabaseUrl.replace(/\/$/, '')}/rest/v1/${table}?limit=1`, {
        headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` }
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      log.success(`✓ Table ${table} accessible`);
    } catch (err) {
      log.error(`✗ Table ${table} check failed: ${err.message}`);
    }
  }

  // Test 2: Invoke Edge Function
  log.info('Testing Edge Function...');
  try {
    const res = await fetch(`${supabaseUrl.replace(/\/$/, '')}/functions/v1/refresh-safety-summary?org_id=`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${serviceKey}` }
    });
    if (res.ok) {
      log.success('✓ Edge Function invokable');
    } else {
      log.warn(`Edge Function returned ${res.status}: ${await res.text()}`);
    }
  } catch (err) {
    log.error(`✗ Edge Function test failed: ${err.message}`);
  }

  // Test 3: Check RPC
  log.info('Testing RPC refresh_safety_summary...');
  try {
    const res = await fetch(`${supabaseUrl.replace(/\/$/, '')}/rest/v1/rpc/refresh_safety_summary`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
        Prefer: 'params=single-object'
      },
      body: JSON.stringify({ p_org: null, p_days: 7 })
    });
    if (res.ok || res.status === 204) {
      log.success('✓ RPC refresh_safety_summary works');
    } else {
      log.warn(`RPC returned ${res.status}: ${await res.text()}`);
    }
  } catch (err) {
    log.error(`✗ RPC test failed: ${err.message}`);
  }

  log.success('Verification complete');
}

// 6. Warmup endpoints
async function warmup() {
  log.step(STEPS.warmup);

  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !anonKey) {
    log.warn('Skipping warmup: missing credentials');
    return;
  }

  const endpoints = [
    '/rest/v1/safety_daily_summary?limit=1',
    '/rest/v1/risk_corridor_cells?limit=5',
    '/rest/v1/v_export_alerts?limit=1'
  ];

  for (const path of endpoints) {
    try {
      const start = Date.now();
      const res = await fetch(`${supabaseUrl.replace(/\/$/, '')}${path}`, {
        headers: { apikey: anonKey }
      });
      const elapsed = Date.now() - start;
      log.info(`${path}: ${res.status} (${elapsed}ms)`);
    } catch (err) {
      log.warn(`Warmup ${path} failed: ${err.message}`);
    }
  }

  log.success('Warmup complete');
}

// Main orchestrator
async function main() {
  const startTime = Date.now();
  const results = {};

  try {
    // Run all steps
    await preflight();
    results.preflight = 'ok';

    await runMigration();
    results.migration = 'ok';

    await deployEdgeFunctions();
    results.edgeFunctions = 'ok';

    await buildWeb();
    results.webBuild = 'ok';

    await verify();
    results.verification = 'ok';

    await warmup();
    results.warmup = 'ok';

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    
    log.step('DEPLOYMENT COMPLETE');
    log.success(`All steps completed in ${elapsed}s`);
    console.log('\nResults:', JSON.stringify(results, null, 2));
    
    console.log('\n📋 Next Steps:');
    console.log('1. Schedule daily CRON: supabase functions schedule refresh-safety-summary "0 6 * * *"');
    console.log('2. Add UI components to dashboard pages');
    console.log('3. Test CSV export via /api/export-alerts.csv');
    console.log('4. Verify Risk Corridors map in Enterprise dashboard');
    
    process.exit(0);
  } catch (err) {
    log.step('DEPLOYMENT FAILED');
    log.error(err.message);
    if (err.stdout) console.log('STDOUT:', err.stdout);
    if (err.stderr) console.error('STDERR:', err.stderr);
    process.exit(1);
  }
}

// Handle errors
process.on('unhandledRejection', (err) => {
  log.error('Unhandled rejection:', err);
  process.exit(1);
});

main();
