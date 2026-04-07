// probes/pos_hmac_invalid.mjs
import { printProbe, exitFor } from './lib/probe.js';

const start = Date.now();
let status = 'pass';
let details = {};
let evidence = {};

try {
  const url = process.env.POS_WEBHOOK_URL;
  const secret = process.env.POS_WEBHOOK_SECRET; // unused intentionally to craft invalid signature
  if (!url || !secret) {
    status = 'degraded';
    details = { hint: 'missing_env', required: ['POS_WEBHOOK_URL', 'POS_WEBHOOK_SECRET'] };
  } else {
    const payload = { event: 'probe.invalid_sig', ts: new Date().toISOString() };
    const body = JSON.stringify(payload);
    const ts = new Date().toISOString();
    // Craft an invalid signature deliberately
    const badSig = 'sha256=deadbeef';
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Timestamp': ts,
        'X-Signature': badSig,
        'X-Probe': 'true'
      },
      body
    });
    if (res.status !== 401 && res.status !== 403) {
      status = 'fail';
      details = { hint: 'expected_401_403', got: res.status };
    } else {
      details = { hint: 'invalid_sig_rejected', got: res.status };
    }
    evidence = { hash: `sha256:${await crypto.subtle.digest('SHA-256', new TextEncoder().encode(body)).then(b=>Array.from(new Uint8Array(b)).map(x=>x.toString(16).padStart(2,'0')).join(''))}` };
  }
} catch (e) {
  status = 'fail';
  details = { hint: String(e?.message || e) };
} finally {
  const latency_ms = Date.now() - start;
  printProbe({ probe: 'pos_hmac', status, tenant: process.env.PROBE_TENANT || 'global', latency_ms, details, evidence });
  process.exit(exitFor(status));
}
