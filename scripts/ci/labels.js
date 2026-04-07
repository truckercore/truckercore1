#!/usr/bin/env node
/*
 Label policy enforcement for PRs:
 - Require at least one of the labels: type:feature, type:fix, type:ops
 - Require CHANGELOG.md to be modified in the PR unless label "skip-changelog" is present
 - Provide clear failure messages and hints.

 Implementation details:
 - Uses GitHub Actions environment variables to read the pull_request payload and repo context.
 - Falls back to GitHub REST API with GITHUB_TOKEN to fetch files/labels if needed.
*/

const fs = require('fs');
const path = require('path');

const token = process.env.GITHUB_TOKEN;
const repo = process.env.GITHUB_REPOSITORY; // owner/repo
const eventPath = process.env.GITHUB_EVENT_PATH; // JSON payload

if (!repo || !eventPath) {
  console.error('[labels] Missing GITHUB_REPOSITORY or GITHUB_EVENT_PATH in environment.');
  process.exit(1);
}

const event = JSON.parse(fs.readFileSync(eventPath, 'utf8'));
const pr = event.pull_request;
if (!pr) {
  console.log('[labels] Not a pull_request event. Skipping.');
  process.exit(0);
}

const requiredTypes = new Set(['type:feature', 'type:fix', 'type:ops']);

function hasRequiredTypeLabel(labels) {
  return labels.some((l) => requiredTypes.has((l.name || '').toLowerCase()));
}

async function fetchPRFiles() {
  if (!token) return [];
  const url = pr._links?.self?.href?.replace(/\{.*\}$/,'') || pr.url;
  const filesUrl = url + '/files';
  const files = [];
  let page = 1;
  while (true) {
    const res = await fetch(filesUrl + `?per_page=100&page=${page}`, {
      headers: { Authorization: `Bearer ${token}`, 'Accept': 'application/vnd.github+json' }
    });
    if (!res.ok) throw new Error(`Failed to fetch PR files: ${res.status}`);
    const batch = await res.json();
    files.push(...batch);
    if (batch.length < 100) break;
    page++;
  }
  return files;
}

(async function main(){
  const labels = pr.labels || [];
  const number = pr.number;
  const owner = repo.split('/')[0];
  const reponame = repo.split('/')[1];

  const hasType = hasRequiredTypeLabel(labels);
  const hasSkipChangelog = labels.some((l) => (l.name || '').toLowerCase() === 'skip-changelog');

  // Fetch changed files to see if CHANGELOG.md was touched
  let changed = [];
  try {
    changed = await fetchPRFiles();
  } catch (e) {
    console.warn('[labels] Could not fetch PR files via API, continuing with labels check only:', e.message);
  }
  const touchedChangelog = changed.some((f) => (f.filename || '').toLowerCase() === 'changelog.md');

  const problems = [];
  if (!hasType) {
    problems.push('Missing required label. Please add one of: type:feature, type:fix, or type:ops.');
  }
  if (!hasSkipChangelog && !touchedChangelog) {
    problems.push('CHANGELOG.md not updated. Either add an entry to CHANGELOG.md or apply the label "skip-changelog" with justification.');
  }

  if (problems.length) {
    console.error('[labels] Policy check failed:\n- ' + problems.join('\n- '));
    console.error(`PR: #${number} (${owner}/${reponame})`);
    process.exit(1);
  }

  console.log('[labels] Label policy passed.');
})();
