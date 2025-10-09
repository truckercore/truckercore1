// integrations/core/storage.ts
import { createClient } from "@supabase/supabase-js";
import type { TokenResult } from "./types";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const service = process.env.SUPABASE_SERVICE_ROLE_KEY!;

export const admin = createClient(url, service);

export async function upsertConnection(orgId: string, provider: string, token: TokenResult) {
  const { error } = await admin.from("integration_connections").upsert(
    {
      org_id: orgId,
      provider,
      access_token: token.accessToken ?? null,
      refresh_token: token.refreshToken ?? null,
      expires_at: token.expiresAt ?? null,
      external_account_id: token.externalAccountId ?? null,
      scope: token.scope ?? null,
      meta: token.meta ?? {},
      updated_at: new Date().toISOString(),
    },
    { onConflict: "org_id,provider" }
  );
  if (error) throw error;
}

export async function enqueueETL(provider: string, kind: string, args: any, connectionId?: string) {
  const { error } = await admin.from("etl_jobs").insert({
    provider,
    kind,
    args,
    connection_id: connectionId ?? null,
    status: "queued",
  });
  if (error) throw error;
}
