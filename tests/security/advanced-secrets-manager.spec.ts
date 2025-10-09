import { AdvancedSecretsManager } from '../../electron/security/advanced_secrets_manager';

// Mock Electron Notification/safeStorage in test env
jest.mock('electron', () => ({
  safeStorage: { isEncryptionAvailable: () => false },
  Notification: function () {},
  app: { getPath: () => process.cwd() },
}));

describe('AdvancedSecretsManager', () => {
  let mgr: AdvancedSecretsManager;

  beforeEach(() => {
    process.env.NODE_ENV = 'development';
    mgr = new AdvancedSecretsManager();
  });

  afterEach(() => {
    mgr.close();
  });

  describe('Secret Storage with Scopes', () => {
    it('stores secret with vendor scopes and allows access for granted scope', async () => {
      await mgr.setSecret('samsara_api_key', 'test-key-123', {
        type: 'api_key',
        vendor: 'samsara',
        environment: 'development',
        scopes: [
          {
            vendor: 'samsara',
            permissions: ['fleets.vehicles.location:read', 'fleets.drivers.hos:read'],
            environment: 'development',
          },
        ],
      });
      const secret = await mgr.getSecret('samsara_api_key', ['fleets.vehicles.location:read'], 'test', 'jest');
      expect(secret).toBe('test-key-123');
    });

    it('enforces least-privilege scopes', async () => {
      await mgr.setSecret('samsara_readonly', 'readonly-key', {
        type: 'api_key',
        vendor: 'samsara',
        environment: 'development',
        scopes: [
          { vendor: 'samsara', permissions: ['fleets.vehicles.location:read'], environment: 'development' },
        ],
      });
      await expect(
        mgr.getSecret('samsara_readonly', ['fleets.dispatch:write'], 'test', 'jest')
      ).rejects.toThrow('Insufficient permissions');
    });

    it('returns recommended scopes for vendor levels', () => {
      const read = mgr.getVendorScopes('samsara', 'read');
      expect(read).toContain('fleets.vehicles.location:read');
      const write = mgr.getVendorScopes('samsara', 'write');
      expect(write).toContain('fleets.dispatch:write');
    });
  });

  describe('Secret Rotation', () => {
    it('rotates secret and returns new version', async () => {
      await mgr.setSecret('test_key', 'version-1', { type: 'api_key', environment: 'development' });
      await mgr.rotateSecret('test_key', 'version-2', 'admin');
      const secret = await mgr.getSecret('test_key', [], 'test', 'jest');
      expect(secret).toBe('version-2');
      const status = mgr.getRotationStatus();
      const row = status.find((s) => s.key === 'test_key');
      expect(row).toBeTruthy();
    });

    it('reports overdue rotation with fake timers', async () => {
      jest.useFakeTimers();
      await mgr.setSecret('short_lived', 'v1', { type: 'oauth_token', environment: 'development', autoRotate: true });
      // Advance 8 days (oauth_token interval 7 days)
      jest.advanceTimersByTime(8 * 24 * 60 * 60 * 1000);
      const status = mgr.getRotationStatus();
      const row = status.find((s) => s.key === 'short_lived');
      expect(row && (row.status === 'warning' || row.status === 'overdue')).toBe(true);
      jest.useRealTimers();
    });
  });

  describe('Environment Isolation', () => {
    it('isolates secrets by environment', async () => {
      await mgr.setSecret('prod_key', 'prod-secret', { type: 'api_key', environment: 'production' });
      process.env.NODE_ENV = 'development';
      const secret = await mgr.getSecret('prod_key', [], 'test', 'jest');
      expect(secret).toBeNull();
    });
  });
});
