import * as Sentry from '@sentry/nextjs';

// Initialize Sentry only once and only when DSN is provided
if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: 0.1,
    beforeSend(event, hint) {
      // Filter out non-critical noisy errors
      if (event.exception && hint?.originalException instanceof Error) {
        const error = hint.originalException as Error;
        if (error instanceof TypeError && error.message.includes('Cannot read property')) {
          return null;
        }
      }
      return event;
    },
  });
}

export default Sentry;
