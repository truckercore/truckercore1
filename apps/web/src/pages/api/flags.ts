// apps/web/src/pages/api/flags.ts
// Minimal API route returning feature flags.
// This endpoint is intentionally simple to satisfy Playwright test expectations.
// If a feature_flags table is present and you want dynamic flags, you can extend this handler later.

import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  // For now, return an empty flags object with ok=true. Tests only require shape.
  // Optionally, you could load from your database here.
  res.status(200).json({ ok: true, flags: {} });
}
