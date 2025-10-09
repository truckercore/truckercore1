import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createHmac } from "https://deno.land/std@0.224.0/crypto/mod.ts";

const ADMIN_HMAC = Deno.env.get("ADMIN_TASK_HMAC_SECRET")!; // scoped to this fn

function verify(req: Request, body: string) {
  const ts = req.headers.get("x-timestamp") ?? "";
  const sig = req.headers.get("x-signature") ?? "";
  const mac = createHmac("sha256", ADMIN_HMAC);
  mac.update(`${ts}|${new URL(req.url).pathname}|${body}`);
  const digest = mac.toString();
  if (sig !== digest) throw new Error("invalid signature");
}

serve(async (req) => {
  const body = await req.text();
  verify(req, body);
  // ...perform admin task...
  return new Response("ok");
});
