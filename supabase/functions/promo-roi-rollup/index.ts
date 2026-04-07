// supabase/functions/promo-roi-rollup/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export const handler = async () => {
  // Placeholder for MV refresh or cache warm (extend as needed)
  return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { "Content-Type": "application/json" } });
};

Deno.serve(handler);
