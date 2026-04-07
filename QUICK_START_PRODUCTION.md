# Quick Start: Production Deployment

**Time Required:** 30-60 minutes  
**Difficulty:** Intermediate  
**Prerequisites:** Server with Node.js 20+, PostgreSQL 15+, Redis 7+

---

## 🎯 5-Minute Overview

Deploy the Fleet Manager Dashboard to production in 3 simple steps:

```bash
# 1. Install and build
npm ci && npm run build

# 2. Configure environment
cp .env.example .env.production
# Edit .env.production with your values

# 3. Deploy
./scripts/deploy-production.sh production false
```

---

## 📋 Detailed Deployment Steps

### Step 1: Server Preparation (10 minutes)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2
sudo npm install -g pm2

# Install PostgreSQL with PostGIS
sudo apt install -y postgresql-15 postgresql-15-postgis-3

# Install Redis
sudo apt install -y redis-server

# Verify installations
node --version    # Should be v20.x
npm --version
pm2 --version
psql --version
redis-cli --version
```

### Step 2: Database Setup (5 minutes)

```bash
# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE fleet_production;
CREATE USER fleet_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE fleet_production TO fleet_user;
\c fleet_production
CREATE EXTENSION IF NOT EXISTS postgis;
EOF

# Run schema migration
psql -U fleet_user -d fleet_production -f lib/database/fleet-schema.sql

# Verify tables created
psql -U fleet_user -d fleet_production -c "\dt"
```

### Step 3: Application Setup (10 minutes)

```bash
# Clone repository (or upload files)
git clone https://github.com/your-org/fleet-manager.git
cd fleet-manager

# Install dependencies
npm ci --only=production

# Configure environment
cat > .env.production << EOF
NODE_ENV=production
DATABASE_URL=postgresql://fleet_user:your_secure_password@localhost:5432/fleet_production
REDIS_URL=redis://localhost:6379
NEXT_PUBLIC_WS_URL=wss://your-domain.com
NEXT_PUBLIC_APP_URL=https://your-domain.com

# Enable all optimizations
REDIS_ENABLED=true
ENABLE_DATABASE_POOLING=true
DATABASE_POOL_MIN=5
DATABASE_POOL_MAX=20
ENABLE_API_COMPRESSION=true
ENABLE_RATE_LIMITING=true
ENABLE_QUERY_CACHING=true
ENABLE_REAL_TIME_SYNC=true
ENABLE_REDIS_WEBSOCKET=true

# UI features
NEXT_PUBLIC_ENABLE_OPTIMISTIC_UI=true
NEXT_PUBLIC_ENABLE_VIRTUAL_SCROLLING=true
NEXT_PUBLIC_ENABLE_INFINITE_SCROLL=true
NEXT_PUBLIC_ENABLE_ADVANCED_FILTERS=true
EOF

# Build application
npm run build
```

### Step 4: Nginx Setup (5 minutes)

```bash
# Install Nginx
sudo apt install -y nginx

# Configure Nginx
sudo tee /etc/nginx/sites-available/fleet-manager << EOF
upstream fleet_app {
    server localhost:3000;
}

server {
    listen 80;
    server_name your-domain.com;

    # Redirect to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL Configuration (update paths)
    ssl_certificate /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    # WebSocket support
    location /api/fleet/ws {
        proxy_pass http://fleet_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }

    # API routes
    location /api/ {
        proxy_pass http://fleet_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # All other routes
    location / {
        proxy_pass http://fleet_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/fleet-manager /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Deploy Application (2 minutes)

```bash
# Start with PM2
pm2 start npm --name "fleet-manager" -- start

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup

# Verify application is running
pm2 status
pm2 logs fleet-manager --lines 50
```

### Step 6: Verify Deployment (5 minutes)

```bash
# Health check
curl https://your-domain.com/api/health

# Expected response:
# {"status":"healthy","checks":{...}}

# Database stats
curl https://your-domain.com/api/fleet/db-stats

# WebSocket stats
curl https://your-domain.com/api/fleet/ws-stats

# Access dashboard
# Open browser: https://your-domain.com/fleet/dashboard
```

---

## ✅ Post-Deployment Checklist

- [ ] Application accessible via HTTPS
- [ ] WebSocket connection working (green indicator)
- [ ] Database queries executing
- [ ] Redis caching active
- [ ] Map displaying with vehicles
- [ ] No errors in PM2 logs
- [ ] Health endpoint returning 200
- [ ] SSL certificate valid

---

## 🔧 Common Issues & Solutions

### Issue 1: Application Won't Start

```bash
# Check logs
pm2 logs fleet-manager --err

# Check environment
cat .env.production | grep DATABASE_URL

# Test database connection
psql $DATABASE_URL -c "SELECT 1"
```

### Issue 2: WebSocket Not Connecting

```bash
# Check Nginx configuration
sudo nginx -t

# Verify WebSocket endpoint
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  https://your-domain.com/api/fleet/ws?orgId=org-1

# Check firewall
sudo ufw status
```

### Issue 3: Slow Performance

```bash
# Check database connections
curl https://your-domain.com/api/fleet/db-stats | jq '.primary'

# Check Redis
redis-cli INFO | grep connected_clients

# Monitor resources
pm2 monit
```

---

## 📊 Monitoring Setup (Optional, 10 minutes)

```bash
# Install Prometheus
./scripts/setup-monitoring.sh

# Start Prometheus
prometheus --config.file=prometheus.yml &

# Access Prometheus UI
# http://localhost:9090

# View metrics
# http://your-domain.com/api/metrics
```

---

## 🔄 Updating the Application

```bash
# Pull latest changes
git pull origin main

# Install dependencies
npm ci

# Build
npm run build

# Restart
pm2 restart fleet-manager

# Verify
curl https://your-domain.com/api/health
```

---

## 🚨 Rollback Procedure

```bash
# If something goes wrong
./scripts/rollback.sh

# Select backup to restore
# Follow prompts

# Verify rollback
curl https://your-domain.com/api/health
```

---

## 📞 Need Help?

- **Documentation:** `/docs` directory
- **Detailed Guide:** See [Production Deployment Guide](/docs/PRODUCTION_DEPLOYMENT.md)
- **Troubleshooting:** See [Operations Runbook](/docs/OPERATIONS_RUNBOOK.md)
- **Issues:** Create GitHub issue

---

## 🎉 Success!

Your Fleet Manager Dashboard is now live! 

**Next steps:**
1. Monitor logs for first 24 hours
2. Set up automated backups
3. Configure monitoring alerts
4. Train your team

---

_Deployment Time: ~30-60 minutes_  
_For production best practices, see full documentation._
