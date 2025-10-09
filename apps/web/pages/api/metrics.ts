// apps/web/pages/api/metrics.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { Registry } from "prom-client";

// Reuse global registry created by CSV export handler via Node module cache
const registry: Registry = (global as any).promRegistry || new Registry();
(global as any).promRegistry = registry;

export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  res.setHeader("Content-Type", registry.contentType);
  res.status(200).send(await registry.metrics());
}
