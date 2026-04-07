import * as crypto from 'crypto';
import type { Request } from 'express';

/**
 * Webhook Signature Verification
 *
 * Supports:
 * - HMAC-SHA256 and HMAC-SHA512
 * - Ed25519 (public key provided as hex or PEM)
 * - Optional timestamp-based replay protection
 */
export type WebhookAlgo = 'hmac-sha256' | 'hmac-sha512' | 'ed25519';

export interface WebhookConfig {
  vendor: string;
  secret: string; // HMAC secret or Ed25519 public key
  algorithm: WebhookAlgo;
  headerName: string; // header that carries signature value
  timestampHeaderName?: string; // header that carries UNIX ts (seconds)
  timestampToleranceSeconds?: number; // default 300
}

export class WebhookVerifier {
  private configs: Map<string, WebhookConfig> = new Map();

  constructor(initDefaults = true) {
    if (initDefaults) this.initializeVendorConfigs();
  }

  private initializeVendorConfigs() {
    // Samsara
    this.configs.set('samsara', {
      vendor: 'samsara',
      secret: process.env.SAMSARA_WEBHOOK_SECRET || '',
      algorithm: 'hmac-sha256',
      headerName: 'X-Samsara-Signature',
      timestampHeaderName: 'X-Samsara-Timestamp',
      timestampToleranceSeconds: 300,
    });
    // Motive
    this.configs.set('motive', {
      vendor: 'motive',
      secret: process.env.MOTIVE_WEBHOOK_SECRET || '',
      algorithm: 'hmac-sha256',
      headerName: 'X-Motive-Signature',
      timestampHeaderName: 'X-Motive-Timestamp',
      timestampToleranceSeconds: 300,
    });
    // Stripe (many accounts still use HMAC based signing secrets delivered as whsec_...)
    this.configs.set('stripe', {
      vendor: 'stripe',
      secret: process.env.STRIPE_WEBHOOK_SECRET || '',
      algorithm: 'hmac-sha256',
      headerName: 'Stripe-Signature',
      timestampToleranceSeconds: 300,
    });
  }

  setConfig(cfg: WebhookConfig) {
    this.configs.set(cfg.vendor.toLowerCase(), cfg);
  }

  getConfig(vendor: string): WebhookConfig | undefined {
    return this.configs.get(vendor.toLowerCase());
  }

  /** Verify Express request (req.body must be raw Buffer) */
  verifyRequest(vendor: string, req: Request): boolean {
    const cfg = this.getConfig(vendor);
    if (!cfg) return false;

    // headers are case-insensitive; Node lowercases keys
    const sigHeader = (req.headers[cfg.headerName.toLowerCase()] || req.headers[cfg.headerName]) as string | undefined;
    const tsHeader = cfg.timestampHeaderName
      ? ((req.headers[cfg.timestampHeaderName.toLowerCase()] || req.headers[cfg.timestampHeaderName]) as string | undefined)
      : undefined;

    if (!sigHeader) {
      // eslint-disable-next-line no-console
      console.error(`[Webhook] Missing signature header: ${cfg.headerName}`);
      return false;
    }

    const payload: Buffer | string = (req as any).body; // should be raw Buffer
    return this.verify(vendor, payload, sigHeader, tsHeader);
  }

  /** Core verification */
  verify(vendor: string, payload: string | Buffer, signature: string, timestamp?: string): boolean {
    const cfg = this.getConfig(vendor);
    if (!cfg) {
      // eslint-disable-next-line no-console
      console.error(`[Webhook] No config for vendor: ${vendor}`);
      return false;
    }
    if (!cfg.secret) {
      // eslint-disable-next-line no-console
      console.error(`[Webhook] No secret configured for vendor: ${vendor}`);
      return false;
    }

    // Timestamp replay protection
    if (timestamp && cfg.timestampToleranceSeconds) {
      if (!this.validateTimestamp(timestamp, cfg.timestampToleranceSeconds)) {
        // eslint-disable-next-line no-console
        console.warn(`[Webhook] Timestamp validation failed for ${vendor}`);
        return false;
      }
    }

    try {
      switch (cfg.algorithm) {
        case 'hmac-sha256':
          return this.verifyHmac(payload, signature, cfg.secret, 'sha256');
        case 'hmac-sha512':
          return this.verifyHmac(payload, signature, cfg.secret, 'sha512');
        case 'ed25519':
          return this.verifyEd25519(payload, signature, cfg.secret);
        default:
          // eslint-disable-next-line no-console
          console.error(`[Webhook] Unsupported algorithm: ${cfg.algorithm}`);
          return false;
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(`[Webhook] Verification error for ${vendor}:`, e);
      return false;
    }
  }

  /** Generate HMAC signature for testing */
  generateSignature(vendor: string, payload: string | Buffer): string | null {
    const cfg = this.getConfig(vendor);
    if (!cfg || !cfg.secret) return null;
    if (cfg.algorithm.startsWith('hmac-')) {
      const algo = cfg.algorithm.replace('hmac-', '') as 'sha256' | 'sha512';
      const h = crypto.createHmac(algo, cfg.secret);
      h.update(payload);
      return h.digest('hex');
    }
    return null;
  }

  private verifyHmac(payload: string | Buffer, signature: string, secret: string, algo: 'sha256' | 'sha512'): boolean {
    const clean = signature.replace(/^(sha256|sha512)=/i, '');
    const h = crypto.createHmac(algo, secret);
    h.update(payload);
    const expected = h.digest('hex');
    const a = Buffer.from(clean, 'hex');
    const b = Buffer.from(expected, 'hex');
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  }

  /**
   * Verify Ed25519 signatures.
   * Accepts public key as hex (32 bytes) or PEM SPKI.
   * Signature must be hex (64 bytes).
   */
  private verifyEd25519(payload: string | Buffer, signatureHex: string, publicKey: string): boolean {
    const payloadBuf = Buffer.isBuffer(payload) ? payload : Buffer.from(payload, 'utf8');
    const sigBuf = Buffer.from(signatureHex, 'hex');

    try {
      // If key looks like PEM, use directly
      if (/-----BEGIN PUBLIC KEY-----/.test(publicKey)) {
        return crypto.verify(null, payloadBuf, publicKey, sigBuf);
      }
      // Otherwise treat as raw 32-byte hex public key and wrap into SPKI DER
      const pubRaw = Buffer.from(publicKey, 'hex');
      if (pubRaw.length !== 32) throw new Error('Invalid Ed25519 public key length');
      const spkiDer = this.rawEd25519PublicKeyToSpki(pubRaw);
      return crypto.verify(null, payloadBuf, { key: spkiDer, format: 'der', type: 'spki' } as any, sigBuf);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('[Webhook] Ed25519 verification error:', e);
      return false;
    }
  }

  private validateTimestamp(ts: string, toleranceSeconds: number): boolean {
    const requestTime = parseInt(ts, 10);
    if (!Number.isFinite(requestTime)) return false;
    const now = Math.floor(Date.now() / 1000);
    return Math.abs(now - requestTime) <= toleranceSeconds;
  }

  // Construct minimal SPKI for Ed25519 raw public key (RFC 8410)
  private rawEd25519PublicKeyToSpki(raw: Buffer): Buffer {
    // ASN.1 DER for: SubjectPublicKeyInfo { algorithm: Ed25519 OID 1.3.101.112, subjectPublicKey: BIT STRING (raw) }
    // Precomputed header for Ed25519 SPKI with 32-byte key
    // 0x30 len  -> SEQUENCE
    //   0x30 5  -> SEQUENCE (alg id)
    //     0x06 3 2B6570 -> OID 1.3.101.112
    //   0x03 42 00 <32-byte key> -> BIT STRING
    const oid = Buffer.from([0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70]);
    const bitString = Buffer.concat([Buffer.from([0x03, 0x22, 0x00]), raw]);
    const seqInner = Buffer.concat([oid, bitString]);
    const spki = Buffer.concat([Buffer.from([0x30, seqInner.length]), seqInner]);
    return spki;
  }
}
