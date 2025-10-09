// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  try {
    const form = await req.formData();
    const file = form.get('audio') as File | null;
    const locale = (form.get('locale') as string | null) ?? 'en';
    if (!file) return new Response(JSON.stringify({ error: 'missing audio' }), { status: 400 });

    const backend = Deno.env.get('ASR_BACKEND_URL');
    if (!backend) return new Response(JSON.stringify({ error: 'missing backend' }), { status: 500 });

    const upstream = await fetch(backend, {
      method: 'POST',
      headers: { 'X-Locale': locale },
      body: file.stream(),
    });

    if (!upstream.ok) {
      return new Response(JSON.stringify({ error: 'backend failed' }), { status: 502 });
    }
    const out = await upstream.json();
    return new Response(JSON.stringify({
      text: out.text ?? '',
      words: out.words ?? [],
      language: out.language ?? locale,
    }), { headers: { "Content-Type": "application/json" }});
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
