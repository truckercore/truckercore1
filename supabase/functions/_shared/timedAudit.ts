// supabase/functions/_shared/timedAudit.ts
export async function timed<T>(
  supabase: any,
  fnName: string,
  actor: string | null,
  payload: unknown,
  run: () => Promise<T>,
  meta?: { ip?: string; ua?: string }
) {
  const start = performance.now();
  try {
    const result = await run();
    const dur = Math.round(performance.now() - start);
    await supabase.from("function_audit_log").insert({
      fn: fnName,
      actor,
      payload_sha256: await sha(payload),
      success: true,
      duration_ms: dur,
      actor_ip: meta?.ip ?? null,
      user_agent: meta?.ua ?? null
    });
    return result;
  } catch (err: any) {
    const dur = Math.round(performance.now() - start);
    await supabase.from("function_audit_log").insert({
      fn: fnName,
      actor,
      payload_sha256: await sha(payload),
      success: false,
      error: String(err?.message ?? err),
      duration_ms: dur,
      actor_ip: meta?.ip ?? null,
      user_agent: meta?.ua ?? null
    });
    throw err;
  }
}

async function sha(payload: unknown) {
  const b = new TextEncoder().encode(JSON.stringify(payload));
  const d = await crypto.subtle.digest("SHA-256", b);
  return Array.from(new Uint8Array(d))
    .map(x => x.toString(16).padStart(2, "0"))
    .join("");
}
