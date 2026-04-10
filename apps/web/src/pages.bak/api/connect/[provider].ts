// apps/web/src/pages/api/connect/[provider].ts
import type { NextApiRequest, NextApiResponse } from "next";
import { Providers } from "../../../../integrations";
import { z } from "zod";
import { kvSetNX } from "../../lib/kv";
import { issueState } from "../../../lib/oauth/state";
import crypto from "crypto";

const Q = z.object({
  provider: z.string(),
  orgId: z.string().uuid(),
  redirectUri: z.string().url().optional(),
});

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const parsed = Q.safeParse({ ...req.query, provider: req.query.provider });
  if (!parsed.success) return res.status(400).json(parsed.error.format());

  const { provider, orgId, redirectUri } = parsed.data;
  const p = Providers[provider];
  if (!p) return res.status(404).send("Unknown provider");

  // Anti-replay state (existing nonce KV) + PKCE state
  const nonce = Math.random().toString(36).slice(2);
  const stateObj = { orgId, nonce };
  const state = Buffer.from(JSON.stringify(stateObj)).toString("base64url");

  const ok = await kvSetNX(`oauth:${provider}:${nonce}`, "1", 600);
  if (!ok) return res.status(409).send("State collision");

  // PKCE code_verifier + httpOnly cookie
  const { codeVerifier } = issueState(orgId);
  res.setHeader(
    "Set-Cookie",
    `pkce_${provider}=${codeVerifier}; Path=/; HttpOnly; SameSite=Lax; Max-Age=600`
  );

  // Compute S256 code_challenge and append to auth URL
  const challenge = crypto
    .createHash("sha256")
    .update(codeVerifier)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const cb = redirectUri || `${process.env.NEXT_PUBLIC_BASE_URL}/api/oauth/callback/${provider}`;
  const urlStr = p.authUrl({ state, redirectUri: cb });
  const url = new URL(urlStr);
  url.searchParams.set("code_challenge", challenge);
  url.searchParams.set("code_challenge_method", "S256");

  res.redirect(url.toString());
}
