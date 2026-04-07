export interface RedactionRule {
  pattern: RegExp;
  replacement: string;
}

export class PIIRedactor {
  private readonly rules: RedactionRule[] = [
    // Authorization headers
    { pattern: /authorization:\s*[^\s,}]+/gi, replacement: 'authorization: [REDACTED]' },
    { pattern: /"authorization":\s*"[^"]+"/gi, replacement: '"authorization": "[REDACTED]"' },
    { pattern: /bearer\s+[a-zA-Z0-9._-]+/gi, replacement: 'bearer [REDACTED]' },

    // API keys
    { pattern: /api[_-]?key['":\s]+[a-zA-Z0-9_-]+/gi, replacement: 'api_key: [REDACTED]' },
    { pattern: /x-api-key['":\s]+[a-zA-Z0-9_-]+/gi, replacement: 'x-api-key: [REDACTED]' },

    // SSN
    { pattern: /\b\d{3}-\d{2}-\d{4}\b/g, replacement: 'XXX-XX-XXXX' },

    // Email
    { pattern: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, replacement: '[EMAIL_REDACTED]' },

    // Phone numbers
    { pattern: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/g, replacement: 'XXX-XXX-XXXX' },

    // Credit card numbers
    { pattern: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, replacement: 'XXXX-XXXX-XXXX-XXXX' },

    // Driver license (common patterns)
    { pattern: /\b[A-Z]{1,2}\d{6,8}\b/g, replacement: '[DL_REDACTED]' },
  ];

  redact(input: any): any {
    if (typeof input === 'string') {
      return this.redactString(input);
    }
    if (Array.isArray(input)) {
      return input.map((item) => this.redact(item));
    }
    if (input && typeof input === 'object') {
      const redacted: any = {};
      for (const [key, value] of Object.entries(input)) {
        if (this.isSensitiveKey(key)) redacted[key] = '[REDACTED]';
        else redacted[key] = this.redact(value);
      }
      return redacted;
    }
    return input;
  }

  private redactString(str: string): string {
    let result = str;
    for (const rule of this.rules) result = result.replace(rule.pattern, rule.replacement);
    return result;
  }

  private isSensitiveKey(key: string): boolean {
    const sensitive = [
      'password',
      'token',
      'secret',
      'api_key',
      'apikey',
      'authorization',
      'ssn',
      'social_security',
      'credit_card',
      'creditcard',
      'cvv',
      'pin',
      'access_token',
      'refresh_token',
    ];
    const lower = key.toLowerCase();
    return sensitive.some((s) => lower.includes(s));
  }
}
