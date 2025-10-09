#!/usr/bin/env ts-node

/**
 * Interactive Integration Configuration Script
 * Guides user through setting up all vendor integrations by writing to .env
 */

import * as readline from 'readline';
import * as fs from 'fs';
import * as path from 'path';
import chalk from 'chalk';

interface Integration {
  name: string;
  required: boolean;
  envVars: Array<{
    key: string;
    description: string;
    secret: boolean;
    default?: string;
  }>;
}

const INTEGRATIONS: Integration[] = [
  {
    name: 'Supabase',
    required: true,
    envVars: [
      { key: 'SUPABASE_URL', description: 'Supabase project URL', secret: false },
      { key: 'SUPABASE_ANON', description: 'Supabase anon/public key', secret: true },
    ],
  },
  {
    name: 'Samsara',
    required: false,
    envVars: [
      { key: 'SAMSARA_API_KEY', description: 'Samsara API token', secret: true },
      { key: 'SAMSARA_BASE_URL', description: 'Samsara API base URL', secret: false, default: 'https://api.samsara.com' },
    ],
  },
  {
    name: 'Motive',
    required: false,
    envVars: [
      { key: 'MOTIVE_API_KEY', description: 'Motive API key', secret: true },
      { key: 'MOTIVE_BASE_URL', description: 'Motive API base URL', secret: false, default: 'https://api.gomotive.com/v1' },
    ],
  },
  {
    name: 'DAT Load Board',
    required: false,
    envVars: [
      { key: 'DAT_API_KEY', description: 'DAT API key', secret: true },
      { key: 'DAT_CUSTOMER_ID', description: 'DAT customer ID', secret: false },
      { key: 'DAT_BASE_URL', description: 'DAT API base URL', secret: false, default: 'https://freight.api.dat.com/v2' },
    ],
  },
  {
    name: 'Trimble Maps',
    required: false,
    envVars: [
      { key: 'TRIMBLE_API_KEY', description: 'Trimble API key', secret: true },
      { key: 'TRIMBLE_BASE_URL', description: 'Trimble API base URL', secret: false, default: 'https://pcmiler.alk.com/apis/rest/v1.0' },
    ],
  },
  {
    name: 'Geotab',
    required: false,
    envVars: [
      { key: 'GEOTAB_USERNAME', description: 'Geotab username', secret: false },
      { key: 'GEOTAB_PASSWORD', description: 'Geotab password', secret: true },
      { key: 'GEOTAB_DATABASE', description: 'Geotab database name', secret: false },
      { key: 'GEOTAB_SERVER', description: 'Geotab server', secret: false, default: 'my.geotab.com' },
    ],
  },
  {
    name: 'Twilio (SMS)',
    required: false,
    envVars: [
      { key: 'TWILIO_ACCOUNT_SID', description: 'Twilio account SID', secret: true },
      { key: 'TWILIO_AUTH_TOKEN', description: 'Twilio auth token', secret: true },
      { key: 'TWILIO_PHONE_NUMBER', description: 'Twilio phone number (e.g., +1234567890)', secret: false },
    ],
  },
  {
    name: 'SendGrid (Email)',
    required: false,
    envVars: [
      { key: 'SENDGRID_API_KEY', description: 'SendGrid API key', secret: true },
      { key: 'SENDGRID_FROM_EMAIL', description: 'From email address', secret: false, default: 'noreply@truckercore.com' },
    ],
  },
];

class ConfigurationWizard {
  private rl: readline.Interface;
  private envData: Map<string, string> = new Map();
  private envPath: string;

  constructor() {
    this.rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    this.envPath = path.join(process.cwd(), '.env');
  }

  async run(): Promise<void> {
    console.log(chalk.cyan.bold('\n🚀 TruckerCore Integration Configuration\n'));
    console.log(chalk.gray('This wizard will help you configure all vendor integrations.\n'));

    this.loadExistingEnv();

    for (const integration of INTEGRATIONS) {
      await this.configureIntegration(integration);
    }

    await this.saveEnv();

    console.log(chalk.green.bold('\n✅ Configuration complete!\n'));
    console.log(chalk.gray('Your credentials have been saved to .env\n'));
    console.log(chalk.yellow('Next steps:'));
    console.log(chalk.gray('  1. Run: npm run migrate'));
    console.log(chalk.gray('  2. Run: npm run test:integration'));
    console.log(chalk.gray('  3. Run: npm run electron:dev\n'));

    this.rl.close();
  }

  private loadExistingEnv(): void {
    if (fs.existsSync(this.envPath)) {
      const content = fs.readFileSync(this.envPath, 'utf8');
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) continue;
        const eq = trimmed.indexOf('=');
        if (eq === -1) continue;
        const key = trimmed.slice(0, eq).trim();
        const value = trimmed.slice(eq + 1).trim();
        if (key) this.envData.set(key, value);
      }
      console.log(chalk.gray('Loaded existing configuration from .env\n'));
    }
  }

  private async configureIntegration(integration: Integration): Promise<void> {
    console.log(chalk.cyan.bold(`\n📦 ${integration.name}`));
    if (integration.required) console.log(chalk.red('   (Required)'));

    const shouldConfigure = await this.question(chalk.white(`\nConfigure ${integration.name}? (y/n): `));
    if (shouldConfigure.toLowerCase() !== 'y') {
      console.log(chalk.gray('   Skipped'));
      return;
    }

    for (const envVar of integration.envVars) {
      const existing = this.envData.get(envVar.key);
      const defaultValue = existing || envVar.default || '';
      let prompt = chalk.white(`${envVar.description}`);
      if (defaultValue) {
        if (envVar.secret) prompt += chalk.gray(' (current: ***)');
        else prompt += chalk.gray(` (current: ${defaultValue})`);
      }
      prompt += chalk.white(': ');
      const value = await this.question(prompt);
      if (value.trim()) this.envData.set(envVar.key, value.trim());
      else if (defaultValue) this.envData.set(envVar.key, defaultValue);
    }

    console.log(chalk.green(`   ✓ ${integration.name} configured`));
  }

  private async saveEnv(): Promise<void> {
    let content = '# TruckerCore Environment Configuration\n';
    content += '# Generated: ' + new Date().toISOString() + '\n\n';
    content += 'NODE_ENV=development\n';
    content += 'APP_VERSION=1.0.0\n\n';

    const groups = new Map<string, string[]>();
    for (const [key, value] of this.envData) {
      const prefix = key.split('_')[0];
      if (!groups.has(prefix)) groups.set(prefix, []);
      groups.get(prefix)!.push(`${key}=${value}`);
    }

    for (const [prefix, lines] of groups) {
      content += `# ${prefix}\n`;
      content += lines.join('\n') + '\n\n';
    }

    fs.writeFileSync(this.envPath, content);
    try { fs.chmodSync(this.envPath, 0o600); } catch { /* ignore on Windows */ }
    console.log(chalk.green(`\n✓ Configuration saved to ${this.envPath}`));
  }

  private question(prompt: string): Promise<string> {
    return new Promise((resolve) => this.rl.question(prompt, (answer) => resolve(answer)));
  }
}

(async () => {
  const wizard = new ConfigurationWizard();
  try {
    await wizard.run();
  } catch (err) {
    console.error(chalk.red('\n❌ Configuration failed:'), err);
    process.exit(1);
  }
})();
