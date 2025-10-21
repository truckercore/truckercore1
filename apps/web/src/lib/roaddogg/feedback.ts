// Minimal client helper to send suggestion feedback to backend.
// Assumes an API route exists to handle persistence with proper auth/RLS.
export async function setSuggestionFeedback(suggestionId: number, accepted: boolean) {
  try {
    const res = await fetch("/api/roaddogg/feedback", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      cache: "no-store",
      body: JSON.stringify({ id: suggestionId, accepted }),
    });
    if (!res.ok) throw new Error(await res.text());
    return { ok: true as const };
  } catch (e: any) {
    console.error("feedback error", e);
    return { ok: false as const, error: String(e?.message || e) };
  }
}
