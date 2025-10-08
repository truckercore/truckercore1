#!/usr/bin/env node
/**
 * Generates placeholder assets using node-canvas (for development only)
 * Requires: npm install canvas
 */
import { createWriteStream, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

let canvasLib;
try {
  // dynamic import to avoid hard dependency
  canvasLib = await import('canvas');
} catch (e) {
  console.error('This script requires the "canvas" package.');
  console.error('Install it with: npm install canvas');
  process.exit(1);
}

const { createCanvas, registerFont } = canvasLib;

const publicDir = join(process.cwd(), 'apps', 'web', 'public');
if (!existsSync(publicDir)) {
  mkdirSync(publicDir, { recursive: true });
}

function generatePlaceholder(width, height, text, filepath) {
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  // Background
  ctx.fillStyle = '#0F1216';
  ctx.fillRect(0, 0, width, height);

  // Border
  ctx.strokeStyle = '#58A6FF';
  ctx.lineWidth = Math.max(2, Math.round(width / 100));
  ctx.strokeRect(2, 2, width - 4, height - 4);

  // Text
  ctx.fillStyle = '#58A6FF';
  const fontSize = Math.max(14, Math.round(width / 8));
  ctx.font = `bold ${fontSize}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, width / 2, height / 2);

  // Save
  return new Promise((resolve, reject) => {
    const out = createWriteStream(filepath);
    const stream = canvas.createPNGStream();
    stream.pipe(out);
    out.on('finish', () => {
      console.log(`✓ Generated ${filepath}`);
      resolve();
    });
    out.on('error', reject);
  });
}

async function main() {
  console.log('Generating placeholder homepage assets into', publicDir, '...\n');
  try {
    await generatePlaceholder(1200, 630, 'TruckerCore', join(publicDir, 'og-image.png'));
    await generatePlaceholder(180, 180, 'TC', join(publicDir, 'apple-touch-icon.png'));
    await generatePlaceholder(192, 192, 'TC', join(publicDir, 'icon-192.png'));
    await generatePlaceholder(512, 512, 'TC', join(publicDir, 'icon-512.png'));
    // Fallback favicon as PNG (convert to ICO for production)
    await generatePlaceholder(32, 32, 'TC', join(publicDir, 'favicon.png'));
    console.log('\n⚠  Note: A real favicon.ico is recommended for production. Convert favicon.png to .ico.');
    console.log('   See docs/homepage/ASSET_GUIDE.md for details.');
    console.log('\n✅ Placeholder assets generated');
  } catch (err) {
    console.error('Error generating assets:', err?.message || err);
    process.exit(1);
  }
}

main();