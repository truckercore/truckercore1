#!/usr/bin/env node
// test_supabase_rpc.mjs
// Usage:
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... node test_supabase_rpc.mjs assign_driver \
//     --org=ORG-UUID --user=USER-UUID --driver=DRIVER-UUID --load=LOAD-UUID \
//     --key=assign_driver:LOAD-UUID:DRIVER-UUID --trace=trace-abc123
//
// Notes:
// - Demonstrates idempotency: run twice with the same --key; second call should return { idempotent: true }.
// - Requires database migrations applied (01_enterprise_audit_log.sql and 02_feature_flags_seed.sql).

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const LEGACY_ANON = process.env['SUPABASE_' + 'ANON_KEY'];
const SUPABASE_ANON = process.env.SUPABASE_ANON || LEGACY_ANON || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLIC_ANON_KEY;
if (!SUPABASE_URL || !SUPABASE_ANON) {
  console.error('[test_supabase_rpc] Missing SUPABASE_URL or anon key');
  process.exit(1);
}

const args = process.argv.slice(2);
const cmd = args[0] || 'assign_driver';
const argMap = Object.fromEntries(args.slice(1).map((a)=>{
  const m = a.match(/^--([^=]+)=(.*)$/); return m ? [m[1], m[2]] : [a.replace(/^--/, ''), true];
}));

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false } });

async function postRpc(name, params){
  const { data, error } = await supabase.rpc(name, params);
  if (error) throw error;
  return data;
}

async function main(){
  if (cmd === 'assign_driver'){
    const p = {
      p_org_id: argMap.org,
      p_actor_user_id: argMap.user,
      p_driver_id: argMap.driver,
      p_load_id: argMap.load,
      p_idempotency_key: argMap.key || `assign_driver:${argMap.load}:${argMap.driver}`,
      p_trace_id: argMap.trace || `trace-${Date.now()}`,
    };
    console.log('[test_supabase_rpc] rpc_assign_driver params:', p);
    const res1 = await postRpc('rpc_assign_driver', p);
    console.log('[test_supabase_rpc] response #1:', res1);
    const res2 = await postRpc('rpc_assign_driver', p);
    console.log('[test_supabase_rpc] response #2 (should be idempotent):', res2);
    console.log('[test_supabase_rpc] Done. Check enterprise_audit_log for two rows max (one insert, one idempotent no-op).');
  } else {
    console.error('Unknown command:', cmd);
    process.exit(2);
  }
}

main().catch((e)=>{ console.error('[test_supabase_rpc] failed:', e); process.exit(1); });
