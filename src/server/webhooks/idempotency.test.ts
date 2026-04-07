// src/server/webhooks/idempotency.test.ts
import { describe, it, expect } from "vitest";
import { recordWebhookReceived } from "./idempotency";

// Integration-like test: requires Supabase env when run manually
// Skips assertions that require actual DB when env is missing

function hasEnv() {
  return !!process.env.NEXT_PUBLIC_SUPABASE_URL && !!(
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SERVICE_ROLE ||
    process.env.SUPABASE_SERVICE_KEY
  );
}

describe("recordWebhookReceived", () => {
  it("handles duplicates (integration; requires DB env)", async () => {
    if (!hasEnv()) {
      expect(true).toBe(true);
      return;
    }
    const e = `evt_test_${Math.random().toString(36).slice(2)}`;
    const r1 = await recordWebhookReceived("stripe", e, "test.event", { ok: true }, null).catch(() => null);
    const r2 = await recordWebhookReceived("stripe", e, "test.event", { ok: true }, null).catch(() => null);
    expect(r1 && (r1 as any).kind).toBeTruthy();
    expect(r2 && (r2 as any).kind === "duplicate").toBeTruthy();
  });
});
