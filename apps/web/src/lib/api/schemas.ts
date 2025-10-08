import { z } from 'zod';

// HOS Schemas
export const HOSStatusSchema = z.enum(['off_duty', 'sleeper_berth', 'driving', 'on_duty_not_driving']);

export const LocationSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  address: z.string().optional(),
});

export const ChangeHOSStatusSchema = z.object({
  status: HOSStatusSchema,
  location: LocationSchema,
  timestamp: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
  notes: z.string().optional(),
});

export const LogViolationSchema = z.object({
  type: z.enum(['driving_limit', 'on_duty_window', 'cycle_limit', 'break_required', 'off_duty_required']),
  severity: z.enum(['warning', 'critical', 'violation']),
  message: z.string(),
  timestamp: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
  acknowledged: z.boolean().default(false),
});

// Location Tracking Schemas
export const LocationUpdateSchema = z.object({
  driverId: z.string().uuid(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracy: z.number().positive(),
  altitude: z.number().optional(),
  heading: z.number().min(0).max(360).optional(),
  speed: z.number().min(0).optional(),
  timestamp: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
  offline: z.boolean().default(false),
});

export const BatchLocationUpdateSchema = z.object({
  locations: z.array(LocationUpdateSchema).min(1).max(100),
});

// Load Management Schemas
export const LoadAcceptanceSchema = z.object({
  loadId: z.string().uuid(),
  driverId: z.string().uuid(),
  acceptedAt: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
  estimatedPickupTime: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val))
    .optional(),
});

export const LoadRejectionSchema = z.object({
  loadId: z.string().uuid(),
  reason: z.string().optional(),
});

export const UpdateStopStatusSchema = z.object({
  status: z.enum(['pending', 'arrived', 'completed', 'skipped']),
  timestamp: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
  notes: z.string().optional(),
});

export const ProofOfDeliverySchema = z.object({
  signature: z
    .object({
      dataUrl: z.string().startsWith('data:image/'),
      signedBy: z.string().min(1),
      timestamp: z
        .string()
        .datetime()
        .or(z.date())
        .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
    })
    .optional(),
  photos: z
    .array(
      z.object({
        id: z.string().uuid(),
        dataUrl: z.string().startsWith('data:image/'),
        caption: z.string().optional(),
        timestamp: z
          .string()
          .datetime()
          .or(z.date())
          .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
      })
    )
    .min(1),
  notes: z.string().optional(),
  deliveredTo: z.string().min(1),
  deliveryTime: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
  odometer: z.number().positive().optional(),
});

// Pagination Schema
export const PaginationSchema = z.object({
  page: z
    .string()
    .transform((val) => parseInt(val, 10))
    .pipe(z.number().int().positive())
    .default('1' as any) as unknown as z.ZodNumber,
  limit: z
    .string()
    .transform((val) => parseInt(val, 10))
    .pipe(z.number().int().positive().max(100))
    .default('20' as any) as unknown as z.ZodNumber,
});

// Query Schemas
export const DateRangeSchema = z.object({
  startDate: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
  endDate: z
    .string()
    .datetime()
    .or(z.date())
    .transform((val) => (typeof val === 'string' ? new Date(val) : val)),
});

export const LoadFilterSchema = z.object({
  status: z.enum(['offered', 'accepted', 'in_transit', 'completed', 'cancelled']).optional(),
  // Include pagination fields
  page: z
    .union([z.string(), z.number()])
    .transform((val) => parseInt(String(val), 10))
    .pipe(z.number().int().positive())
    .optional(),
  limit: z
    .union([z.string(), z.number()])
    .transform((val) => parseInt(String(val), 10))
    .pipe(z.number().int().positive().max(100))
    .optional(),
});
