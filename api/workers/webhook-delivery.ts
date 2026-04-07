// webhook-delivery.ts
import crypto from 'crypto';
import { db, http } from './shared';

const HEADER_SIG = 'X-TruckerCore-Signature';
const HEADER_TS = 'X-TruckerCore-Timestamp';
const HEADER_IDEMP = 'Idempotency-Key';
const HEADER_ATTEMPT = 'X-TruckerCore-Attempt';

type OutboxEvent = {
  id: string;
  org_id: string;
  topic: string;
  aggregate_type: string;
  aggregate_id: string;
  payload: any;
  created_at: string;
  attempts?: number;
  key?: string | null;
};

type WebhookSub = { id: string; org_id: string; endpoint_url: string; secret: string };

export async function deliverPending(now = new Date()) {
  const batch: OutboxEvent[] = await db.outbox.claimPending(now, 100);
  for (const evt of batch) {
    const subs: WebhookSub[] = await db.webhooks.activeFor(evt.org_id, evt.topic);
    for (const sub of subs) {
      const ts = Math.floor(Date.now() / 1000).toString();
      const body = JSON.stringify({
        id: evt.id,
        topic: evt.topic,
        aggregate_type: evt.aggregate_type,
        aggregate_id: evt.aggregate_id,
        payload: evt.payload,
        created_at: evt.created_at
      });
      const sig = sign(sub.secret, ts, body);
      try {
        const attempt = (evt.attempts ?? 0) + 1;
        await http.post(sub.endpoint_url, body, {
          headers: {
            'Content-Type': 'application/json',
            [HEADER_TS]: ts,
            [HEADER_SIG]: sig,
            [HEADER_IDEMP]: evt.key ?? `${evt.topic}:${evt.id}`,
            [HEADER_ATTEMPT]: String(attempt)
          },
          timeout: 10_000
        });
      } catch (err) {
        await db.outbox.bumpRetry(evt.id, backoffSeconds(evt.attempts ?? 0));
        continue;
      }
    }
    await db.outbox.markDelivered(evt.id);
  }
}

function sign(secret: string, ts: string, body: string) {
  return 'sha256=' + crypto.createHmac('sha256', secret).update(`${ts}.${body}`).digest('hex');
}

function backoffSeconds(attempts: number) {
  const base = Math.min(300, Math.pow(2, Math.min(attempts, 8)));
  return Math.floor(base + Math.random() * 10);
}
