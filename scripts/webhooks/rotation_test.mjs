// scripts/webhooks/rotation_test.mjs
// Self-test for dual-secret rotation and replay protection. Exits non-zero on failure.
import { signWithSecret, resolveVerificationSecrets, verifyIncomingWebhook } from './rotation.mjs';

function assert(cond, msg){ if (!cond) { console.error('[rotation_test] fail:', msg); process.exit(1);} }

const subBase = {
  id: 'sub_123',
  org_id: 'org_1',
  name: 'Test',
  endpoint_url: 'http://localhost:0',
  topics: ['demo'],
  is_active: true,
  max_in_flight: 2,
};

const now = Math.floor(Date.now()/1000);
const body = JSON.stringify({ hello: 'world' });

// 1) Only current secret
{
  const sub = { ...subBase, secret: 's_cur' };
  const ts = String(now);
  const sig = signWithSecret(sub.secret, ts, body);
  assert(verifyIncomingWebhook(sub, sig, ts, body) === true, 'current-only must verify');
}

// 2) Active rotation window: verify against current and next
{
  const cutoff = new Date(Date.now() + 5*60*1000).toISOString();
  const sub = { ...subBase, secret: 's_cur', secret_next: 's_next', secret_next_expires_at: cutoff };
  const ts = String(now);
  const sigCur = signWithSecret('s_cur', ts, body);
  const sigNext = signWithSecret('s_next', ts, body);
  assert(verifyIncomingWebhook(sub, sigCur, ts, body) === true, 'rotation window: current must verify');
  assert(verifyIncomingWebhook(sub, sigNext, ts, body) === true, 'rotation window: next must verify');
}

// 3) Post-cutover: next preferred; current may still verify until promotion persisted
{
  const cutoffPast = new Date(Date.now() - 60*1000).toISOString();
  const sub = { ...subBase, secret: 's_cur', secret_next: 's_next', secret_next_expires_at: cutoffPast };
  const ts = String(now);
  const sigNext = signWithSecret('s_next', ts, body);
  assert(verifyIncomingWebhook(sub, sigNext, ts, body) === true, 'post-cutover: next must verify');
}

// 4) Skew rejection
{
  const sub = { ...subBase, secret: 's_cur' };
  const tsOld = String(now - 301);
  const sig = signWithSecret(sub.secret, tsOld, body);
  assert(verifyIncomingWebhook(sub, sig, tsOld, body) === false, 'reject skewed timestamps');
}

// 5) Replay protection via in-memory seen set
{
  const sub = { ...subBase, secret: 's_cur' };
  const ts = String(now);
  const sig = signWithSecret(sub.secret, ts, body);
  const seen = new Set();
  const ok1 = verifyIncomingWebhook(sub, sig, ts, body, { isReplay: (t, s, id) => { const k = `${id}:${t}:${s}`; if (seen.has(k)) return true; seen.add(k); return false; } });
  const ok2 = verifyIncomingWebhook(sub, sig, ts, body, { isReplay: (t, s, id) => { const k = `${id}:${t}:${s}`; if (seen.has(k)) return true; seen.add(k); return false; } });
  assert(ok1 === true && ok2 === false, 'replay protection must reject second attempt');
}

console.log('[rotation_test] passed');
