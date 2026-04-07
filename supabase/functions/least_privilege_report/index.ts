import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { Client } from "https://deno.land/x/postgres@v0.17.0/mod.ts";

const CONN = Deno.env.get("PG_CONN_STRING")!;
serve(async () => {
  const c = new Client(CONN);
  await c.connect();
  const q = `
    select n.nspname as schema,
           p.proname as fn,
           pg_get_userbyid(p.proowner) as owner,
           p.prosecdef as security_definer,
           pg_get_functiondef(p.oid) ilike '%set_config(''search_path''%' as pins_search_path
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname not in ('pg_catalog','information_schema');`;
  const r = await c.queryObject(q);
  await c.end();
  return new Response(JSON.stringify(r.rows), { headers: { "content-type": "application/json" } });
});
