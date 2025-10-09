import { describe, it, expect } from "vitest";
import { recordWebhookReceived } from "./idempotency";

describe("recordWebhookReceived", () => {
  it("handles duplicates (integration; requires DB env)", async () => {
    const e = `evt_test_${Math.random().toString(36).slice(2)}`;
    const r1 = await recordWebhookReceived("stripe", e, "test.event", { ok: true }, null).catch(() => null);
    const r2 = await recordWebhookReceived("stripe", e, "test.event", { ok: true }, null).catch(() => null);
    expect(r1 && (r1 as any).kind).toBeTruthy();
    expect(r2 && (r2 as any).kind === "duplicate").toBeTruthy();
  });
});
