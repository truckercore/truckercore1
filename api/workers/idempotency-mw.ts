// idempotency-mw.ts
import crypto from 'crypto';
import type { Request, Response, NextFunction } from 'express';
import { db } from './shared';

type IdemState = {
  key: string;
  orgId: string | undefined;
  endpoint: string;
  bodyHash: string;
};

declare global {
  // eslint-disable-next-line no-var
  var __augment_res_locals: undefined | ((res: Response) => void);
}

export async function withIdempotency(req: Request, res: Response, next: NextFunction) {
  const key = req.header('Idempotency-Key');
  if (!key || req.method === 'GET') return next();

  const orgId = (req.params as any).orgId || req.header('X-Org-Id');
  const endpoint = `${req.method} ${req.path}`;
  const bodyHash = hash(JSON.stringify(req.body || {}));

  const existing = await db.idempotency.find(key);
  if (existing) {
    if (existing.request_hash === bodyHash && existing.endpoint === endpoint && existing.org_id === orgId) {
      res.status(existing.response_code)
        .set('X-Idempotent-Replay', 'true')
        .send(existing.response_body);
      return;
    }
    res.status(409).send({ error: 'Idempotency key collision' });
    return;
  }

  // Attach state for later persistence
  (res.locals as any).__idem = { key, orgId, endpoint, bodyHash } as IdemState;
  next();
}

export async function persistIdempotentResult(res: Response, code: number, body: any) {
  const idem: IdemState | undefined = (res.locals as any).__idem;
  if (!idem) return;
  const expiresAt = new Date(Date.now() + 72 * 3600_000).toISOString();
  await db.idempotency.put({
    key: idem.key,
    org_id: idem.orgId,
    endpoint: idem.endpoint,
    request_hash: idem.bodyHash,
    response_code: code,
    response_body: body,
    expires_at: expiresAt,
  });
}

function hash(s: string) {
  return crypto.createHash('sha256').update(s).digest('hex');
}
