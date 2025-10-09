type Fields = Record<string, unknown>;
const ALLOW = new Set(["event", "status", "org_id", "count", "duration_ms"]);
const MASK = "[REDACTED]";

export function logJSON(level: "info" | "warn" | "error", fields: Fields) {
  const clean: Fields = {};
  for (const [k, v] of Object.entries(fields)) {
    clean[k] = ALLOW.has(k) ? v : MASK;
  }
  console.log(JSON.stringify({ level, ...clean }));
}
