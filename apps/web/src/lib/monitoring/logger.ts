import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  ...(process.env.NODE_ENV === 'production'
    ? {
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: false,
          },
        },
      }
    : {}),
});

export default logger;
// Usage examples:
// logger.info('Vehicle updated', { vehicleId: '123' });
// logger.error('Database error', { error });
// logger.warn('High memory usage', { usage: 85 });
