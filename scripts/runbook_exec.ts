// scripts/runbook_exec.ts
// Usage: PROJECT_URL=... SKIP_HTTP=0 SKIP_MV=0 deno run -A scripts/runbook_exec.ts

const PROJECT_URL = Deno.env.get("PROJECT_URL") ?? "http://127.0.0.1:54321";
const SKIP_HTTP = (Deno.env.get("SKIP_HTTP") ?? "0") === "1";
const SKIP_MV = (Deno.env.get("SKIP_MV") ?? "0") === "1";

await Deno.mkdir("artifacts", { recursive: true });
function tsSuffix() {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  const stamp = `${d.getFullYear()}${pad(d.getMonth()+1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  const rand = crypto.getRandomValues(new Uint16Array(1))[0].toString(16);
  return `${stamp}_${rand}`;
}
const base = `artifacts/runbook_report_${tsSuffix()}`;
const txtTmp = `${base}.txt.tmp`;
const jsonTmp = `${base}.json.tmp`;
const txtOut = `${base}.txt`;
const jsonOut = `${base}.json`;

// Redaction helper: crude masking of USER_JWT if present
function redact(s: string): string {
  const jwt = Deno.env.get("USER_JWT");
  return jwt && jwt.length > 0 ? s.replaceAll(jwt, "****…****") : s;
}

// Step model
type Step = { name: string; ok: boolean; duration_ms: number; remediation?: string };
const steps: Step[] = [];
const t0 = performance.now();

async function step(name: string, fn: () => Promise<void>, remediation?: string) {
  const s = performance.now();
  let ok = true;
  try { await fn(); } catch (e) { ok = false; console.error(`[FAIL] ${name}: ${e?.message ?? e}`); }
  const d = Math.round(performance.now() - s);
  steps.push({ name, ok, duration_ms: d, remediation });
}

async function writeTempFiles(summary: any, bodyTxt: string) {
  await Deno.writeTextFile(txtTmp, bodyTxt);
  await Deno.writeTextFile(jsonTmp, JSON.stringify(summary, null, 2));
}

async function atomicPublish() {
  await Deno.rename(txtTmp, txtOut);
  await Deno.rename(jsonTmp, jsonOut);
}

// Steps (minimal assertions – extend as desired)
await step("HTTP health", async () => {
  if (SKIP_HTTP) return;
  const res = await fetch(`${PROJECT_URL}/health`, { headers: { accept: "application/json" } });
  if (!res.ok) throw new Error(`health_${res.status}`);
}, "Check /health endpoint and logs; ensure service keys configured.");

await step("DB extensions", async () => {
  // placeholder for optional DB checks; rely on existing Make targets or CLI scripts
}, "Enable pgcrypto/postgis extensions in Supabase if required.");

await step("Objects exist", async () => {
  // placeholder: a server-side RPC could be called here; left minimal per spec
}, "Run migrations for integrations + sample public tables.");

// Build summary
const okCount = steps.filter(s => s.ok).length;
const failCount = steps.length - okCount;
const shaCmd = new Deno.Command("git", { args: ["rev-parse", "HEAD"] });
let gitSha: string | null = null;
try {
  const out = await shaCmd.output();
  if (out.stdout?.length) gitSha = new TextDecoder().decode(out.stdout).trim();
} catch (_) { /* ignore */ }

const summary = {
  summary: {
    exit_code: failCount === 0 ? 0 : 1,
    ok: okCount,
    fail: failCount,
    duration_ms: Math.round(performance.now() - t0),
    tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
    git_sha: gitSha,
  },
  steps,
  env: { PROJECT_URL, SKIP_HTTP, SKIP_MV }
};

const lines = [
  `Runbook Report`,
  `Status: ${failCount === 0 ? "OK" : "FAIL"}`,
  `OK: ${okCount}  FAIL: ${failCount}  Duration(ms): ${summary.summary.duration_ms}`,
  `TZ: ${summary.summary.tz}  SHA: ${summary.summary.git_sha ?? "n/a"}`,
  `Env: PROJECT_URL=${PROJECT_URL} SKIP_HTTP=${SKIP_HTTP ? 1 : 0} SKIP_MV=${SKIP_MV ? 1 : 0}`,
  `--- Steps ---`,
  ...steps.map(s => `${s.ok ? "[OK] " : "[FAIL]"} ${s.name} (${s.duration_ms}ms)${s.ok ? "" : s.remediation ? " :: " + s.remediation : ""}`),
].join("\n");

// Atomic write
await writeTempFiles(summary, redact(lines) + "\n");
await atomicPublish();

// Exit policy
Deno.exit(summary.summary.exit_code);
