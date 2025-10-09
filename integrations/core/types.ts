// integrations/core/types.ts
export type ExchangeInput = { code: string; redirectUri: string; orgId: string; codeVerifier?: string };

export type TokenResult = {
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: string;
  externalAccountId?: string;
  scope?: string;
  meta?: Record<string, unknown>;
};

export interface OAuthProvider {
  key: "samsara" | "qbo" | string;
  authUrl(params: { state: string; redirectUri: string }): string;
  exchange(input: ExchangeInput): Promise<TokenResult>;
  verifyWebhook(body: string, signature: string): Promise<boolean>;
  etl(kind: string, args: any): Promise<{ ok: boolean; log?: string }>;
}
