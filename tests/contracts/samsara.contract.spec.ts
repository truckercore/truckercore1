import nock from 'nock';

// Mock electron to avoid native module requirements in unit tests
jest.mock('electron', () => ({
  ipcMain: { handle: jest.fn(), on: jest.fn() },
  Notification: function () {},
}));

import { SamsaraIntegration } from '../../electron/integrations/samsara-integration';

describe('Samsara API Contract', () => {
  let samsara: SamsaraIntegration;
  const SAMSARA_BASE_URL = 'https://api.samsara.com';

  beforeEach(() => {
    samsara = new SamsaraIntegration({ apiKey: 'test-api-key', baseURL: SAMSARA_BASE_URL });
  });

  afterEach(() => {
    nock.cleanAll();
  });

  describe('Vehicle Locations Endpoint', () => {
    it('should handle successful response', async () => {
      const mockResponse = {
        data: [
          {
            id: 'vehicle123',
            name: 'Truck 001',
            vin: '1HGBH41JXMN109186',
            location: {
              latitude: 37.7749,
              longitude: -122.4194,
              time: '2025-10-01T12:00:00Z',
              speedMilesPerHour: 55,
              heading: 180,
              reverseGeo: { formattedLocation: 'San Francisco, CA' },
            },
          },
        ],
      } as any;

      nock(SAMSARA_BASE_URL).get('/fleet/vehicles/locations').query({ types: 'current' }).reply(200, mockResponse);

      const locations = await samsara.getVehicleLocations();
      expect(locations).toHaveLength(1);
      expect(locations[0]).toMatchObject({
        vehicleId: 'vehicle123',
        name: 'Truck 001',
        latitude: 37.7749,
        longitude: -122.4194,
      });
    });

    it('should handle rate limit response (429)', async () => {
      nock(SAMSARA_BASE_URL)
        .get('/fleet/vehicles/locations')
        .query({ types: 'current' })
        .reply(429, { error: 'Too Many Requests' }, {
          'X-RateLimit-Limit': '1000',
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Reset': String(Math.floor(Date.now() / 1000) + 60),
          'Retry-After': '60',
        });

      await expect(samsara.getVehicleLocations()).rejects.toThrow();
    });

    it('should handle authentication error (401)', async () => {
      nock(SAMSARA_BASE_URL).get('/fleet/vehicles/locations').query({ types: 'current' }).reply(401, { error: 'Unauthorized' });
      await expect(samsara.getVehicleLocations()).rejects.toThrow('Unauthorized');
    });

    it('should handle server error (500)', async () => {
      nock(SAMSARA_BASE_URL).get('/fleet/vehicles/locations').query({ types: 'current' }).reply(500, { error: 'Internal Server Error' });
      await expect(samsara.getVehicleLocations()).rejects.toThrow();
    });
  });

  describe('Driver HOS Endpoint', () => {
    it('should parse HOS data correctly', async () => {
      const mockResponse = {
        data: [
          {
            driver: { id: 'driver123', name: 'John Doe' },
            currentDutyStatus: 'driving',
            driveRemaining: 28800000,
            shiftRemaining: 50400000,
            cycleRemaining: 252000000,
            timeUntilBreak: 1800000,
          },
        ],
      } as any;

      nock(SAMSARA_BASE_URL).get('/fleet/drivers/driver123/hos_daily_logs').reply(200, mockResponse);

      const hos = await samsara.getDriverHOS('driver123');
      expect(hos).toMatchObject({
        driverId: 'driver123',
        driverName: 'John Doe',
        timeUntilBreak: 30,
        driveTimeRemaining: 480,
        shiftTimeRemaining: 840,
      });
    });
  });
});
