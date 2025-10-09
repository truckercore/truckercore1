import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Entry = { id: string; model: string; sha256: string; size: number; updated_at: string; url: string };

serve(async () => {
  const entries: Entry[] = [
    { id:'whisper-tiny.en-q8', model:'Xenova/whisper-tiny.en', sha256:'', size: 75000000, updated_at: new Date().toISOString(), url: '' }
  ];
  return new Response(JSON.stringify({ entries }), { headers: { "Content-Type": "application/json" }});
});
