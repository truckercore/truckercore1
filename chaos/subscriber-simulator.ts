// chaos/subscriber-simulator.ts
import express from 'express';

const app = express();
app.use(express.json());

let mode: 'ok' | 'slow' | '429' | '500' = 'ok';
let delayMs = 0;
let retryAfterSec = 60;

app.post('/set-mode', (req, res) => {
  mode = (req.query.mode as any) ?? 'ok';
  delayMs = Number(req.query.delayMs ?? 0);
  retryAfterSec = Number(req.query.retryAfter ?? 60);
  res.json({ mode, delayMs, retryAfterSec });
});

app.post('/webhooks/test', async (req, res) => {
  if (delayMs) await new Promise((r) => setTimeout(r, delayMs));
  if (mode === 'ok') return res.status(200).json({ ok: true });
  if (mode === 'slow') return res.status(200).json({ ok: true, slow: true });
  if (mode === '429') {
    res.setHeader('Retry-After', String(retryAfterSec));
    return res.status(429).json({ error: 'rate_limited' });
  }
  if (mode === '500') return res.status(502).json({ error: 'upstream' });
  return res.status(200).json({ ok: true });
});

const port = process.env.PORT || 8089;
app.listen(port, () => console.log(`Subscriber simulator on :${port}, POST /set-mode?mode=ok|slow|429|500`));
