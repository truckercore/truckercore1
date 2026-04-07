# Integration Setup Guide

Complete guide for setting up all vendor integrations in TruckerCore.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Samsara Setup](#samsara-setup)
3. [Motive Setup](#motive-setup)
4. [DAT Load Board](#dat-load-board)
5. [Trimble Maps](#trimble-maps)
6. [Geotab Setup](#geotab-setup)
7. [Communications (Twilio/SendGrid)](#communications)
8. [Testing Integrations](#testing-integrations)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts
- [ ] Samsara API account
- [ ] Motive developer account
- [ ] DAT Load Board subscription
- [ ] Trimble Maps API key
- [ ] Twilio account (for SMS)
- [ ] SendGrid account (for email)

### System Requirements
- Node.js 18+
- npm 9+
- Valid SSL certificates (for webhooks)
- Static IP address (recommended for whitelisting)

---

## Samsara Setup

### 1. Create API Token

1. Log in to Samsara Dashboard: https://cloud.samsara.com
2. Navigate to **Settings** → **API Tokens**
3. Click **Create Token**
4. Set permissions:
   - ✅ Vehicle Location (Read)
   - ✅ Driver HOS (Read)
   - ✅ Vehicle Diagnostics (Read)
   - ✅ Alerts (Read/Write)
5. Copy the token immediately (won't be shown again)

### 2. Configure in TruckerCore

```bash
# Add to .env
SAMSARA_API_KEY=your-api-token-here
SAMSARA_BASE_URL=https://api.samsara.com
```

### 3. Set OAuth Scopes (If Using OAuth)

Required scopes:
- `fleets.vehicles.location:read`
- `fleets.drivers.hos:read`
- `fleets.vehicles.stats:read`
- `fleets.alerts:read`

### 4. Configure Webhooks (Optional)

TruckerCore URL: `https://your-domain.com/webhooks/samsara`

Subscribe to:
- `vehicle.location.updated`
- `driver.hos.violation`
- `vehicle.alert.created`

### 5. Test Connection

```typescript
// In Electron DevTools Console
const samsara = new SamsaraIntegration({
  apiKey: process.env.SAMSARA_API_KEY,
  baseURL: 'https://api.samsara.com'
});
const locations = await samsara.getVehicleLocations();
console.log('Vehicles found:', locations.length);
```

### 6. Data Mapping

| Samsara Field | TruckerCore Field | Notes |
|--------------|-------------------|-------|
| `speedMilesPerHour` | `telemetry.speed` | Already in mph |
| `odometerMeters` | `telemetry.odometer` | Converted to miles |
| `engineCoolantTemp` | `telemetry.engine.temperature` | Converted to °F |
| `location.reverseGeo.formattedLocation` | `location.address` | Full address string |

### 7. Rate Limits
- **Standard Plan:** 60 requests/minute
- **Premium Plan:** 120 requests/minute
- **Burst:** Up to 2x limit for 30 seconds

### 8. Monitoring

Check health:

```bash
curl -H "Authorization: Bearer $SAMSARA_API_KEY" \
  https://api.samsara.com/fleet/vehicles
```

Expected response: 200 OK with vehicle list

---

## Motive Setup

### 1. Register Application

1. Visit: https://gomotive.com/developer
2. Click **Register New Application**
3. Fill in details:
   - **App Name:** TruckerCore
   - **Redirect URI:** `truckercore://oauth/callback`
   - **Webhook URL:** `https://your-domain.com/webhooks/motive`
4. Note your **Client ID** and **Client Secret**

### 2. Configure OAuth

```bash
# Add to .env
MOTIVE_CLIENT_ID=your-client-id
MOTIVE_CLIENT_SECRET=your-client-secret
MOTIVE_API_KEY=your-api-key
MOTIVE_BASE_URL=https://api.gomotive.com/v1
```

### 3. OAuth Flow

```typescript
// Implement OAuth in your app
const authUrl =
  'https://api.gomotive.com/oauth/authorize?'
  + `client_id=${MOTIVE_CLIENT_ID}`
  + '&redirect_uri=truckercore://oauth/callback'
  + '&response_type=code'
  + '&scope=hos:read dvir:read vehicle:read';

// After user authorizes, exchange code for token
const tokenResponse = await fetch('https://api.gomotive.com/oauth/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    client_id: MOTIVE_CLIENT_ID,
    client_secret: MOTIVE_CLIENT_SECRET,
    code: authCode,
    grant_type: 'authorization_code'
  })
});
```

### 4. Required Scopes

- `hos:read` - Hours of Service data
- `dvir:read` - Vehicle inspection reports
- `dvir:write` - Submit inspections
- `vehicle:read` - Vehicle telemetry
- `ifta:read` - IFTA reports

### 5. Test Connection

```typescript
const motive = new MotiveIntegration({
  apiKey: process.env.MOTIVE_API_KEY,
  baseURL: 'https://api.gomotive.com/v1'
});
const drivers = await motive.getDrivers();
console.log('Drivers found:', drivers.length);
```

### 6. Compliance Note

⚠️ **IMPORTANT:** HOS data retention is **7 years** (FMCSA requirement). Configure automatic archival in privacy settings.

### 7. Rate Limits
- **API Calls:** 100 requests/minute
- **Webhook Events:** Unlimited
- **Burst:** 2x for 60 seconds

---

## DAT Load Board

### 1. Get API Credentials

1. Contact DAT Sales: sales@dat.com
2. Request API access (requires DAT subscription)
3. Receive:
   - Customer ID
   - API Key
   - Base URL

### 2. Configure

```bash
# Add to .env
DAT_API_KEY=your-api-key
DAT_CUSTOMER_ID=your-customer-id
DAT_BASE_URL=https://freight.api.dat.com/v2
```

### 3. Set Permissions

Ensure your API key has:
- ✅ Load Search
- ✅ Load Posting
- ✅ Rate Analytics
- ✅ Carrier Search

### 4. Data Caching Policy

⚠️ Per DAT TOS:
- **Load data:** Cache max 15 minutes
- **Rate analytics:** Cache max 24 hours
- **Carrier data:** Do not cache

Implement in code:

```typescript
const CACHE_TTL = {
  loads: 15 * 60 * 1000,     // 15 minutes
  rates: 24 * 60 * 60 * 1000, // 24 hours
  carriers: 0                 // No caching
};
```

### 5. Test Connection

```typescript
const dat = new DATIntegration({
  apiKey: process.env.DAT_API_KEY,
  customerId: process.env.DAT_CUSTOMER_ID,
  baseURL: 'https://freight.api.dat.com/v2'
});
const loads = await dat.searchLoads({ origin: 'Chicago, IL', equipment: 'V', radius: 50 });
console.log('Loads found:', loads.length);
```

### 6. Rate Limits
- **Search:** 60 requests/minute
- **Posting:** 30 requests/minute
- **Analytics:** 10 requests/minute

---

## Trimble Maps

### 1. Register for API Key

1. Visit: https://developer.trimblemaps.com
2. Sign up for developer account
3. Create new application
4. Select products:
   - ✅ PC*MILER Route
   - ✅ Geocoding
   - ✅ Mapping Services
5. Copy API key

### 2. Configure

```bash
# Add to .env
TRIMBLE_API_KEY=your-api-key
TRIMBLE_BASE_URL=https://pcmiler.alk.com/apis/rest/v1.0
```

### 3. Truck Profile Configuration

```typescript
const truckProfile = {
  height: 13.5, // feet
  width: 8.5,   // feet
  length: 53,   // feet
  weight: 80000,// pounds
  axles: 5,
  hazmat: false
};
```

### 4. Routing Options

```typescript
const routeOptions = {
  vehicleType: 'Truck',
  routeOptimization: 'Time', // or 'Distance'
  highwayOnly: false,
  tollDiscourage: true,
  borderOpen: true
};
```

### 5. Test Route Calculation

```typescript
const trimble = new TrimbleIntegration({
  apiKey: process.env.TRIMBLE_API_KEY,
  baseURL: 'https://pcmiler.alk.com/apis/rest/v1.0'
});
const route = await trimble.calculateRoute({
  origin: 'Chicago, IL',
  destination: 'Dallas, TX',
  truckProfile,
  avoidTolls: false
});
console.log('Distance:', route.distance, 'miles');
console.log('Duration:', route.duration, 'minutes');
console.log('Low Clearances:', route.lowClearances.length);
```

### 6. Tile Licensing

⚠️ **Map Tiles:** Display only, no offline caching without license.

⚠️ **Attribution:** Must display Trimble attribution on all maps.

### 7. Rate Limits
- **Routing:** 120 requests/minute
- **Geocoding:** 240 requests/minute
- **Daily Cap:** 10,000 route calculations

---

## Geotab Setup

### 1. Get Credentials

Geotab uses database authentication:
- Database name (from Geotab admin)
- Username
- Password
- Server (usually `my.geotab.com`)

### 2. Configure

```bash
# Add to .env
GEOTAB_USERNAME=your-username
GEOTAB_PASSWORD=your-password
GEOTAB_DATABASE=your-database-name
GEOTAB_SERVER=my.geotab.com
```

### 3. Authentication

Geotab uses session-based auth:

```typescript
const geotab = new GeotabIntegration({
  username: process.env.GEOTAB_USERNAME,
  password: process.env.GEOTAB_PASSWORD,
  database: process.env.GEOTAB_DATABASE,
  server: process.env.GEOTAB_SERVER
});
await geotab.authenticate();
```

### 4. Test Connection

```typescript
const vehicles = await geotab.getVehicles();
console.log('Vehicles found:', vehicles.length);
```

### 5. Rate Limits
- **API Calls:** 10,000 per hour
- **Max Results:** 50,000 per query
- **Concurrent:** 5 requests max

---

## Communications

### Twilio (SMS)

```bash
# Add to .env
TWILIO_ACCOUNT_SID=your-account-sid
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+1234567890
```

Test:

```typescript
const comm = new CommunicationIntegration({
  twilio: {
    accountSid: process.env.TWILIO_ACCOUNT_SID,
    authToken: process.env.TWILIO_AUTH_TOKEN,
    phoneNumber: process.env.TWILIO_PHONE_NUMBER
  },
  sendgrid: { /* ... */ }
});
await comm.sendSMS({ to: '+1234567890', message: 'Test message from TruckerCore' });
```

### SendGrid (Email)

```bash
# Add to .env
SENDGRID_API_KEY=your-api-key
SENDGRID_FROM_EMAIL=noreply@truckercore.com
```

Test:

```typescript
await comm.sendEmail({
  to: 'test@example.com',
  subject: 'Test Email',
  html: '<p>Test message from TruckerCore</p>'
});
```

---

## Testing Integrations

### Run Integration Tests

```bash
# Test all integrations
npm run test:integration

# Test specific vendor
npm run test:integration -- --vendor=samsara
```

### Synthetic Health Checks

```typescript
// Run every 5 minutes
setInterval(async () => {
  for (const vendor of ['samsara', 'motive', 'dat', 'trimble']) {
    const start = Date.now();
    try {
      await performHealthCheck(vendor);
      const latency = Date.now() - start;
      metricsCollector.recordSyntheticCheck(vendor, 'health', true, latency);
    } catch (error: any) {
      metricsCollector.recordSyntheticCheck(
        vendor,
        'health',
        false,
        Date.now() - start,
        error.message
      );
    }
  }
}, 5 * 60 * 1000);
```

---

## Troubleshooting

### Authentication Failures

**Symptom:** 401 Unauthorized

**Solutions:**
1. Verify API key is correct and not expired
2. Check if IP address needs whitelisting
3. Ensure correct base URL
4. Verify OAuth token hasn't expired (refresh if needed)

### Rate Limit Errors

**Symptom:** 429 Too Many Requests

**Solutions:**
1. Check rate limiter configuration
2. Implement exponential backoff
3. Enable request queuing
4. Consider upgrading API plan

### Timeout Errors

**Symptom:** Request timeout after 30 seconds

**Solutions:**
1. Increase timeout for slow endpoints
2. Implement request pagination
3. Use streaming for large responses
4. Check network connectivity

### Data Mapping Errors

**Symptom:** Incorrect units or null values

**Solutions:**
1. Review schema mapper conversions
2. Check for API version changes
3. Validate required fields are present
4. Add fallback values for optional fields

### Circuit Breaker Opens

**Symptom:** Circuit breaker is OPEN

**Solutions:**
1. Check vendor status page
2. Review error logs for patterns
3. Reduce request rate temporarily
4. Wait for automatic recovery

---

## Support Resources

### Vendor Documentation
- **Samsara:** https://developers.samsara.com
- **Motive:** https://gomotive.com/developer/docs
- **DAT:** https://developer.dat.com
- **Trimble:** https://developer.trimblemaps.com
- **Geotab:** https://geotab.github.io/sdk

### Community
- TruckerCore Discord: [invite link]
- Stack Overflow: Tag `truckercore`
- GitHub Issues: https://github.com/your-org/truckercore/issues

### Emergency Contacts
- Ops Team: ops@company.com
- On-Call: +1-555-ONCALL
- Slack: #truckercore-support
