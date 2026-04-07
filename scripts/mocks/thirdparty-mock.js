// scripts/mocks/thirdparty-mock.js
const express = require('express');
const app = express();
app.use(express.json());

// DOT incidents mock
app.get('/dot/incidents', (req, res) => {
  res.json({
    updated_at: new Date().toISOString(),
    incidents: [
      { id: 'dot-1', type: 'closure', severity: 3, lat: 29.76, lng: -95.36, confidence: 0.82 },
    ],
  });
});

// NOAA weather mock
app.get('/noaa/weather', (req, res) => {
  res.json({
    updated_at: new Date().toISOString(),
    alerts: [
      { id: 'noaa-1', type: 'storm', level: 'advisory', area: 'TX-HOU', confidence: 0.7 },
    ],
  });
});

// Health
app.get('/health', (_req, res) => res.send('ok'));

const port = process.env.MOCK_PORT || 4001;
app.listen(port, () => console.log(`[mocks] listening on :${port}`));
