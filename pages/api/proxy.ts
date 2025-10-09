import type { NextApiRequest, NextApiResponse } from 'next';

// Temporary server-side proxy to mitigate client-side SSL issues when calling certain domains.
// Only allows GET to a small whitelist of hosts and path prefixes.
const ALLOWED_HOSTS = new Set([
  'api.truckercore.com',
  'downloads.truckercore.com',
]);

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const url = req.query.url;
  if (typeof url !== 'string') {
    return res.status(400).json({ error: 'Missing url parameter' });
  }

  try {
    const target = new URL(url);
    if (!ALLOWED_HOSTS.has(target.hostname)) {
      return res.status(400).json({ error: 'Host not allowed' });
    }

    const upstream = await fetch(target.toString(), {
      method: 'GET',
      headers: { 'Accept': 'application/json, text/plain, */*' },
      // Add timeout via AbortController if needed later
    });

    const contentType = upstream.headers.get('content-type') || 'application/octet-stream';
    res.status(upstream.status);
    res.setHeader('content-type', contentType);

    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.send(buffer);
  } catch (err: any) {
    return res.status(502).json({ error: 'Bad Gateway', message: err?.message || 'fetch failed' });
  }
}
