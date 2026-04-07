#!/usr/bin/env node
// Verifies presence of basic store assets (icons/screenshots placeholders)
import fs from 'node:fs';
import path from 'node:path';

function fail(msg){ console.error(`[assets] ${msg}`); process.exit(1); }
function ok(msg){ console.log(`[assets] ${msg}`); }
function warn(msg){ console.warn(`[assets] WARN: ${msg}`); }

const iconHints = [
  path.join('assets', 'icons', 'tray'),
  path.join('assets', 'logo'),
];
let anyIcon = false;
for (const p of iconHints) {
  const full = path.join(process.cwd(), p);
  if (fs.existsSync(full)) {
    const files = fs.readdirSync(full).filter(f=>/\.(png|svg|ico|icns)$/i.test(f));
    if (files.length) { anyIcon = true; ok(`found icons in ${p}: ${files.length}`); }
  }
}
if (!anyIcon) warn('No obvious icon assets found under assets/icons or assets/logo');

// Screenshots directory convention (optional): docs/store/screenshots/{ios,android}
const shotsBase = path.join(process.cwd(), 'docs', 'store', 'screenshots');
if (!fs.existsSync(shotsBase)) {
  warn('docs/store/screenshots directory not found (add phone/tablet screenshots)');
} else {
  const ios = path.join(shotsBase, 'ios');
  const and = path.join(shotsBase, 'android');
  const count = (d)=>fs.existsSync(d)? fs.readdirSync(d).filter(f=>/\.(png|jpg|jpeg)$/i.test(f)).length : 0;
  ok(`screenshots: ios=${count(ios)} android=${count(and)}`);
}

ok('Store assets check completed');
