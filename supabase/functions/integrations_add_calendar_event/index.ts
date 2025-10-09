// Path: supabase/functions/integrations_add_calendar_event/index.ts
// Invoke with: POST /functions/v1/integrations_add_calendar_event
// Headers: { "X-Signature": sha256(INTEGRATIONS_SIGNING_SECRET + '.' + rawBody) }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

type CalReq = {
  org_id: string;
  title: string;
  starts_at: string; // ISO
  ends_at: string;   // ISO
  location?: string;
  notes?: string;
  provider?: 'google'|'outlook'|'ics';
};

function icsText(ev: CalReq) {
  const dt = (s: string) => s.replace(/[-:]/g,'').replace('.000Z','Z');
  return `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:${ev.title}
DTSTART:${dt(ev.starts_at)}
DTEND:${dt(ev.ends_at)}
LOCATION:${ev.location ?? ''}
DESCRIPTION:${ev.notes ?? ''}
END:VEVENT
END:VCALENDAR`;
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  const raw = await req.text();
  try {
    const secret = Deno.env.get('INTEGRATIONS_SIGNING_SECRET') ?? '';
    if (!await hmacValid(secret, raw, req.headers.get('x-signature'))) {
      return new Response('invalid signature', { status: 401 });
    }
    const body: CalReq = JSON.parse(raw);
    if (!body?.org_id || !body?.title || !body?.starts_at || !body?.ends_at) {
      return new Response('bad_request', { status: 400 });
    }

    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    await supa.from('integration_events').insert({
      org_id: body.org_id,
      integration_id: null,
      provider: body.provider ?? 'ics',
      event_type: 'calendar.create',
      payload: body,
      status: 'ok'
    });

    const ics = icsText(body);
    return new Response(JSON.stringify({ ok:true, ics }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok:false, error:String(e) }), { status: 500 });
  }
});
