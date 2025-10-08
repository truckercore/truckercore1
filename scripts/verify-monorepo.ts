/**
 * Monorepo Structure Verification Script (App Router aware)
 * Verifies the monorepo is correctly configured for Vercel deployment
 * Run (from repo root): npx ts-node scripts/verify-monorepo.ts
 */

import * as fs from 'fs';
import * as path from 'path';

console.log('🔍 Verifying Monorepo Structure for Vercel Deployment...\n');

interface VerificationResult {
  item: string;
  status: 'PASS' | 'FAIL' | 'WARNING';
  message: string;
}

const results: VerificationResult[] = [];

function verify(item: string, check: boolean, passMsg: string, failMsg: string): boolean {
  if (check) {
    results.push({ item, status: 'PASS', message: passMsg });
    console.log(`✅ ${item}: ${passMsg}`);
    return true;
  } else {
    results.push({ item, status: 'FAIL', message: failMsg });
    console.error(`❌ ${item}: ${failMsg}`);
    return false;
  }
}

function warn(item: string, message: string) {
  results.push({ item, status: 'WARNING', message });
  console.warn(`⚠️  ${item}: ${message}`);
}

const root = process.cwd();

// Check 1: Root vercel.json exists
const vercelJsonPath = path.join(root, 'vercel.json');
const vercelJsonExists = fs.existsSync(vercelJsonPath);
verify(
  'Root vercel.json',
  vercelJsonExists,
  'Found in root directory',
  'Missing from root directory'
);

// Check 2: Verify vercel.json configuration (support both modern and legacy formats)
if (vercelJsonExists) {
  try {
    const vercelJson = JSON.parse(fs.readFileSync(vercelJsonPath, 'utf-8'));

    const usesBuildsArray = Array.isArray(vercelJson.builds);
    const hasBuildCommand = typeof vercelJson.buildCommand === 'string';

    verify(
      'Vercel config format',
      usesBuildsArray || hasBuildCommand,
      usesBuildsArray ? 'Using builds[] with @vercel/next' : 'Using buildCommand/outputDirectory format',
      'Unknown vercel.json format (expected builds[] or buildCommand)'
    );

    // If using buildCommand format, check target paths
    if (hasBuildCommand) {
      verify(
        'buildCommand',
        !!vercelJson.buildCommand,
        `Configured: "${vercelJson.buildCommand}"`,
        'buildCommand not set'
      );

      verify(
        'outputDirectory',
        vercelJson.outputDirectory === 'apps/web/.next',
        'Correctly set to "apps/web/.next"',
        `Incorrect or missing: "${vercelJson.outputDirectory}"`
      );

      verify(
        'Root directory',
        vercelJson.installCommand?.includes('--prefix apps/web') ||
          vercelJson.buildCommand?.includes('apps/web'),
        'Correctly configured for apps/web',
        'Root directory not properly configured'
      );
    } else if (usesBuildsArray) {
      // Basic sanity checks for builds[] format
      const hasNextBuild = vercelJson.builds?.some((b: any) => b.use === '@vercel/next');
      verify('Next builder', !!hasNextBuild, 'Found @vercel/next builder', 'Missing @vercel/next builder');

      const targetsWebPkg = vercelJson.builds?.some((b: any) => typeof b.src === 'string' && b.src.includes('apps/web/package.json'));
      verify('Build target path', !!targetsWebPkg, 'Targets apps/web/package.json', 'Build target should be apps/web/package.json');
    }
  } catch (e) {
    verify('vercel.json parse', false, '', 'Invalid JSON');
  }
}

// Check 3: Apps directory structure
const appsDir = path.join(root, 'apps');
verify('apps/ directory', fs.existsSync(appsDir), 'Exists', 'Missing - create apps/ directory');

// Check 4: apps/web directory
const webDir = path.join(appsDir, 'web');
verify('apps/web/ directory', fs.existsSync(webDir), 'Exists', 'Missing - create apps/web/ directory');

// Check 5: apps/web/package.json
const webPackageJsonPath = path.join(webDir, 'package.json');
const webPackageJsonExists = fs.existsSync(webPackageJsonPath);
verify(
  'apps/web/package.json',
  webPackageJsonExists,
  'Found',
  'Missing - Next.js app package.json not found'
);

let webPackageJson: any = {};
if (webPackageJsonExists) {
  try {
    webPackageJson = JSON.parse(fs.readFileSync(webPackageJsonPath, 'utf-8'));
  } catch (e) {}

  verify(
    'Next.js dependency',
    !!webPackageJson.dependencies?.next,
    `Next.js version: ${webPackageJson.dependencies?.next}`,
    'Next.js not found in dependencies'
  );

  verify('Build script', !!webPackageJson.scripts?.build, 'Build script configured', 'Build script missing');
}

// Check 6: apps/web routing (support App Router under src/app)
const srcDir = path.join(webDir, 'src');
const appDir = path.join(srcDir, 'app');
const hasAppRouter = fs.existsSync(appDir);
verify('apps/web/src/app (App Router)', hasAppRouter, 'Found', 'Missing App Router directory');

// Critical app routes
const criticalAppRoutes = [
  path.join(appDir, 'page.tsx'),
  path.join(appDir, 'freight-broker-dashboard', 'page.tsx'),
  path.join(appDir, 'owner-operator-dashboard', 'page.tsx'),
  path.join(appDir, 'fleet-manager-dashboard', 'page.tsx'),
];

criticalAppRoutes.forEach((p) => {
  const rel = path.relative(webDir, p).replace(/\\/g, '/');
  verify(`Route: ${rel}`, fs.existsSync(p), 'Found', 'Missing');
});

// Check 7: apps/web/components directory
const componentsDir = path.join(webDir, 'src', 'components');
verify(
  'apps/web/src/components/',
  fs.existsSync(componentsDir),
  'Components directory exists',
  'Components directory missing'
);

// Check 8: apps/web/next.config.js
const nextConfigPath = path.join(webDir, 'next.config.js');
verify('apps/web/next.config.js', fs.existsSync(nextConfigPath), 'Next.js config found', 'Next.js config missing');

// Check 9: apps/web/tsconfig.json
const tsconfigPath = path.join(webDir, 'tsconfig.json');
verify('apps/web/tsconfig.json', fs.existsSync(tsconfigPath), 'TypeScript config found', 'TypeScript config missing - create tsconfig.json');

// Check 10: .vercelignore (optional but recommended)
const vercelIgnorePath = path.join(root, '.vercelignore');
if (!fs.existsSync(vercelIgnorePath)) {
  warn('.vercelignore', 'Not found - consider creating to exclude unnecessary files');
}

// Check 11: Environment variables documentation
const envExamplePath = path.join(webDir, '.env.example');
if (!fs.existsSync(envExamplePath)) {
  warn('apps/web/.env.example', 'Not found - consider creating for documentation');
}

// Summary
console.log('\n' + '='.repeat(70));
console.log('📊 VERIFICATION SUMMARY');
console.log('='.repeat(70));

const passed = results.filter((r) => r.status === 'PASS').length;
const failed = results.filter((r) => r.status === 'FAIL').length;
const warnings = results.filter((r) => r.status === 'WARNING').length;

console.log(`✅ Passed: ${passed}`);
console.log(`❌ Failed: ${failed}`);
console.log(`⚠️  Warnings: ${warnings}`);
console.log(`📊 Total Checks: ${results.length}`);

console.log('\n' + '='.repeat(70));

if (failed === 0) {
  console.log('🎉 Monorepo structure is correctly configured for Vercel!');
  console.log('\n✅ Ready to deploy with:');
  console.log('   vercel --prod\n');
  process.exit(0);
} else {
  console.log('⚠️  Issues detected. Please fix the failures above before deploying.\n');
  process.exit(1);
}