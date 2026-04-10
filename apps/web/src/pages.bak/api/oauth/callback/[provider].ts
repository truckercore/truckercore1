// apps/web/src/pages/api/oauth/callback/[provider].ts
import type { NextApiRequest, NextApiResponse } from "next";
import { Providers } from "../../../../../integrations";
import { upsertConnection, enqueueETL } from "../../../../../integrations/core/storage";
import { z } from "zod";
import { kvTake } from "../../../lib/kv";

const Q = z.object({
  provider: z.string(),
  code: z.string(),
  state: z.string(),
});

function parseCookies(header?: string): Record<string, string> {
  const out: Record<string, string> = {};
  if (!header) return out;
  header.split(/;\s*/).forEach((p) => {
    const idx = p.indexOf("=");
    if (idx > 0) {
      const k = decodeURIComponent(p.slice(0, idx));
      const v = decodeURIComponent(p.slice(idx + 1));
      out[k] = v;
    }
  });
  return out;
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const parsed = Q.safeParse({ ...req.query, provider: req.query.provider });
  if (!parsed.success) return res.status(400).json(parsed.error.format());

  const { provider, code, state } = parsed.data;
  const p = Providers[provider];
  if (!p) return res.status(404).send("Unknown provider");

  let decoded: { orgId: string; nonce: string };
  try {
    decoded = JSON.parse(Buffer.from(state, "base64url").toString("utf8"));
  } catch {
    return res.status(400).send("Bad state");
  }

  const nonceOk = await kvTake(`oauth:${provider}:${decoded.nonce}`);
  if (!nonceOk) return res.status(400).send("State expired or replayed");

  // Read PKCE verifier cookie (if set) and pass along to provider exchange
  const cookies = parseCookies(req.headers.cookie);
  const codeVerifier = cookies[`pkce_${provider}`];

  const redirectUri = `${process.env.NEXT_PUBLIC_BASE_URL}/api/oauth/callback/${provider}`;
  const token = await p.exchange({ code, redirectUri, orgId: decoded.orgId, codeVerifier } as any);
  await upsertConnection(decoded.orgId, provider, token);
  await enqueueETL(provider, "initial_sync", { orgId: decoded.orgId });

  // Clear PKCE cookie
  res.setHeader("Set-Cookie", `pkce_${provider}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`);

  res.status(200).send(`Connected ${provider} for org ${decoded.orgId} (${token.meta?.mock ? "mock" : "live"})`);
}
