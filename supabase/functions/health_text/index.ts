import 'jsr:@supabase/functions-js/edge-runtime';

// Health ping that returns plain text per spec
(Deno as any).serve((_req: Request) => new Response('ok', { headers: { 'content-type': 'text/plain' } }));
