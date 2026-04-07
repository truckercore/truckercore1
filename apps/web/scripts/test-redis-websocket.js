/* eslint-disable no-console */
const WebSocket = require('ws');

console.log('🧪 Testing Redis WebSocket Scaling\n');

const SERVER_URLS = [
  'ws://localhost:3000/api/fleet/ws?orgId=org-1',
  // Add more server URLs for multi-instance testing
];

const clients = [];
const ORG_ID = 'org-1';

// Connect multiple clients
SERVER_URLS.forEach((url, index) => {
  const ws = new WebSocket(url);

  ws.on('open', () => {
    console.log(`✅ Client ${index + 1} connected to ${url}`);

    // Authenticate
    ws.send(
      JSON.stringify({
        type: 'AUTH',
        data: { organizationId: ORG_ID },
      })
    );
  });

  ws.on('message', (data) => {
    const message = JSON.parse(data.toString());
    console.log(`📨 Client ${index + 1} received:`, message.type);

    if (message.type === 'VEHICLE_UPDATE') {
      console.log('   Vehicle:', message.data.id);
    }
  });

  ws.on('error', (error) => {
    console.error(`❌ Client ${index + 1} error:`, error.message);
  });

  ws.on('close', () => {
    console.log(`🔌 Client ${index + 1} disconnected`);
  });

  clients.push(ws);
});

// Send test message after 2 seconds
setTimeout(() => {
  console.log('\n📤 Sending test broadcast...\n');

  // Simulate server broadcast
  const testMessage = {
    type: 'VEHICLE_UPDATE',
    data: {
      id: 'vehicle-test-1',
      location: { lat: 40.7128, lng: -74.006 },
      speed: 55,
    },
  };

  // POST to broadcast endpoint
  fetch('http://localhost:3000/api/fleet/ws', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      orgId: ORG_ID,
      message: testMessage,
    }),
  })
    .then((res) => res.json())
    .then((data) => console.log('Broadcast response:', data))
    .catch((error) => console.error('Broadcast error:', error));
}, 2000);

// Close connections after 10 seconds
setTimeout(() => {
  console.log('\n🔚 Closing all connections...\n');
  clients.forEach((ws) => ws.close());
  process.exit(0);
}, 10000);
