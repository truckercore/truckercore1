#!/usr/bin/env node
// Cross-platform DNS checker wrapper

const { spawn } = require('child_process');
const { platform } = require('os');
const { join } = require('path');

const isWindows = platform() === 'win32';
const scriptDir = __dirname;

// Determine which script to run
const scriptPath = isWindows
  ? join(scriptDir, 'check-windows.ps1')
  : join(scriptDir, 'check.mjs');

const command = isWindows ? 'powershell.exe' : 'node';
const args = isWindows ? ['-ExecutionPolicy', 'Bypass', '-File', scriptPath] : [scriptPath];

console.log(`🔍 Running DNS check for ${platform()}...`);
console.log('');

// Spawn the appropriate script
const child = spawn(command, args, {
  stdio: 'inherit',
  shell: false,
});

child.on('error', (error) => {
  console.error('❌ Failed to run DNS check:', error.message);
  process.exit(1);
});

child.on('exit', (code) => {
  process.exit(code || 0);
});
