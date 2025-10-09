export function requireRationale(resp: any) {
  if (!resp || typeof resp !== "object" || !('rationale' in resp)) {
    return { ok: false, error: "missing_rationale" } as const;
  }
  const r: any = (resp as any).rationale;
  const keys = ["features", "model"];
  for (const k of keys) {
    if (!(k in r)) return { ok: false, error: `missing_${k}` } as const;
  }
  return { ok: true } as const;
}
