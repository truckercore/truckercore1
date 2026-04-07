// security/redaction-middleware.ts
// Express middleware helper to attach a redacting logger and helpers to sanitize structured logs.
import { Request, Response, NextFunction } from 'express';

const REDACTION = '****REDACTED****';
const SENSITIVE_KEYS = [
  'x-api-key', 'authorization', 'api_key', 'apikey', 'api-key', 'key', 'secret', 'token', 'password', 'bearer'
];

// Hex-like tokens 32–64 chars, JWTs, and common env-like assignments
const SENSITIVE_VALUE_REGEX = new RegExp(
  [
    /\b[a-f0-9]{32,64}\b/.source, // hex keys
    /\b[A-Za-z0-9-_]{20,}\.[A-Za-z0-9-_]{10,}\.[A-Za-z0-9-_]{10,}\b/.source, // JWT-ish
    /(api[_-]?key|secret|password)\s*=\s*[^\s&]+/i.source // inline "apiKey=..."
  ].join('|'),
  'g'
);

export function redactObject(obj: any): any {
  if (obj == null || typeof obj !== 'object') return obj;
  const out: any = Array.isArray(obj) ? [] : {};
  for (const k of Object.keys(obj)) {
    const v = (obj as any)[k];
    if (SENSITIVE_KEYS.includes(k.toLowerCase())) {
      out[k] = REDACTION;
    } else if (typeof v === 'string') {
      out[k] = v.replace(SENSITIVE_VALUE_REGEX, (m) =>
        m.includes('=') ? m.replace(/=.*/, `=${REDACTION}`) : REDACTION
      );
    } else if (v && typeof v === 'object') {
      out[k] = redactObject(v);
    } else {
      out[k] = v;
    }
  }
  return out;
}

// Express middleware that attaches a redacting logger to req.log
export function withRedactedLogger(logger: { info: Function; warn: Function; error: Function }) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const base = {
      method: req.method,
      path: req.path,
      headers: redactObject(req.headers),
      query: redactObject(req.query),
      ...(req.method !== 'GET' ? { body: redactObject((req as any).body) } : {})
    } as Record<string, unknown>;

    const wrap = (level: 'info' | 'warn' | 'error') =>
      (msg: string, meta?: Record<string, any>) =>
        (logger as any)[level](msg, { ...base, ...(meta ? redactObject(meta) : {}) });

    (req as any).log = {
      info: wrap('info'),
      warn: wrap('warn'),
      error: wrap('error')
    };

    next();
  };
}

export const Redaction = { REDACTION, SENSITIVE_KEYS, SENSITIVE_VALUE_REGEX };
