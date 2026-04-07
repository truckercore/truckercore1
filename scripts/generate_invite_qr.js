/* Node 18+ script: generates n invite codes as QR PNGs and a manifest CSV.
   Usage: node generate_invite_qr.js --org_id=<uuid> --count=100 --out=./out
*/
import fs from 'node:fs';
import path from 'node:path';
import QRCode from 'qrcode';

const args = Object.fromEntries(process.argv.slice(2).map(kv => {
  const [k, ...v] = kv.split('=');
  return [k.replace(/^--/, ''), v.join('=')];
}));

const orgId = args.org_id || '00000000-0000-0000-0000-000000000000';
const count = parseInt(args.count || '50', 10);
const outDir = args.out || './qr_codes';
fs.mkdirSync(outDir, { recursive: true });

function shortToken() {
  // 20-char base36 token: reasonably short, time-limited validation on server
  return Math.random().toString(36).slice(2, 12) + Math.random().toString(36).slice(2, 12);
}

const manifest = [['org_id', 'role', 'token', 'deep_link']];

console.log(`Generating ${count} invite tokens for org ${orgId}...`);
for (let i = 1; i <= count; i++) {
  const token = shortToken();
  const role = 'driver';
  const deepLink = `app://accept-invite?token=${token}`;
  const file = path.join(outDir, `invite_${String(i).padStart(3, '0')}.png`);
  // Generate QR code PNG
  await QRCode.toFile(file, deepLink, { width: 512, margin: 2 });
  manifest.push([orgId, role, token, deepLink]);
}

const csv = manifest.map(r => r.map(v => `"${String(v).replaceAll('"', '""')}"`).join(',')).join('\n');
fs.writeFileSync(path.join(outDir, 'manifest.csv'), csv);
console.log(`Done. Files written to ${outDir}`);
