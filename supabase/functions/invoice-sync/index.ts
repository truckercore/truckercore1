// supabase/functions/invoice-sync/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async () => {
  // Placeholder: select invoices_ext in 'ready' state, push to QBO, update qbo_txn_id/status.
  // Implement with service key and QBO creds via secrets manager or env.
  return new Response("ok");
});
