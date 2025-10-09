import crypto from 'node:crypto';

export function hmacHex(secret, s) {
  return crypto.createHmac('sha256', secret).update(s).digest('hex');
}

export function nowIso() {
  return new Date().toISOString();
}

export async function postJson(url, body, headers = {}) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body ?? {}),
  });
  const text = await res.text();
  return { res, text, json: safeJson(text) };
}

export function safeJson(text) {
  try { return JSON.parse(text); } catch { return null; }
}

export function requireEnv(keys) {
  const missing = keys.filter(k => !process.env[k] || String(process.env[k]).length === 0);
  if (missing.length) {
    console.log(`[skip] missing env: ${missing.join(', ')}`);
    process.exit(0);
  }
}
