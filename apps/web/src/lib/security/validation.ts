import { z } from 'zod';

export const vehicleSchema = z.object({
  name: z.string().min(1).max(255),
  type: z.enum(['semi-truck', 'box-truck', 'van', 'pickup', 'trailer', 'flatbed']),
  status: z
    .enum(['active', 'idle', 'maintenance', 'offline', 'loading', 'unloading'])
    .optional(),
  vin: z.string().length(17).optional(),
  make: z.string().max(100).optional(),
  model: z.string().max(100).optional(),
  year: z.number().int().min(1900).max(new Date().getFullYear() + 1).optional(),
  licensePlate: z.string().max(20).optional(),
  capacity: z.number().positive().optional(),
  fuel: z.number().min(0).max(100).optional(),
  odometer: z.number().nonnegative().optional(),
});

export const driverSchema = z.object({
  name: z.string().min(1).max(255),
  email: z.string().email(),
  phone: z.string().regex(/^\+?[\d\s\-()]+$/),
  licenseNumber: z.string().optional(),
  licenseExpiry: z.preprocess((v) => (v ? new Date(String(v)) : undefined), z.date().optional()),
});

export const loadSchema = z.object({
  origin: z.object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
    address: z.string().min(1),
  }),
  destination: z.object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
    address: z.string().min(1),
  }),
  pickupTime: z.preprocess((v) => (v ? new Date(String(v)) : undefined), z.date()),
  deliveryTime: z.preprocess((v) => (v ? new Date(String(v)) : undefined), z.date()),
  weight: z.number().positive(),
  priority: z.enum(['urgent', 'normal', 'low']).optional(),
});

// Example usage in API route:
// try {
//   const validData = vehicleSchema.parse(req.body);
//   // Process valid data
// } catch (error) {
//   if (error instanceof z.ZodError) {
//     return res.status(400).json({ success: false, error: 'Validation failed', details: error.errors });
//   }
// }
