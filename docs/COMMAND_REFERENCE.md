# Fleet Manager Dashboard - Command Reference

Quick reference for all important commands.

---

## 🚀 Development

```bash
# Start development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Type check
npm run type-check

# Lint code
npm run lint
```

---

## 🧪 Testing

```bash
# Run all tests
npm run test:all

# Unit tests
npm test

# E2E tests
npm run test:e2e

# Integration verification
npm run verify

# Final verification
npm run verify:final

# Production validation
./scripts/production-validation.sh
```

---

## 🚢 Deployment

```bash
# Deploy to staging
npm run deploy:staging

# Deploy to production
npm run deploy:production

# Dry run (test without deploying)
npm run deploy:dry-run

# Verify deployment
npm run verify:post-deploy https://your-domain.com

# Rollback
npm run rollback
```

---

## 🐳 Docker

```bash
# Build and start
docker-compose up -d

# Scale app servers
docker-compose up -d --scale app=3

# View logs
docker-compose logs -f app

# Stop all services
docker-compose down

# Rebuild
# (use the appropriate service or --build flag as needed)
docker-compose up -d --build
```
