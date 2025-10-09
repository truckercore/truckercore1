// JavaScript
const fs = require('fs');
const path = require('path');

console.log('🔍 TruckerCore SEO & Asset Validation\n');

// Check 1: Pages have required meta tags
const pagesToCheck = [
  'pages/index.tsx',
  'pages/about.tsx',
  'pages/privacy.tsx',
  'pages/terms.tsx',
  'pages/contact.tsx',
  'pages/docs.tsx',
  'pages/404.tsx',
  'pages/downloads/index.tsx',
];

const requiredTags = [
  { tag: '<title>', name: 'Title tag' },
  { tag: 'name="description"', name: 'Description meta' },
  { tag: 'name="viewport"', name: 'Viewport meta' },
];

console.log('📄 Checking page meta tags...\n');
let metaIssues = 0;

pagesToCheck.forEach(page => {
  const filepath = path.join(process.cwd(), page);
  if (!fs.existsSync(filepath)) {
    console.log(`⚠️  ${page} - File not found`);
    metaIssues++;
    return;
  }
  const content = fs.readFileSync(filepath, 'utf-8');
  const missing = requiredTags.filter(({ tag }) => !content.includes(tag));
  if (missing.length === 0) {
    console.log(`✓ ${page}`);
  } else {
    console.log(`✗ ${page}`);
    missing.forEach(({ name }) => console.log(`   Missing: ${name}`));
    metaIssues++;
  }
});

// Check 2: Required public assets exist
console.log('\n📦 Checking public assets...\n');
const requiredAssets = [
  'public/manifest.json',
  'public/logo.svg',
  'public/robots.txt',
  'public/sitemap.xml',
];

const optionalAssets = [
  'public/favicon.ico',
  'public/icon-192.png',
  'public/icon-512.png',
  'public/apple-touch-icon.png',
  'public/og-image.png',
];

let assetIssues = 0;

requiredAssets.forEach(asset => {
  const filepath = path.join(process.cwd(), asset);
  if (fs.existsSync(filepath)) {
    const stats = fs.statSync(filepath);
    console.log(`✓ ${asset} (${(stats.size / 1024).toFixed(1)} KB)`);
  } else {
    console.log(`✗ ${asset} - MISSING (required)`);
    assetIssues++;
  }
});

console.log('\nOptional assets:');
optionalAssets.forEach(asset => {
  const filepath = path.join(process.cwd(), asset);
  if (fs.existsSync(filepath)) {
    console.log(`✓ ${asset}`);
  } else {
    console.log(`⚠️  ${asset} - Not found (recommended)`);
  }
});

// Check 3: Next.js config
console.log('\n⚙️  Checking Next.js configuration...\n');
const configPath = path.join(process.cwd(), 'next.config.js');
if (fs.existsSync(configPath)) {
  console.log('✓ next.config.js exists');
} else {
  console.log('⚠️  next.config.js not found (optional)');
}

// Check 4: Router setup
console.log('\n🔀 Checking router setup...\n');
const hasAppRouter = fs.existsSync(path.join(process.cwd(), 'app', 'layout.tsx'));
const hasPagesRouter = fs.existsSync(path.join(process.cwd(), 'pages', '_app.tsx'));

if (hasAppRouter && hasPagesRouter) {
  console.log('ℹ️  Both App Router and Pages Router detected. This is supported, but ensure routes are intentional.');
} else if (hasAppRouter) {
  console.log('✓ Using App Router (app/layout.tsx found)');
} else if (hasPagesRouter) {
  console.log('✓ Using Pages Router (pages/_app.tsx found)');
} else {
  console.log('✗ No router layout found - build will fail!');
  assetIssues++;
}

// Summary
console.log('\n' + '='.repeat(50));
const totalIssues = metaIssues + assetIssues;
if (totalIssues === 0) {
  console.log('✅ All validation checks passed!');
  console.log('   Ready for production deployment.');
  process.exit(0);
} else {
  console.log(`❌ Found ${totalIssues} issue(s) that need attention:`);
  if (metaIssues > 0) console.log(`   - ${metaIssues} pages missing meta tags`);
  if (assetIssues > 0) console.log(`   - ${assetIssues} required assets missing`);
  console.log('\n   Fix these issues before deploying to production.');
  process.exit(1);
}
