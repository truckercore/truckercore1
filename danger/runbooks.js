// danger/runbooks.js
const { danger, fail, warn, markdown } = require("danger");
const fs = require("fs");
const path = require("path");

function getChangedFiles(glob = /.*/i) {
  return [
    ...danger.git.created_files,
    ...danger.git.modified_files,
  ].filter((f) => f.match(glob));
}

function readFileSafe(p) {
  try {
    return fs.readFileSync(p, "utf8");
  } catch {
    return "";
  }
}

async function checkRunbooks() {
  const runbookFiles = getChangedFiles(/(^|\/)runbooks\/.*\.(md|mdx)$/i);
  if (!runbookFiles.length) return;

  const missing = [];
  const todoHits = [];
  const required = [/^#+\s*Activation\b/i, /^#+\s*Monitoring\b/i, /^#+\s*Rollback\b/i, /^#+\s*Hygiene\b/i];

  for (const f of runbookFiles) {
    const body = readFileSafe(f);
    const ok = required.every((r) => r.test(body));
    if (!ok) missing.push(f);
    if (/\bTODO\b/i.test(body) || /\bTBD\b/i.test(body) || /<\s*FILL/i.test(body)) {
      todoHits.push(f);
    }
  }

  if (missing.length) {
    fail(
      `Runbook completeness check failed: missing required sections in:\n${missing
        .map((s) => `- ${s}`)
        .join("\n")}`
    );
  }
  if (todoHits.length) {
    fail(
      `Runbooks contain placeholders (TODO/TBD):\n${todoHits
        .map((s) => `- ${s}`)
        .join("\n")}`
    );
  }
  if (!missing.length && !todoHits.length) {
    markdown("✅ Runbooks: sections present and no placeholders.");
  }
}

module.exports = { checkRunbooks };
