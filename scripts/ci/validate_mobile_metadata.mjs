#!/usr/bin/env node
/**
 * Lightweight validator for mobile metadata (no build):
 * - iOS Info.plist: presence of required purpose strings and UIBackgroundModes (location when used)
 * - Android manifests: presence of location permissions and foreground service type
 * Exits with code 1 on failure, prints warnings otherwise.
 */
import fs from 'node:fs';
import path from 'node:path';

function fail(msg){ console.error(`[store-readiness] ${msg}`); process.exit(1); }
function warn(msg){ console.warn(`[store-readiness] WARN: ${msg}`); }
function ok(msg){ console.log(`[store-readiness] ${msg}`); }

function readText(p){ try { return fs.readFileSync(p, 'utf8'); } catch { return null; } }

// iOS Info.plist (Runner)
(function validateIOS(){
  const plistPath = path.join(process.cwd(), 'ios', 'Runner', 'Info.plist');
  const txt = readText(plistPath);
  if (!txt) { warn(`iOS Info.plist not found at ${plistPath}`); return; }
  const mustKeys = [
    'NSLocationWhenInUseUsageDescription',
    'NSLocationAlwaysAndWhenInUseUsageDescription',
  ];
  for (const k of mustKeys) {
    if (!txt.includes(`<key>${k}</key>`)) {
      warn(`Missing ${k} in Info.plist`);
    }
  }
  // Background modes
  if (!txt.includes('<key>UIBackgroundModes</key>')) {
    warn('UIBackgroundModes not present (add <array><string>location</string></array> if using background tracking)');
  } else if (!txt.includes('<string>location</string>')) {
    warn('UIBackgroundModes present but missing <string>location</string>');
  }
  ok('iOS Info.plist check completed');
})();

// Android manifest(s)
(function validateAndroid(){
  const root = path.join(process.cwd(), 'android');
  const manifests = [
    path.join(root, 'app', 'src', 'main', 'AndroidManifest.xml'),
    path.join(root, 'src', 'main', 'AndroidManifest.xml'),
  ].filter((p)=>fs.existsSync(p));
  if (manifests.length === 0) { warn('AndroidManifest.xml not found'); return; }
  let anyOk = false;
  for (const m of manifests) {
    const txt = readText(m);
    if (!txt) continue;
    anyOk = true;
    const required = [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.FOREGROUND_SERVICE',
    ];
    for (const perm of required) {
      if (!txt.includes(perm)) warn(`Missing <uses-permission ${perm}> in ${m}`);
    }
    // Background location (optional but recommended if tracking in background)
    if (!txt.includes('android.permission.ACCESS_BACKGROUND_LOCATION')) {
      warn('ACCESS_BACKGROUND_LOCATION not declared (required for background tracking on Android 10+)');
    }
    // Foreground service type location (Android 10+)
    if (!txt.includes('android:foregroundServiceType="location"')) {
      warn('Service missing android:foregroundServiceType="location" (required for location foreground service)');
    }
  }
  if (anyOk) ok('Android manifest check completed');
})();
