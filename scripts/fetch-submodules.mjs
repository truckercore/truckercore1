#!/usr/bin/env node
// Cross-platform replacement for scripts/fetch-submodules.sh
import { existsSync } from 'fs';
import { execSync } from 'child_process';

const log = (...args) => console.log('[fetch-submodules]', ...args);
const run = (cmd) => {
  try {
    log('running:', cmd);
    execSync(cmd, { stdio: 'inherit' });
  } catch (err) {
    log('command failed:', cmd);
    throw err;
  }
};

log('Starting submodule fetch...');

if (!existsSync('.gitmodules')) {
  log('No .gitmodules found; skipping.');
  process.exit(0);
}

const token = process.env.GITHUB_ACCESS_TOKEN || '';

if (token) {
  log('Configuring authenticated HTTPS for github.com using provided token.');
  // Configure git to rewrite https://github.com/ to use the token
  try {
    run(`git config --global url."https://${token}@github.com/".insteadOf "https://github.com/"`);
  } catch (e) {
    // Non-fatal
    console.error('[fetch-submodules] Warning: failed to set global git config replacement', e?.message || e);
  }

  // Try to find submodule URL keys and rewrite SSH to HTTPS
  let names = '';
  try {
    names = execSync("git config -f .gitmodules --name-only --get-regexp '^submodule\\..*\\.url$'", { encoding: 'utf8' });
  } catch (e) {
    names = '';
  }

  if (names) {
    log('Rewriting SSH submodule URLs to HTTPS where needed.');
    const keys = names.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
    for (const key of keys) {
      try {
        const url = execSync(`git config -f .gitmodules --get ${key}`, { encoding: 'utf8' }).trim();
        if (/^git@github.com:/.test(url)) {
          let repo = url.replace(/^git@github.com:/, '');
          repo = repo.replace(/\.git$/, '');
          const httpsUrl = `https://github.com/${repo}.git`;
          run(`git config -f .gitmodules ${key} "${httpsUrl}"`);
        }
      } catch (e) {
        // ignore per-file errors
        console.error('[fetch-submodules] Warning: failed to rewrite key', key, e?.message || e);
      }
    }

    try {
      run('git submodule sync --recursive || true');
    } catch (e) {
      // ignore
    }
  }
}

log('Running git submodule update --init --recursive');
try {
  run('git submodule update --init --recursive');
  log('Completed.');
} catch (e) {
  console.error('[fetch-submodules] Warning: submodule update failed. Check credentials and access.');
  process.exit(1);
}

