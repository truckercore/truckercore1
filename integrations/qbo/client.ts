// integrations/qbo/client.ts
import type { OAuthProvider, ExchangeInput, TokenResult } from "../core/types";
import { verifyHmacSHA256 } from "../core/webhook";

export const QBOProvider: OAuthProvider = {
  key: "qbo",
  authUrl: ({ state, redirectUri }) =>
    `https://appcenter.intuit.com/connect/oauth2?response_type=code&client_id=${encodeURIComponent(process.env.QBO_CLIENT_ID || "todo")}&redirect_uri=${encodeURIComponent(redirectUri)}&scope=com.intuit.quickbooks.accounting&state=${encodeURIComponent(state)}`,

  async exchange(_input: ExchangeInput): Promise<TokenResult> {
    if (!process.env.QBO_CLIENT_ID || !process.env.QBO_CLIENT_SECRET) {
      return { externalAccountId: "pending", meta: { mock: true } };
    }
    return {
      accessToken: "qbo_access_stub",
      refreshToken: "qbo_refresh_stub",
      externalAccountId: "realm_stub",
    };
  },

  async verifyWebhook(body, signature) {
    const secret = process.env.QBO_WEBHOOK_VERIFIER || "";
    if (!secret) return false;
    return verifyHmacSHA256(body, signature, secret);
  },

  async etl(kind, _args) {
    return { ok: true, log: `qbo etl executed: ${kind}` };
  },
};
