// api/lib/logging.ts
// Structured logging helpers that attach org_id and correlation_id to every log/notification.

function redactValue(key: string, value: any) {
  const k = key.toLowerCase();
  const sensitiveKeys = [
    'authorization','auth','password','passwd','secret','token','apikey','api_key','access_token','refresh_token','client_secret','private_key','ssn','creditcard','card','cvv','pin'
  ];
  if (sensitiveKeys.some(s => k.includes(s))) return '[REDACTED]';
  if (typeof value === 'string') {
    // redact common bearer tokens and emails in free-form strings
    let v = value.replace(/(bearer\s+)[a-z0-9._\-]+/gi, '$1[REDACTED]');
    // redact JWT-like tokens (three base64url segments)
    v = v.replace(/([A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+)/g, '[REDACTED_JWT]');
    // redact long digit sequences (16+), unless key seems safe (ids)
    const safeNumericKeys = ['correlation_id','trace_id','request_id','org_id','user_id'];
    if (!safeNumericKeys.some(s => k.includes(s))) {
      v = v.replace(/\b\d{16,}\b/g, '[REDACTED_NUM]');
    }
    v = v.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[REDACTED_EMAIL]');
    return v;
  }
  return value;
}

function sanitize(obj: any, depth = 0): any {
  if (depth > 4) return '[DEPTH_LIMIT]';
  if (obj == null) return obj;
  if (Array.isArray(obj)) return obj.map(v => sanitize(v, depth + 1));
  if (typeof obj === 'object') {
    const out: Record<string, any> = {};
    for (const [k, v] of Object.entries(obj)) {
      if (v && typeof v === 'object') {
        out[k] = sanitize(v, depth + 1);
      } else {
        out[k] = redactValue(k, v);
      }
    }
    return out;
  }
  return obj;
}

export function logEvent(level: 'info'|'warn'|'error', msg: string, meta: Record<string, any> = {}) {
  const cid = meta.correlation_id ?? (typeof (globalThis as any).crypto?.randomUUID === 'function' ? (globalThis as any).crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`)
  const safeMeta = sanitize(meta);
  const out = {
    ts: new Date().toISOString(),
    level,
    message: msg,
    org_id: safeMeta.org_id ?? 'unknown',
    correlation_id: cid,
    ...safeMeta,
  }
  try {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify(out))
  } catch {
    // ignore
  }
  return cid
}

export async function notify(severity: 'WARN'|'P1'|'P0', title: string, meta: Record<string, any>) {
  const cid = meta.correlation_id ?? (typeof (globalThis as any).crypto?.randomUUID === 'function' ? (globalThis as any).crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`)
  const payload = { title, severity, org_id: meta.org_id, correlation_id: cid, meta: sanitize(meta) }
  try {
    // send to Slack/Teams/Email if available in global notifier; otherwise noop
    const notifier = (globalThis as any).notifier
    if (notifier?.send) {
      await notifier.send(payload)
    }
  } catch {
    // ignore
  }
  // emit metric if configured
  try { (globalThis as any).metrics?.inc('alerts_sent_total', { severity, org_id: String(meta.org_id || 'unknown') }) } catch {}
  return cid
}
