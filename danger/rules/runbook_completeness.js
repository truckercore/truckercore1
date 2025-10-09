// Checks runbooks contain required sections and no TODOs/placeholders
const REQUIRED = ["## Activation", "## Monitoring", "## Rollback", "## Hygiene"];
module.exports = async ({ danger, fail, warn, markdown }) => {
  const changed = danger.git.modified_files.concat(danger.git.created_files)
    .filter(f => f.startsWith("docs/runbooks/") && f.endsWith(".md"));
  for (const f of changed) {
    const diff = await danger.git.diffForFile(f);
    const content = (diff && diff.after) || "";
    if (!REQUIRED.every(h => content.includes(h))) {
      fail(`Runbook missing required sections in ${f}`);
    }
    if (/TODO|TBD|<placeholder>/i.test(content)) {
      fail(`Runbook contains TODO/TBD/placeholder in ${f}`);
    }
  }
};
