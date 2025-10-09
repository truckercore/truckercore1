export async function audit(supabase: any, fn: string, actor: string | null, payload: unknown, ok: boolean, meta?: { ip?: string; ua?: string; error?: string }) {
  const sha = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(payload)));
  const hex = Array.from(new Uint8Array(sha)).map(b=>b.toString(16).padStart(2,"0")).join("");
  await supabase.from("function_audit_log").insert({
    fn, actor, payload_sha256: hex, success: ok, error: meta?.error ?? null,
    actor_ip: meta?.ip ?? null, user_agent: meta?.ua ?? null
  });
}
