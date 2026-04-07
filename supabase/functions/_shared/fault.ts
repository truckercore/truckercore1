// supabase/functions/_shared/fault.ts
export async function maybeFail() {
  const mode = Deno.env.get('FAULT_MODE') || 'off'; // 'off'|'latency'|'error'
  if (mode === 'latency') {
    const ms = Number(Deno.env.get('FAULT_LATENCY_MS') || '1200');
    await new Promise((r) => setTimeout(r, ms));
  }
  if (mode === 'error') {
    throw new Error('Injected fault');
  }
}
