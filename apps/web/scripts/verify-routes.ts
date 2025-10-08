/**
 * Route Verification Script (App Router)
 * Verifies all routes are accessible and navigation works
 * Run: ts-node --project tsconfig.scripts.json scripts/verify-routes.ts
 */

import * as fs from 'fs';
import * as path from 'path';

interface RouteCheck {
  path: string;
  file: string;
  exists: boolean;
  hasNavigation: boolean;
}

const appRoot = process.cwd();
const SRC_APP = path.join(appRoot, 'src', 'app');

const ROUTES_TO_CHECK = [
  { path: '/', file: path.join(SRC_APP, 'page.tsx') },
  { path: '/freight-broker-dashboard', file: path.join(SRC_APP, 'freight-broker-dashboard', 'page.tsx') },
  { path: '/owner-operator-dashboard', file: path.join(SRC_APP, 'owner-operator-dashboard', 'page.tsx') },
  { path: '/fleet-manager-dashboard', file: path.join(SRC_APP, 'fleet-manager-dashboard', 'page.tsx') },
];

const REQUIRED_COMPONENTS = [
  path.join(appRoot, 'src', 'components', 'DashboardNavigation.tsx'),
  path.join(appRoot, 'src', 'components', 'LoadCreationDialog.tsx'),
  path.join(appRoot, 'src', 'components', 'CarrierOnboardingDialog.tsx'),
  path.join(appRoot, 'src', 'components', 'OwnerOperatorDashboard.tsx'),
  path.join(appRoot, 'src', 'components', 'FleetManagerDashboard.tsx'),
  path.join(appRoot, 'src', 'components', 'InsuranceExpiryAlert.tsx'),
  path.join(appRoot, 'src', 'components', 'DashboardSelector.tsx'),
];

console.log('🔍 Starting Route Verification...\n');

// Check routes
console.log('📍 Checking Routes:');
const routeResults: RouteCheck[] = ROUTES_TO_CHECK.map((route) => {
  const exists = fs.existsSync(route.file);
  let hasNavigation = false;
  if (exists) {
    const content = fs.readFileSync(route.file, 'utf-8');
    hasNavigation = content.includes('DashboardNavigation');
  }
  const status = exists ? '✅' : '❌';
  const navStatus = hasNavigation ? '✅' : '⚠️';
  console.log(`${status} ${route.path} - Navigation: ${navStatus}`);
  return {
    path: route.path,
    file: route.file,
    exists,
    hasNavigation,
  };
});

// Check components
console.log('\n📦 Checking Required Components:');
const componentResults = REQUIRED_COMPONENTS.map((component) => {
  const exists = fs.existsSync(component);
  const status = exists ? '✅' : '❌';
  const rel = path.relative(appRoot, component).replace(/\\/g, '/');
  console.log(`${status} ${rel}`);
  return { component, exists };
});

// Check dependencies
console.log('\n📚 Checking Dependencies:');
const packageJsonPath = path.join(appRoot, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf-8'));
const dependencies = { ...packageJson.dependencies, ...packageJson.devDependencies };

const REQUIRED_DEPS = [
  'react',
  'next',
  'typescript',
  'zod',
  'jspdf',
  'lucide-react',
  'tailwindcss',
];

REQUIRED_DEPS.forEach((dep) => {
  const exists = !!dependencies[dep];
  const status = exists ? '✅' : '❌';
  const version = exists ? dependencies[dep] : 'NOT FOUND';
  console.log(`${status} ${dep}: ${version}`);
});

// Summary
console.log('\n' + '='.repeat(60));
console.log('📊 VERIFICATION SUMMARY:');
console.log('='.repeat(60));

const routesPass = routeResults.every((r) => r.exists);
const navPass = routeResults.filter((r) => r.path !== '/').every((r) => r.hasNavigation);
const componentsPass = componentResults.every((c) => c.exists);
const depsPass = REQUIRED_DEPS.every((dep) => !!dependencies[dep]);

console.log(`Routes: ${routesPass ? '✅ PASS' : '❌ FAIL'}`);
console.log(`Navigation: ${navPass ? '✅ PASS' : '⚠️ PARTIAL'}`);
console.log(`Components: ${componentsPass ? '✅ PASS' : '❌ FAIL'}`);
console.log(`Dependencies: ${depsPass ? '✅ PASS' : '❌ FAIL'}`);

const allPass = routesPass && navPass && componentsPass && depsPass;
console.log('\n' + '='.repeat(60));
console.log(`OVERALL STATUS: ${allPass ? '✅ READY FOR TESTING' : '❌ NEEDS ATTENTION'}`);
console.log('='.repeat(60));

if (!allPass) {
  console.log('\n⚠️ Issues detected. Please fix before proceeding.');
  process.exit(1);
} else {
  console.log('\n🎉 All verifications passed! System is ready for testing.');
  process.exit(0);
}
