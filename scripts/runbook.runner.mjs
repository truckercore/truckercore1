// Portable Runbook Runner (Node 18+)
// Discovers step scripts (2..10) under scripts/runbook/, runs them in order,
// captures output, masks secrets, and writes artifacts/runbook_report_YYYYMMDD_HHMM(.json|.txt)

import { promises as fs } from "fs";
import { spawn } from "child_process";
import { fileURLToPath } from "url";
import { dirname, join, sep } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const RUNBOOK_DIR = join(ROOT, "scripts", "runbook");
const ARTIFACTS = join(ROOT, "artifacts");
const TZ = process.env.TZ || "America/New_York";

const ENV = {
  PROJECT_URL: process.env.PROJECT_URL || "",
  USER_JWT: process.env.USER_JWT || "",
  SKIP_HTTP: process.env.SKIP_HTTP || "0",
  SKIP_MV: process.env.SKIP_MV || "0",
  ALLOW_PARTIAL: process.env.ALLOW_PARTIAL || "0",
  RUNBOOK_STEP_TIMEOUT: Number(process.env.RUNBOOK_STEP_TIMEOUT || 300_000), // 5m
};

const SENSITIVE_ENV_VARS = [
  "USER_JWT",
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_SERVICE_ROLE",
  "SUPABASE_ANON_KEY",
  "AUTH_TOKEN",
];

function maskSecrets(text) {
  if (!text) return text;
  let masked = text;

  // Mask specific env var values
  for (const key of SENSITIVE_ENV_VARS) {
    const val = process.env[key];
    if (val && val.length >= 8) {
      const safe = val.slice(0, 2) + "****" + val.slice(-2);
      const re = new RegExp(val.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g");
      masked = masked.replace(re, safe);
    }
  }

  // Mask JWT-like strings (three base64url segments)
  masked = masked.replace(
    /\b[A-Za-z0-9\-_]{10,}\.[A-Za-z0-9\-_]{10,}\.[A-Za-z0-9\-_]{10,}\b/g,
    (m) => m.slice(0, 4) + "****" + m.slice(-4)
  );

  return masked;
}

function fmtNY(dt = new Date()) {
  // Build YYYYMMDD_HHMM in America/New_York without extra deps
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })
    .formatToParts(dt)
    .reduce((acc, p) => ((acc[p.type] = p.value), acc), {});
  return `${parts.year}${parts.month}${parts.day}_${parts.hour}${parts.minute}`;
}

async function gitSha() {
  return new Promise((resolve) => {
    const exe = process.platform === "win32" ? "git.exe" : "git";
    const p = spawn(exe, ["rev-parse", "--short", "HEAD"], { cwd: ROOT });
    let out = "";
    p.stdout.on("data", (d) => (out += d));
    p.on("close", () => resolve(out.trim() || "unknown"));
    p.on("error", () => resolve("unknown"));
  });
}

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

function pickScriptForStep(n, configSteps) {
  // Priority: config.json file mapping → otherwise autodiscover stepN.sh / stepN.ps1
  if (configSteps) {
    const c = configSteps.find((s) => String(s.id) === String(n));
    if (c) return join(RUNBOOK_DIR, c.file);
  }
  const sh = join(RUNBOOK_DIR, `step${n}.sh`);
  const ps = join(RUNBOOK_DIR, `step${n}.ps1`);
  return { sh, ps };
}

function detectTagsFromFilename(file) {
  const low = file.toLowerCase();
  const tags = [];
  if (low.includes("http")) tags.push("HTTP");
  if (low.includes("mv")) tags.push("MV");
  return tags;
}

async function loadConfig() {
  const cfgPath = join(RUNBOOK_DIR, "config.json");
  if (await pathExists(cfgPath)) {
    try {
      const raw = await fs.readFile(cfgPath, "utf8");
      return JSON.parse(raw);
    } catch {
      // ignore invalid config
    }
  }
  return null;
}

function runScript(file, { timeoutMs }) {
  return new Promise((resolve) => {
    const isWin = process.platform === "win32";
    let cmd, args;

    if (file.endsWith(".ps1")) {
      cmd = isWin ? "powershell.exe" : "pwsh";
      args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", file];
    } else {
      // .sh or anything else → run via bash
      cmd = "bash";
      args = ["-lc", `"${file.replace(/"/g, '\\"')}"`];
    }

    const child = spawn(cmd, args, {
      cwd: ROOT,
      shell: false,
      env: { ...process.env },
    });

    let stdout = "";
    let stderr = "";
    let killed = false;
    const to = setTimeout(() => {
      killed = true;
      child.kill("SIGKILL");
    }, timeoutMs);

    child.stdout.on("data", (d) => (stdout += d.toString()));
    child.stderr.on("data", (d) => (stderr += d.toString()));

    child.on("close", (code) => {
      clearTimeout(to);
      resolve({
        code: killed ? 124 : code ?? 1,
        stdout,
        stderr,
        cmd: `${cmd} ${args.join(" ")}`,
      });
    });

    child.on("error", (err) => {
      clearTimeout(to);
      resolve({ code: 1, stdout: "", stderr: String(err), cmd: `${cmd} ${args.join(" ")}` });
    });
  });
}

function trimBlock(s, { maxLines = 400, maxChars = 120_000 } = {}) {
  if (!s) return "";
  let out = s;
  if (out.length > maxChars) out = out.slice(out.length - maxChars);
  const lines = out.split(/\r?\n/);
  if (lines.length > maxLines) return ["…(trimmed)…", ...lines.slice(lines.length - maxLines)].join("\n");
  return out;
}

async function main() {
  await fs.mkdir(ARTIFACTS, { recursive: true });

  const now = new Date();
  const stamp = fmtNY(now);
  const base = `runbook_report_${stamp}`;
  const reportTxt = join(ARTIFACTS, `${base}.txt`);
  const reportJson = join(ARTIFACTS, `${base}.json`);
  const sha = await gitSha();

  const cfg = await loadConfig();
  const configSteps = cfg?.steps;

  const steps = [];
  for (let n = 2; n <= 10; n++) {
    const pick = pickScriptForStep(n, configSteps);
    let file;
    if (typeof pick === "string") {
      file = pick;
    } else {
      // autodiscover
      if (await pathExists(pick.sh)) file = pick.sh;
      else if (await pathExists(pick.ps)) file = pick.ps;
      else file = null;
    }
    steps.push({ id: n, file });
  }

  const header =
    `RUNBOOK REPORT\n` +
    `Timestamp: ${now.toISOString()} (TZ=${TZ})\n` +
    `Git SHA:   ${sha}\n` +
    `Project:   ${ENV.PROJECT_URL}\n` +
    `Flags:     SKIP_HTTP=${ENV.SKIP_HTTP} SKIP_MV=${ENV.SKIP_MV} ALLOW_PARTIAL=${ENV.ALLOW_PARTIAL}\n` +
    `Host:      ${process.platform} ${process.version}\n` +
    `Steps:     2..10\n` +
    `------------------------------------------------------------\n`;

  const jsonOut = {
    meta: {
      timestamp: now.toISOString(),
      tz: TZ,
      sha,
      project_url: ENV.PROJECT_URL,
      flags: { SKIP_HTTP: ENV.SKIP_HTTP, SKIP_MV: ENV.SKIP_MV, ALLOW_PARTIAL: ENV.ALLOW_PARTIAL },
      node: process.version,
      platform: process.platform,
      artifacts_basename: base,
    },
    steps: [],
    summary: {},
  };

  let report = header;
  let ok = 0, fail = 0, skip = 0;

  for (const s of steps) {
    const name = `STEP ${s.id}`;
    if (!s.file) {
      report += `${name}: SKIPPED (no script found)\n\n`;
      jsonOut.steps.push({ id: s.id, status: "SKIPPED", reason: "missing", file: null });
      skip++;
      continue;
    }

    // Skip by tags (from config.json or filename)
    const tags = (cfg?.steps?.find(x => String(x.id) === String(s.id))?.tags) || detectTagsFromFilename(s.file);
    if (ENV.SKIP_HTTP === "1" && tags.includes("HTTP")) {
      report += `${name}: SKIPPED (tag HTTP)\n\n`;
      jsonOut.steps.push({ id: s.id, status: "SKIPPED", reason: "tag:HTTP", file: s.file });
      skip++;
      continue;
    }
    if (ENV.SKIP_MV === "1" && tags.includes("MV")) {
      report += `${name}: SKIPPED (tag MV)\n\n`;
      jsonOut.steps.push({ id: s.id, status: "SKIPPED", reason: "tag:MV", file: s.file });
      skip++;
      continue;
    }

    // Run
    const started = Date.now();
    const result = await runScript(s.file, { timeoutMs: ENV.RUNBOOK_STEP_TIMEOUT });
    const durMs = Date.now() - started;

    const stdout = maskSecrets(trimBlock(result.stdout));
    const stderr = maskSecrets(trimBlock(result.stderr));
    const status = result.code === 0 ? "OK" : "FAIL";

    if (status === "OK") ok++; else fail++;

    report += `${name}: ${status}  (duration=${Math.round(durMs/1000)}s)\n`;
    report += `File: ${s.file}\n`;
    report += `CMD:  ${result.cmd}\n`;
    if (stdout) report += `--- STDOUT ---\n${stdout}\n`;
    if (stderr) report += `--- STDERR ---\n${stderr}\n`;
    report += `\n`;

    jsonOut.steps.push({
      id: s.id,
      file: s.file,
      cmd: result.cmd,
      status,
      duration_ms: durMs,
      stdout: stdout,
      stderr: stderr,
      code: result.code,
      tags,
    });
  }

  const exitCode = fail > 0 && ENV.ALLOW_PARTIAL !== "1" ? 1 : 0;
  const summary =
    `------------------------------------------------------------\n` +
    `SUMMARY: ok=${ok}  fail=${fail}  skipped=${skip}\n` +
    `EXIT CODE: ${exitCode}\n`;

  report += summary;
  jsonOut.summary = { ok, fail, skipped: skip, exit_code: exitCode };

  await fs.writeFile(reportTxt, report, "utf8");
  await fs.writeFile(reportJson, JSON.stringify(jsonOut, null, 2), "utf8");

  // Also print to console
  process.stdout.write(report);
  process.stdout.write(`\nReport written: ${reportTxt.replaceAll(sep, "/")}\n`);
  process.exit(exitCode);
}

main().catch(async (e) => {
  await fs.mkdir(ARTIFACTS, { recursive: true }).catch(() => {});
  const fallback = `FATAL: ${String(e)}\n`;
  await fs.writeFile(join(ARTIFACTS, `runbook_report_${fmtNY()}.txt`), fallback, "utf8").catch(() => {});
  console.error(fallback);
  process.exit(2);
});