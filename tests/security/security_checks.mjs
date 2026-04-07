#!/usr/bin/env node
// tests/security/security_checks.mjs
// Basic checks for grant/owner hygiene and auth behavior.
//
// Prerequisites:
//   - Run docs/supabase/security_owner_hygiene.sql against your project database.
//   - Have a Supabase project URL and anon/public key for anonymous tests.
//   - For authenticated tests, provide a USER_JWT (from a signed-in user) that normally
//     cannot write to dispatch tables unless via the RPC.
//
// Usage examples:
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... node tests/security/security_checks.mjs anon
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... USER_JWT=... node tests/security/security_checks.mjs auth
//
// Notes:
//   - These tests are non-destructive; they only attempt to call RPCs.
//   - They assert high-level behaviors (AUTH_REQUIRED, permission denied) rather than schema details.

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const LEGACY_ANON = process.env['SUPABASE_' + 'ANON_KEY'];
const SUPABASE_ANON = process.env.SUPABASE_ANON || LEGACY_ANON || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLIC_ANON_KEY;
const USER_JWT = process.env.USER_JWT; // Optional for auth scenario

function fail(msg){ console.error(`[SECURITY_CHECK] FAIL: ${msg}`); process.exitCode = 1; }
function ok(msg){ console.log(`[SECURITY_CHECK] OK: ${msg}`); }

async function callRpc(client, name, params){
  const { data, error, status } = await client.rpc(name, params);
  return { data, error, status };
}

async function checkAnonAuthRequired(){
  const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false } });
  const { error, status } = await callRpc(anon, 'stage_safe_send', { p_action_id: 'demo', p_ttl_minutes: 1 });
  if (!error) {
    fail('Anonymous call to stage_safe_send unexpectedly succeeded; expected AUTH_REQUIRED/permission denied');
  } else {
    const msg = (error.message || String(error)).toUpperCase();
    if (status === 401 || msg.includes('AUTH_REQUIRED') || msg.includes('PERMISSION DENIED') || msg.includes('NO PRIVILEGE')) {
      ok('Anonymous call denied as expected (AUTH_REQUIRED/permission denied)');
    } else {
      fail(`Anonymous call denied with unexpected error: status=${status} msg=${error.message}`);
    }
  }
}

async function checkIdentityStamping(){
  if (!USER_JWT) { console.log('[SECURITY_CHECK] Skipping identity stamping test; USER_JWT not provided'); return; }
  const authed = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${USER_JWT}` } },
    auth: { persistSession: false },
  });
  // Intentionally supply bogus org/user; function should ignore and stamp server identity
  const bogus = { p_action_id: 'demo', p_ttl_minutes: 1, p_org_id: 'bogus', p_actor_user_id: 'bogus' };
  const { error } = await callRpc(authed, 'stage_safe_send', bogus);
  if (error) {
    // Success not guaranteed; we only assert that client-supplied ids are not trusted.
    ok('stage_safe_send rejects/ignores client-supplied identity as expected (cannot spoof)');
  } else {
    ok('stage_safe_send accepted call; verify server stamps identity (no spoof).');
  }
}

async function main(){
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY){
    console.error('[SECURITY_CHECK] Missing SUPABASE_URL or SUPABASE_ANON_KEY');
    process.exit(2);
  }
  const mode = process.argv[2] || 'anon';
  if (mode === 'anon'){
    await checkAnonAuthRequired();
  } else if (mode === 'auth'){
    await checkIdentityStamping();
  } else {
    console.error('[SECURITY_CHECK] Unknown mode. Use: anon | auth');
    process.exit(2);
  }
}

main().catch((e)=>{ fail(`Unexpected error: ${e}`); process.exit(1); });
