import nock from 'nock';

jest.mock('electron', () => ({ ipcMain: { handle: jest.fn(), on: jest.fn() } }));

import { MotiveIntegration } from '../../electron/integrations/motive-integration';

/**
 * Contract Tests for Motive API
 */

describe('Motive API Contract', () => {
  let motive: MotiveIntegration;
  const MOTIVE_BASE_URL = 'https://api.gomotive.com/v1';

  beforeEach(() => {
    motive = new MotiveIntegration({ apiKey: 'test-api-key', baseURL: MOTIVE_BASE_URL });
  });

  afterEach(() => {
    nock.cleanAll();
  });

  describe('DVIR Submission', () => {
    it('should submit DVIR with defects', async () => {
      const mockResponse = { id: 'dvir123', status: 'success' } as any;

      nock(MOTIVE_BASE_URL).post('/dvir').reply(201, mockResponse);

      const result = await motive.submitDVIR({
        driverId: 'driver123',
        vehicleId: 'vehicle456',
        status: 'defect',
        defects: [
          { component: 'brakes', description: 'Worn brake pads', severity: 'major' },
        ],
        odometer: 125000,
        location: 'Chicago, IL',
      });

      expect(result.success).toBe(true);
      expect(result.dvirId).toBe('dvir123');
    });
  });

  describe('IFTA Report', () => {
    it('should return jurisdictional data', async () => {
      const mockResponse = {
        vehicle_id: 'vehicle123',
        start_date: '2025-01-01',
        end_date: '2025-03-31',
        jurisdictions: [
          { state: 'IL', miles: 1500, gallons: 250 },
          { state: 'IN', miles: 800, gallons: 133 },
          { state: 'OH', miles: 600, gallons: 100 },
        ],
        total_miles: 2900,
        total_gallons: 483,
      } as any;

      nock(MOTIVE_BASE_URL)
        .get('/ifta/report')
        .query({ vehicle_id: 'vehicle123', start_date: '2025-01-01', end_date: '2025-03-31' })
        .reply(200, mockResponse);

      const report = await motive.getIFTAReport({ vehicleId: 'vehicle123', startDate: '2025-01-01', endDate: '2025-03-31' });

      expect(report.jurisdictions).toHaveLength(3);
      expect(report.total_miles).toBe(2900);
      expect(report.total_gallons).toBe(483);
    });
  });
});
