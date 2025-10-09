import express from 'express';
import { HEADER_SIG, HEADER_TS, HEADER_EVENT, HEADER_IDEMP, InMemoryReplayCache, verify, requireIdempotencyKey } from '../lib/webhook';

const app = express();
app.use(express.json({ type: '*/*' }));

// Replace with your secret store
const SECRET = process.env.WEBHOOK_SECRET || 'replace-me';

// Simple in-memory replay guard for demo purposes only.
const replay = new InMemoryReplayCache();

app.post('/webhook', (req, res) => {
  const ts = req.header(HEADER_TS) || '';
  const sig = req.header(HEADER_SIG) || '';
  const event = req.header(HEADER_EVENT) || '';

  const raw = JSON.stringify(req.body || {});
  const result = verify({
    secret: SECRET,
    headerSignature: sig,
    timestamp: ts,
    rawBody: raw,
    replayCache: replay,
  });
  if (!result.ok) return res.status(400).json({ ok: false, error: result.error });

  const idk = requireIdempotencyKey(req.headers as any);
  if (!idk.ok) return res.status(400).json({ ok: false, error: idk.error });

  // Idempotency handling example: look up idk.key in persistent storage and short-circuit if already processed
  // (Implement your storage here)
  console.log('[webhook] ok', { event });
  res.status(200).json({ ok: true });
});

if (require.main === module) {
  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`Webhook receiver listening on :${port}`));
}

export default app;
