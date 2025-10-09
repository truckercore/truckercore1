import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async (req) => {
  try {
    // Accept multipart or JSON; parse and classify (204/214/210)
    const contentType = req.headers.get('content-type') ?? '';
    // TODO: parse EDI document → extract envelope → store to edi_messages with direction=in/out & type=204|214|210
    // Keep this function idempotent via hash fingerprint.
    return new Response(JSON.stringify({ accepted: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
