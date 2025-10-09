// Supabase Edge Function: env_health
// Returns a tiny JSON identifying the environment. Useful for verifying deploy targets.

Deno.serve(() => {
  const env = Deno.env.get('ENV_NAME') ?? 'unknown';
  const webUrl = Deno.env.get('WEB_URL') ?? null;
  return new Response(JSON.stringify({ env, web_url: webUrl }), {
    headers: { 'content-type': 'application/json' },
  });
});
