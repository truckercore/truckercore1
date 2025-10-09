// apps/web/src/pages/api/oauth/samsara/callback.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { oauthTokenExchange } from "../../../../lib/integrations/sdk";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    const { code, state } = req.query;
    if (!code || typeof code !== "string") return res.status(400).send("Missing code");

    const redirectUri = `${process.env.NEXT_PUBLIC_BASE_URL}/api/oauth/samsara/callback`;
    const token = await oauthTokenExchange({
      provider: "samsara",
      tokenUrl: "https://api.samsara.com/oauth2/token",
      code,
      redirectUri,
      clientId: process.env.SAMSARA_CLIENT_ID as string,
      clientSecret: process.env.SAMSARA_CLIENT_SECRET as string,
    });

    const body = {
      org_id: state, // state should be orgId
      provider: "samsara",
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_in ? new Date(Date.now() + token.expires_in * 1000).toISOString() : null,
      scope: token.scope,
      connection_status: "active",
    } as any;

    const r = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/integrations`, {
      method: "POST",
      headers: {
        apikey: process.env.SUPABASE_SERVICE_ROLE_KEY as string,
        Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates",
      },
      body: JSON.stringify(body),
    });
    if (!r.ok) return res.status(500).send(await r.text());

    return res.redirect("/dashboard/integrations?connected=samsara");
  } catch (e: any) {
    return res.status(500).send(String(e?.message || e));
  }
}
