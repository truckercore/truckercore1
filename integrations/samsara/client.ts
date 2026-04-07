// integrations/samsara/client.ts
import type { OAuthProvider, ExchangeInput, TokenResult } from "../core/types";
import { verifyHmacSHA256 } from "../core/webhook";

export const SamsaraProvider: OAuthProvider = {
  key: "samsara",
  authUrl: ({ state, redirectUri }) =>
    `https://cloud.samsara.com/o/oauth2/auth?response_type=code&client_id=${encodeURIComponent(process.env.SAMSARA_CLIENT_ID || "todo")}&redirect_uri=${encodeURIComponent(redirectUri)}&scope=read&state=${encodeURIComponent(state)}`,

  async exchange(_input: ExchangeInput): Promise<TokenResult> {
    if (!process.env.SAMSARA_CLIENT_ID || !process.env.SAMSARA_CLIENT_SECRET) {
      return { externalAccountId: "pending", meta: { mock: true } };
    }
    // Placeholder token result; wire real exchange later.
    return {
      accessToken: "samsara_access_stub",
      refreshToken: "samsara_refresh_stub",
      expiresAt: new Date(Date.now() + 3600e3).toISOString(),
      externalAccountId: "org_stub",
    };
  },

  async verifyWebhook(body, signature) {
    const secret = process.env.SAMSARA_WEBHOOK_SECRET || "";
    if (!secret) return false;
    return verifyHmacSHA256(body, signature, secret);
  },

  async etl(kind, _args) {
    return { ok: true, log: `samsara etl executed: ${kind}` };
  },
};
