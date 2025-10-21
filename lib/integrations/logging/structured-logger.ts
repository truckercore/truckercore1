// Lightweight structured logger that prefers winston if available, else falls back to console
// and always applies PII redaction.

import { PIIRedactor } from './log-redactor';

// dynamic winston import (optional)
let winston: any = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  winston = require('winston');
} catch {}

const redactor = new PIIRedactor();

function makeLogger() {
  if (winston) {
    return winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: { service: 'fleet-integration' },
      transports: [new winston.transports.Console()],
    });
  }
  // fallback minimal logger
  return {
    info: (msg: string, obj?: any) => console.log(JSON.stringify({ level: 'info', msg, ...obj })),
    error: (msg: string, obj?: any) => console.error(JSON.stringify({ level: 'error', msg, ...obj })),
  } as any;
}

export const logger = makeLogger();

export function logRequest(vendor: string, operation: string, metadata: Record<string, any> = {}): void {
  logger.info('api_request', { vendor, operation, ...redactor.redact(metadata) });
}

export function logResponse(
  vendor: string,
  operation: string,
  status: number,
  durationMs: number,
  metadata: Record<string, any> = {}
): void {
  logger.info('api_response', { vendor, operation, status, duration_ms: durationMs, ...redactor.redact(metadata) });
}

export function logError(vendor: string, operation: string, error: Error, metadata: Record<string, any> = {}): void {
  logger.error('api_error', { vendor, operation, error: error.message, stack: (error as any)?.stack, ...redactor.redact(metadata) });
}
