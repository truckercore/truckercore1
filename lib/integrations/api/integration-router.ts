import express, { Request, Response, NextFunction } from 'express';
import { DATAdapter } from '../adapters/dat-adapter';
import { TrimbleAdapter } from '../adapters/trimble-adapter';
import { SamsaraAdapter } from '../adapters/samsara-adapter';
import { IdempotencyManager } from '../core/idempotency';
import { PersistentRetryQueue } from '../core/retry-queue';
import { IntegrationFlagManager } from '../feature-flags/integration-flags';
import { metrics } from '../observability/metrics';
import { HealthChecker } from '../observability/health-checks';
import { logger } from '../logging/structured-logger';
import { z } from 'zod';

export interface IntegrationRouterConfig {
  datAdapter: DATAdapter;
  trimbleAdapter: TrimbleAdapter;
  samsaraAdapter: SamsaraAdapter;
  idempotencyManager: IdempotencyManager;
  retryQueue: PersistentRetryQueue;
  flagManager: IntegrationFlagManager;
  healthChecker: HealthChecker;
}

// Request validation schemas
const LoadSearchSchema = z.object({
  origin: z
    .object({
      city: z.string().optional(),
      state: z.string().optional(),
      radius: z.number().optional(),
    })
    .optional(),
  destination: z
    .object({
      city: z.string().optional(),
      state: z.string().optional(),
      radius: z.number().optional(),
    })
    .optional(),
  equipmentType: z.string().optional(),
  pickupDateStart: z.string().optional(),
  pickupDateEnd: z.string().optional(),
  maxAge: z.number().optional(),
  limit: z.number().max(100).optional(),
});

const RouteRequestSchema = z.object({
  origin: z.object({
    lat: z.number(),
    lon: z.number(),
  }),
  destination: z.object({
    lat: z.number(),
    lon: z.number(),
  }),
  stops: z
    .array(
      z.object({
        lat: z.number(),
        lon: z.number(),
      }),
    )
    .optional(),
  vehicleProfile: z.object({
    type: z.literal('truck'),
    width: z.number().optional(),
    height: z.number().optional(),
    length: z.number().optional(),
    weight: z.number().optional(),
    axles: z.number().optional(),
    hazmat: z.boolean().optional(),
  }),
  options: z
    .object({
      avoidTolls: z.boolean().optional(),
      routeOptimization: z.enum(['fastest', 'shortest']).optional(),
    })
    .optional(),
});

export function createIntegrationRouter(config: IntegrationRouterConfig): express.Router {
  const router = express.Router();

  // Middleware: Extract tenant ID from header or token
  const extractTenantId = (req: Request, res: Response, next: NextFunction) => {
    const tenantId = req.headers['x-tenant-id'] as string;
    (req as any).tenantId = tenantId;
    next();
  };

  // Middleware: Check if vendor is enabled
  const checkVendorEnabled = (vendor: 'DAT' | 'TRIMBLE' | 'SAMSARA') => {
    return (req: Request, res: Response, next: NextFunction) => {
      const tenantId = (req as any).tenantId;
      const flagKey = `${vendor.toLowerCase()}Enabled` as keyof any;
      
      if (!config.flagManager.isEnabled(flagKey, tenantId)) {
        logger.warn('vendor_disabled', { vendor, tenantId });
        return res.status(503).json({
          error: 'Service Unavailable',
          message: `${vendor} integration is currently disabled`,
          vendor,
        });
      }
      next();
    };
  };

  // Middleware: Check write operations enabled
  const checkWriteEnabled = (req: Request, res: Response, next: NextFunction) => {
    const tenantId = (req as any).tenantId;
    
    if (!config.flagManager.isEnabled('allWriteOperationsEnabled', tenantId)) {
      return res.status(503).json({
        error: 'Service Unavailable',
        message: 'Write operations are currently disabled',
      });
    }
    next();
  };

  // Apply tenant extraction to all routes
  router.use(extractTenantId);

  // ============ DAT Routes ============

  router.get(
    '/dat/loads/search',
    checkVendorEnabled('DAT'),
    async (req: Request, res: Response) => {
      const tenantId = (req as any).tenantId;
      
      try {
        const params = LoadSearchSchema.parse(req.query);

        const loads = await config.datAdapter.searchLoads(params);

        metrics.recordRequest('DAT', 'search_loads', 'success');

        res.json({
          success: true,
          data: loads,
          count: loads.length,
        });
      } catch (error: any) {
        metrics.recordRequest('DAT', 'search_loads', 'failure');
        metrics.recordError('DAT', 'search_loads', error.name);
        
        logger.error('dat_search_error', { error: error.message, tenantId });

        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message,
        });
      }
    },
  );

  router.get(
    '/dat/loads/:loadId',
    checkVendorEnabled('DAT'),
    async (req: Request, res: Response) => {
      try {
        const { loadId } = req.params;
        const load = await config.datAdapter.getLoad(loadId);

        metrics.recordRequest('DAT', 'get_load', 'success');

        res.json({
          success: true,
          data: load,
        });
      } catch (error: any) {
        metrics.recordRequest('DAT', 'get_load', 'failure');
        res.status(error.response?.status || 500).json({
          error: 'Error fetching load',
          message: error.message,
        });
      }
    },
  );

  router.post(
    '/dat/loads',
    checkVendorEnabled('DAT'),
    checkWriteEnabled,
    async (req: Request, res: Response) => {
      const tenantId = (req as any).tenantId;

      try {
        // Generate idempotency key
        const idempotencyKey = config.idempotencyManager.generateKey(
          'DAT',
          'post_load',
          req.body,
        );

        const result = await config.idempotencyManager.execute(
          idempotencyKey,
          async () => {
            return await config.datAdapter.postLoad(req.body);
          },
          86400, // 24 hour TTL
        );

        metrics.recordRequest('DAT', 'post_load', 'success');

        res.status(result.cached ? 200 : 201).json({
          success: true,
          data: result.result,
          cached: result.cached,
        });
      } catch (error: any) {
        metrics.recordRequest('DAT', 'post_load', 'failure');

        // If vendor is down, queue for retry
        if (error.name === 'VendorServerError' || error.name === 'CircuitOpenError') {
          const jobId = await config.retryQueue.enqueue({
            vendor: 'DAT',
            operation: 'post_load',
            payload: req.body,
            maxAttempts: 5,
            nextRetry: Date.now() + 5000,
          });

          logger.info('load_queued_for_retry', { jobId, tenantId });

          return res.status(202).json({
            success: false,
            message: 'Request queued for retry',
            jobId,
          });
        }

        res.status(500).json({
          error: 'Error posting load',
          message: error.message,
        });
      }
    },
  );

  // ============ Trimble Routes ============

  router.post(
    '/trimble/route',
    checkVendorEnabled('TRIMBLE'),
    async (req: Request, res: Response) => {
      try {
        const routeRequest = RouteRequestSchema.parse(req.body);

        const route = await config.trimbleAdapter.calculateRoute(routeRequest);

        metrics.recordRequest('TRIMBLE', 'calculate_route', 'success');

        res.json({
          success: true,
          data: route,
        });
      } catch (error: any) {
        metrics.recordRequest('TRIMBLE', 'calculate_route', 'failure');
        
        res.status(500).json({
          error: 'Error calculating route',
          message: error.message,
        });
      }
    },
  );

  router.get(
    '/trimble/geocode',
    checkVendorEnabled('TRIMBLE'),
    async (req: Request, res: Response) => {
      try {
        const { address } = req.query;
        
        if (!address || typeof address !== 'string') {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Address parameter is required',
          });
        }

        const location = await config.trimbleAdapter.geocode(address);

        metrics.recordRequest('TRIMBLE', 'geocode', 'success');

        res.json({
          success: true,
          data: location,
        });
      } catch (error: any) {
        metrics.recordRequest('TRIMBLE', 'geocode', 'failure');
        
        res.status(500).json({
          error: 'Error geocoding address',
          message: error.message,
        });
      }
    },
  );

  router.get(
    '/trimble/restrictions',
    checkVendorEnabled('TRIMBLE'),
    async (req: Request, res: Response) => {
      try {
        const { lat, lon, radius } = req.query;

        if (!lat || !lon) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'lat and lon parameters are required',
          });
        }

        const restrictions = await config.trimbleAdapter.getTruckRestrictions(
          parseFloat(lat as string),
          parseFloat(lon as string),
          radius ? parseInt(radius as string) : 5000,
        );

        metrics.recordRequest('TRIMBLE', 'get_restrictions', 'success');

        res.json({
          success: true,
          data: restrictions,
        });
      } catch (error: any) {
        metrics.recordRequest('TRIMBLE', 'get_restrictions', 'failure');
        
        res.status(500).json({
          error: 'Error fetching restrictions',
          message: error.message,
        });
      }
    },
  );

  // ============ Samsara Routes ============

  router.get(
    '/samsara/vehicles',
    checkVendorEnabled('SAMSARA'),
    async (req: Request, res: Response) => {
      try {
        const vehicles = await config.samsaraAdapter.listVehicles();

        metrics.recordRequest('SAMSARA', 'list_vehicles', 'success');

        res.json({
          success: true,
          data: vehicles,
          count: vehicles.length,
        });
      } catch (error: any) {
        metrics.recordRequest('SAMSARA', 'list_vehicles', 'failure');
        
        res.status(500).json({
          error: 'Error fetching vehicles',
          message: error.message,
        });
      }
    },
  );

  router.get(
    '/samsara/vehicles/:vehicleId',
    checkVendorEnabled('SAMSARA'),
    async (req: Request, res: Response) => {
      try {
        const { vehicleId } = req.params;
        const vehicle = await config.samsaraAdapter.syncVehicleToCanonical(vehicleId);

        metrics.recordRequest('SAMSARA', 'get_vehicle', 'success');

        res.json({
          success: true,
          data: vehicle,
        });
      } catch (error: any) {
        metrics.recordRequest('SAMSARA', 'get_vehicle', 'failure');
        
        res.status(error.response?.status || 500).json({
          error: 'Error fetching vehicle',
          message: error.message,
        });
      }
    },
  );

  router.get(
    '/samsara/vehicles/locations/bulk',
    checkVendorEnabled('SAMSARA'),
    async (req: Request, res: Response) => {
      try {
        const { vehicleIds } = req.query;

        if (!vehicleIds || typeof vehicleIds !== 'string') {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'vehicleIds parameter is required',
          });
        }

        const ids = vehicleIds.split(',');
        const locations = await config.samsaraAdapter.getVehicleLocations(ids);

        metrics.recordRequest('SAMSARA', 'bulk_locations', 'success');

        res.json({
          success: true,
          data: locations,
          count: locations.length,
        });
      } catch (error: any) {
        metrics.recordRequest('SAMSARA', 'bulk_locations', 'failure');
        
        res.status(500).json({
          error: 'Error fetching locations',
          message: error.message,
        });
      }
    },
  );

  // ============ Health & Metrics ============

  router.get('/health', async (req: Request, res: Response) => {
    const results = await config.healthChecker.checkAll();
    
    const allHealthy = results.every((r) => r.healthy);
    const status = allHealthy ? 200 : 503;

    res.status(status).json({
      healthy: allHealthy,
      checks: results,
      timestamp: new Date().toISOString(),
    });
  });

  router.get('/metrics', async (req: Request, res: Response) => {
    res.set('Content-Type', 'text/plain');
    res.send(await metrics.getMetrics());
  });

  router.get('/status', async (req: Request, res: Response) => {
    const queueSize = await config.retryQueue.getQueueSize();
    const dlqSize = await config.retryQueue.getDLQSize();

    metrics.updateQueueMetrics(queueSize, dlqSize);

    res.json({
      adapters: {
        dat: config.datAdapter.getMetrics(),
        trimble: config.trimbleAdapter.getMetrics(),
        samsara: config.samsaraAdapter.getMetrics(),
      },
      queue: {
        pending: queueSize,
        dlq: dlqSize,
      },
      flags: config.flagManager.getFlags((req as any).tenantId),
    });
  });

  // ============ Admin Routes (Feature Flags) ============

  router.post('/admin/flags', async (req: Request, res: Response) => {
    try {
      const { flags, tenantId } = req.body;

      if (tenantId) {
        config.flagManager.setTenantOverride(tenantId, flags);
      } else {
        config.flagManager.updateFlags(flags);
      }

      logger.info('flags_updated', { flags, tenantId });

      res.json({
        success: true,
        message: 'Feature flags updated',
      });
    } catch (error: any) {
      res.status(500).json({
        error: 'Error updating flags',
        message: error.message,
      });
    }
  });

  router.get('/admin/flags', (req: Request, res: Response) => {
    const { tenantId } = req.query;
    
    res.json({
      success: true,
      data: config.flagManager.getFlags(tenantId as string),
    });
  });

  return router;
}
