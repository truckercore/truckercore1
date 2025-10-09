import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (_req) => {
  // Stub: Implement your outbound push to accounting here (e.g., create/close invoices)
  return new Response(JSON.stringify({ ok: true, message: "Export stub" }), { headers: { "content-type": "application/json" } });
});
