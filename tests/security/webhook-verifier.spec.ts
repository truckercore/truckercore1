import * as crypto from 'crypto';
import { WebhookVerifier } from '../../electron/security/webhook_verifier';

describe('WebhookVerifier', () => {
  let verifier: WebhookVerifier;

  beforeEach(() => {
    process.env.SAMSARA_WEBHOOK_SECRET = 'test-secret-123';
    process.env.MOTIVE_WEBHOOK_SECRET = 'motive-secret-456';
    process.env.STRIPE_WEBHOOK_SECRET = 'stripe-secret-789';
    verifier = new WebhookVerifier();
  });

  describe('HMAC verification', () => {
    it('verifies a valid HMAC-SHA256 signature', () => {
      const payload = JSON.stringify({ event: 'vehicle.location.updated' });
      const h = crypto.createHmac('sha256', 'test-secret-123');
      h.update(payload);
      const sig = h.digest('hex');
      expect(verifier.verify('samsara', payload, sig)).toBe(true);
    });

    it('rejects invalid signature', () => {
      const payload = JSON.stringify({ event: 'vehicle.location.updated' });
      expect(verifier.verify('samsara', payload, 'bad')).toBe(false);
    });

    it('rejects tampered payload', () => {
      const payload = JSON.stringify({ event: 'vehicle.location.updated' });
      const h = crypto.createHmac('sha256', 'test-secret-123');
      h.update(payload);
      const sig = h.digest('hex');
      const tampered = JSON.stringify({ event: 'vehicle.location.updated', hacked: true });
      expect(verifier.verify('samsara', tampered, sig)).toBe(false);
    });
  });

  describe('Timestamp replay protection', () => {
    it('accepts a recent timestamp', () => {
      const payload = JSON.stringify({ test: 1 });
      const sig = verifier.generateSignature('samsara', payload)!;
      const ts = Math.floor(Date.now() / 1000).toString();
      expect(verifier.verify('samsara', payload, sig, ts)).toBe(true);
    });

    it('rejects an old timestamp', () => {
      const payload = JSON.stringify({ test: 1 });
      const sig = verifier.generateSignature('samsara', payload)!;
      const old = Math.floor((Date.now() - 10 * 60 * 1000) / 1000).toString();
      expect(verifier.verify('samsara', payload, sig, old)).toBe(false);
    });

    it('rejects a future timestamp', () => {
      const payload = JSON.stringify({ test: 1 });
      const sig = verifier.generateSignature('samsara', payload)!;
      const future = Math.floor((Date.now() + 10 * 60 * 1000) / 1000).toString();
      expect(verifier.verify('samsara', payload, sig, future)).toBe(false);
    });
  });

  describe('Signature generation', () => {
    it('generates a valid signature for testing', () => {
      const payload = JSON.stringify({ hello: 'world' });
      const sig = verifier.generateSignature('samsara', payload);
      expect(sig).toBeTruthy();
      expect(sig).toMatch(/^[a-f0-9]{64}$/);
      expect(verifier.verify('samsara', payload, sig!)).toBe(true);
    });
  });
});
