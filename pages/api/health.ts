import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  // Basic health response with minimal info to avoid leaking env secrets
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).json({
    status: 'ok',
    service: 'truckercore-web',
    time: new Date().toISOString(),
    version: process.env.VERCEL_GIT_COMMIT_SHA || process.env.COMMIT_SHA || 'unknown',
  });
}
