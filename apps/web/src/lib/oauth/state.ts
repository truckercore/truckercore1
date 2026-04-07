import crypto from "crypto";

// In-memory state store (dev/local). Replace with Redis or durable KV in production.
type Rec = { orgId: string; exp: number; codeVerifier?: string };
const mem = new Map<string, Rec>();

export function issueState(orgId: string) {
  const state = crypto.randomBytes(16).toString("hex");
  const codeVerifier = crypto.randomBytes(32).toString("base64url");
  mem.set(state, { orgId, exp: Date.now() + 10 * 60_000, codeVerifier });
  return { state, codeVerifier };
}

export function consumeState(state: string) {
  const rec = mem.get(state);
  if (!rec || rec.exp < Date.now()) return null;
  mem.delete(state);
  return rec;
}
