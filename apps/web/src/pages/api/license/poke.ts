import type { NextApiRequest, NextApiResponse } from 'next';
import { randomUUID } from 'crypto';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();
  const { orgId } = req.body || {};
  if (!orgId) return res.status(400).json({ ok: false, error: 'missing_org' });
  return res.status(200).json({ ok: true, nonce: randomUUID(), ts: Date.now() });
}
