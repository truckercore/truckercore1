# Fleet Integration Service Architecture

## Overview
Production-grade integration layer for DAT, Trimble, and Samsara APIs with:
- PII redaction & structured logging
- Circuit breakers & bulkheads per vendor
- Adaptive rate limiting with jittered backoff
- Idempotency for mutating operations
- Persistent retry queue with DLQ
- Worker thread offloading
- Unified data model with normalization

## Service Structure
```
lib/integrations/
├── core/
│   ├── circuit-breaker.ts    # Per-vendor circuit breaker
│   ├── rate-limiter.ts       # Adaptive rate limiting
│   ├── retry-queue.ts        # Persistent retry with DLQ (Redis)
│   ├── worker-pool.ts        # Thread pool for network I/O
│   └── idempotency.ts        # Idempotency key management (Redis)
├── logging/
│   ├── structured-logger.ts  # PII-safe structured logging
│   └── log-redactor.ts       # PII redaction engine
├── models/
│   ├── canonical.ts          # Unified Fleet/Load/Vehicle schema & helpers
│   └── mappers/              # Vendor-specific mappers (stubs)
├── adapters/
│   ├── dat-adapter.ts
│   ├── trimble-adapter.ts
│   └── samsara-adapter.ts
├── observability/
│   ├── metrics.ts            # Prometheus metrics
│   └── health-checks.ts      # Synthetic monitoring
└── api/
    └── integration-router.ts # Express router with feature flags
```

This package is additive and self-contained. It does not change runtime behavior unless imported by a service. All external dependencies used here already exist in the repository (axios, ioredis, prom-client, express). The logger dynamically falls back to console if `winston` is not available.
