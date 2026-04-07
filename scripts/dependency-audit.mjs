#!/usr/bin/env node
/*
  Cross-ecosystem dependency audit script
  - Node (npm): vulnerabilities via `npm audit --json`, updates via `npm outdated --json`
  - Dart/Flutter: updates via `dart pub outdated --json`
  - Gradle: detected and reported with recommended plugin to enable updates/vuln scanning

  Output: dependency-audit-<YYYY-MM-DD>.md in repo root
*/

import { execFileSync, execSync, spawnSync } from 'node:child_process';
import { existsSync, readdirSync, statSync, writeFileSync, readFileSync } from 'node:fs';
import { join, basename } from 'node:path';

const REPO_ROOT = process.cwd();
const today = new Date();
const yyyy = today.getFullYear();
const mm = String(today.getMonth() + 1).padStart(2, '0');
const dd = String(today.getDate()).padStart(2, '0');
const REPORT_NAME = `dependency-audit-${yyyy}-${mm}-${dd}.md`;
const REPORT_PATH = join(REPO_ROOT, REPORT_NAME);

function isDirectory(p) {
  try { return statSync(p).isDirectory(); } catch { return false; }
}
function isFile(p) {
  try { return statSync(p).isFile(); } catch { return false; }
}

function walk(dir, options = {}) {
  const {
    maxDepth = 4,
    ignoreDirs = ['.git', 'node_modules', '.dart_tool', '.idea', 'build', '.gradle', '.next', 'out', 'dist', '.svelte-kit', '.venv', '.vscode', '.husky', '.pnpm-store'],
  } = options;
  const results = [];
  function visit(p, depth) {
    if (depth > maxDepth) return;
    let entries;
    try { entries = readdirSync(p, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (e.isDirectory()) {
        if (ignoreDirs.includes(e.name)) continue;
        visit(join(p, e.name), depth + 1);
      } else {
        results.push(join(p, e.name));
      }
    }
  }
  visit(dir, 0);
  return results;
}

function findNodeProjects() {
  const files = walk(REPO_ROOT);
  const pkgs = files.filter(f => basename(f) === 'package.json');
  // Filter out generated/embedded examples
  return pkgs.filter(p => !p.includes('flutter') && !p.includes('ephemeral'))
             .map(p => join(p, '..'));
}

function findDartProjects() {
  const tops = [REPO_ROOT];
  // Include the Flutter app at root (primary)
  return tops.filter(dir => existsSync(join(dir, 'pubspec.yaml')));
}

function hasGradleProject() {
  return existsSync(join(REPO_ROOT, 'android', 'build.gradle')) || existsSync(join(REPO_ROOT, 'android', 'build.gradle.kts'));
}

function run(command, args, cwd, timeoutMs = 60_000) {
  try {
    const res = spawnSync(command, args, { cwd, encoding: 'utf8', timeout: timeoutMs, shell: process.platform === 'win32' });
    if (res.error) throw res.error;
    return { code: res.status ?? 0, stdout: res.stdout || '', stderr: res.stderr || '' };
  } catch (e) {
    return { code: 1, stdout: '', stderr: String(e) };
  }
}

function safeJsonParse(s) {
  try { return JSON.parse(s); } catch { return null; }
}

function semverDiff(current, latest) {
  // naive semver comparison category: major/minor/patch/other
  const parse = v => (v || '').replace(/^v/, '').split('-')[0].split('.').map(n => parseInt(n, 10));
  const [a, b, c] = parse(current);
  const [x, y, z] = parse(latest);
  if ([a,b,c].some(n => Number.isNaN(n)) || [x,y,z].some(n => Number.isNaN(n))) return 'other';
  if (x > a) return 'major';
  if (x === a && y > b) return 'minor';
  if (x === a && y === b && z > c) return 'patch';
  return 'none';
}

function auditNodeProject(dir) {
  const result = { dir, type: 'node', vulnerabilities: [], updates: [], errors: [] };
  // npm audit
  const audit = run('npm', ['audit', '--json', '--omit=dev'], dir, 120_000);
  if (audit.code === 0 || audit.stdout) {
    const data = safeJsonParse(audit.stdout);
    if (data && data.vulnerabilities) {
      // npm v8/9 format
      for (const [name, vuln] of Object.entries(data.vulnerabilities)) {
        const viaList = Array.isArray(vuln.via) ? vuln.via : [];
        const entries = viaList.map(v => typeof v === 'string' ? { title: v } : v);
        for (const v of entries) {
          result.vulnerabilities.push({
            package: name,
            severity: vuln.severity,
            via: v.title || v.name || v.source,
            id: v.url ? v.url.split('/').pop() : (v.source || ''),
            range: vuln.range,
            fixAvailable: vuln.fixAvailable,
          });
        }
      }
    } else if (data && data.advisories) {
      // older npm format
      for (const adv of Object.values(data.advisories)) {
        const a = adv;
        result.vulnerabilities.push({
          package: a.module_name,
          severity: a.severity,
          via: a.title,
          id: `GHSA-${a.github_advisory_id || a.id}`,
          range: a.vulnerable_versions,
          fixAvailable: a.fix_available,
        });
      }
    }
  } else {
    result.errors.push(`npm audit failed: ${audit.stderr || 'unknown error'}`);
  }

  // npm outdated
  const outdated = run('npm', ['outdated', '--json'], dir, 120_000);
  if (outdated.stdout) {
    const data = safeJsonParse(outdated.stdout) || {};
    for (const [name, info] of Object.entries(data)) {
      const diff = semverDiff(info.current, info.latest);
      result.updates.push({
        package: name,
        current: info.current,
        wanted: info.wanted,
        latest: info.latest,
        type: diff,
      });
    }
  } else if (outdated.code !== 0 && outdated.stderr) {
    // npm returns non-zero when outdated exists; ignore if no stdout
  }

  return result;
}

function auditDartProject(dir) {
  const result = { dir, type: 'dart', vulnerabilities: [], updates: [], errors: [] };
  // Use `dart pub outdated --json`
  const cmd = run('dart', ['pub', 'outdated', '--json'], dir, 180_000);
  if (cmd.stdout) {
    const data = safeJsonParse(cmd.stdout);
    if (data && data.packages) {
      for (const p of data.packages) {
        const current = p.current?.version || null;
        const latest = p.latest?.version || null;
        const resolvable = p.resolvable?.version || null;
        if (current && latest && current !== latest) {
          const diff = semverDiff(current, latest);
          result.updates.push({ package: p.package, current, wanted: resolvable, latest, type: diff });
        }
      }
    }
  } else if (cmd.stderr) {
    result.errors.push(`dart pub outdated failed: ${cmd.stderr.trim()}`);
  }
  // No native vulnerability IDs available from pub yet; note none/unknown
  return result;
}

function formatReport(sections) {
  const lines = [];
  lines.push(`# Dependency Audit Report`);
  lines.push('');
  lines.push(`Date: ${yyyy}-${mm}-${dd}`);
  lines.push('');
  lines.push(`This report aggregates dependency vulnerabilities and update availability across detected package managers in this repository. Major upgrades are listed but batched separately with a note about potential breaking changes.`);
  lines.push('');

  for (const s of sections) {
    lines.push(`## ${s.type.toUpperCase()} project: ${s.dir.replace(REPO_ROOT, '.')}\n`);

    if (s.vulnerabilities?.length) {
      lines.push(`### Vulnerabilities`);
      lines.push('');
      // header
      lines.push('| Package | Severity | ID/Source | Affected Range | Fix Available |');
      lines.push('|---|---|---|---|---|');
      for (const v of s.vulnerabilities.sort((a,b) => (b.severity||'').localeCompare(a.severity||''))) {
        const fix = typeof v.fixAvailable === 'object' ? JSON.stringify(v.fixAvailable) : (v.fixAvailable ? 'Yes' : 'No');
        lines.push(`| ${v.package} | ${v.severity || ''} | ${v.id || v.via || ''} | ${v.range || ''} | ${fix} |`);
      }
      lines.push('');
    } else {
      lines.push('No vulnerabilities reported by native tooling.');
      lines.push('');
    }

    const patchMinor = s.updates.filter(u => u.type === 'patch' || u.type === 'minor');
    const majors = s.updates.filter(u => u.type === 'major');

    if (patchMinor.length) {
      lines.push('### Patch/Minor updates available');
      lines.push('');
      lines.push('| Package | Current | Wanted | Latest | Update Type |');
      lines.push('|---|---|---|---|---|');
      for (const u of patchMinor.sort((a,b) => a.package.localeCompare(b.package))) {
        lines.push(`| ${u.package} | ${u.current || ''} | ${u.wanted || ''} | ${u.latest || ''} | ${u.type} |`);
      }
      lines.push('');
    } else {
      lines.push('No patch/minor updates available.');
      lines.push('');
    }

    if (majors.length) {
      lines.push('### Major updates (batched)');
      lines.push('');
      lines.push('The following have newer major versions which may introduce breaking changes. Consider evaluating release notes and upgrading in a dedicated branch.');
      lines.push('');
      lines.push('| Package | Current | Latest | Note |');
      lines.push('|---|---|---|---|');
      for (const u of majors.sort((a,b) => a.package.localeCompare(b.package))) {
        lines.push(`| ${u.package} | ${u.current || ''} | ${u.latest || ''} | Potential breaking changes |`);
      }
      lines.push('');
    }

    if (s.errors?.length) {
      lines.push('> Notes/Errors:');
      for (const e of s.errors) lines.push(`> - ${e}`);
      lines.push('');
    }
  }

  // Gradle section note if present
  if (hasGradleProject()) {
    lines.push('## GRADLE (Android)');
    lines.push('');
    lines.push('Gradle project detected at ./android. Native vulnerability scanning is not configured. To enable rich reports:');
    lines.push('- Add the Gradle Versions plugin to check available updates: https://github.com/ben-manes/gradle-versions-plugin');
    lines.push('- Consider OWASP Dependency-Check or Gradle OWASP plugin for vulnerability IDs.');
    lines.push('');
  }

  lines.push('---');
  lines.push('Next steps:');
  lines.push('- Optionally apply patch/minor updates where tests pass.');
  lines.push('- Investigate and remediate listed vulnerabilities (apply fixes, overrides, or pins).');
  lines.push('- Schedule major upgrades separately.');

  return lines.join('\n');
}

function main() {
  const sections = [];

  // Node projects
  const nodeDirs = [...new Set(findNodeProjects())];
  for (const dir of nodeDirs) {
    // Skip if this is within node_modules
    if (dir.includes('node_modules')) continue;
    // Ensure package.json exists and is not a plugin example
    try {
      const pkgJson = JSON.parse(readFileSync(join(dir, 'package.json'), 'utf8'));
      // Only include real projects (skip examples in Flutter plugins if any leaked)
      sections.push(auditNodeProject(dir));
    } catch {}
  }

  // Dart projects (top-level only)
  for (const dir of findDartProjects()) {
    sections.push(auditDartProject(dir));
  }

  const md = formatReport(sections);
  writeFileSync(REPORT_PATH, md, 'utf8');
  console.log(`Wrote ${REPORT_PATH}`);
}

main();
