// deno-fns/quotes_download.ts
// Endpoint: /api/quotes/:quoteId/download?org_id=...&user_id=...
// Renders a placeholder PDF (bytes) for a Quote and logs to legal_download_audit.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

async function fetchQuote(orgId: string, quoteId: string) {
  const { data, error } = await db.from('quotes').select('*').eq('id', quoteId).eq('org_id', orgId).maybeSingle();
  if (error || !data) return null;
  return data as any;
}

// Replace with a real PDF engine later
async function renderQuotePdf(quote: any) {
  const body = `Quote ${quote.id}\n` + JSON.stringify(quote, null, 2);
  const bytes = new TextEncoder().encode(body);
  return { bytes, filename: `quote_${quote.id}.pdf`, contentType: 'application/pdf' };
}

Deno.serve(async (req) => {
  try {
    const u = new URL(req.url);
    const parts = u.pathname.split('/').filter(Boolean); // ['api','quotes',':quoteId','download']
    const quoteId = parts.at(2);
    const orgId = u.searchParams.get('org_id');
    const userId = u.searchParams.get('user_id');
    if (!quoteId || !orgId || !userId) return new Response('Bad Request', { status: 400 });

    const quote = await fetchQuote(orgId, quoteId);
    if (!quote) return new Response('Not found', { status: 404 });

    const pdf = await renderQuotePdf(quote);

    // Audit log (service-role insert)
    try {
      await db.from('legal_download_audit').insert({
        org_id: orgId,
        user_id: userId,
        doc_type: 'quote',
        doc_id: quoteId,
        meta: { filename: pdf.filename }
      });
    } catch (_e) {
      // best-effort only
    }

    return new Response(pdf.bytes, {
      headers: {
        'content-type': pdf.contentType,
        'content-disposition': `attachment; filename="${pdf.filename}"`
      }
    });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 500 });
  }
});
