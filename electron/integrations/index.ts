import { BrowserWindow } from 'electron';
import { DATIntegration } from './dat-integration';
import { TrimbleIntegration } from './trimble-integration';
import { SamsaraIntegration } from './samsara-integration';
import { MotiveIntegration } from './motive-integration';
import { GeotabIntegration } from './geotab-integration';
import { CommunicationIntegration } from './communication-integration';

/**
 * Initialize third-party API integrations.
 * Reads credentials from environment variables (process.env) and
 * registers IPC handlers in the main process. Secrets remain in main.
 */
export function initializeIntegrations(_mainWindow: BrowserWindow) {
  console.log('[Integrations] Starting initialization...');
  // DAT Load Board
  try {
    if (process.env.DAT_API_KEY) {
      // eslint-disable-next-line no-new
      new DATIntegration({
        apiKey: process.env.DAT_API_KEY!,
        customerId: process.env.DAT_CUSTOMER_ID || '',
        baseURL: process.env.DAT_BASE_URL || 'https://freight.api.dat.com/v2',
      });
      console.log('[Integrations] ✓ DAT Load Board initialized');
    }
  } catch (e) {
    console.error('[Integrations] DAT init failed:', e);
  }

  // Trimble Maps
  try {
    if (process.env.TRIMBLE_API_KEY) {
      // eslint-disable-next-line no-new
      new TrimbleIntegration({
        apiKey: process.env.TRIMBLE_API_KEY!,
        baseURL: process.env.TRIMBLE_BASE_URL || 'https://pcmiler.alk.com/apis/rest/v1.0',
      });
      console.log('[Integrations] ✓ Trimble Maps initialized');
    }
  } catch (e) {
    console.error('[Integrations] Trimble init failed:', e);
  }

  // Samsara Fleet Tracking
  try {
    if (process.env.SAMSARA_API_KEY) {
      // eslint-disable-next-line no-new
      new SamsaraIntegration({
        apiKey: process.env.SAMSARA_API_KEY!,
        baseURL: process.env.SAMSARA_BASE_URL || 'https://api.samsara.com',
      });
      console.log('[Integrations] ✓ Samsara initialized');
    }
  } catch (e) {
    console.error('[Integrations] Samsara init failed:', e);
  }

  // Motive (KeepTruckin)
  try {
    if (process.env.MOTIVE_API_KEY) {
      // eslint-disable-next-line no-new
      new MotiveIntegration({
        apiKey: process.env.MOTIVE_API_KEY!,
        baseURL: process.env.MOTIVE_BASE_URL || 'https://api.gomotive.com/v1',
      });
      console.log('[Integrations] ✓ Motive initialized');
    }
  } catch (e) {
    console.error('[Integrations] Motive init failed:', e);
  }

  // Geotab
  try {
    if (process.env.GEOTAB_USERNAME && process.env.GEOTAB_PASSWORD) {
      // eslint-disable-next-line no-new
      new GeotabIntegration({
        username: process.env.GEOTAB_USERNAME!,
        password: process.env.GEOTAB_PASSWORD!,
        database: process.env.GEOTAB_DATABASE || '',
        server: process.env.GEOTAB_SERVER || 'my.geotab.com',
      });
      console.log('[Integrations] ✓ Geotab initialized');
    }
  } catch (e) {
    console.error('[Integrations] Geotab init failed:', e);
  }

  // Communications (Twilio + SendGrid)
  try {
    if ((process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) || process.env.SENDGRID_API_KEY) {
      // eslint-disable-next-line no-new
      new CommunicationIntegration({
        twilio: {
          accountSid: process.env.TWILIO_ACCOUNT_SID || '',
          authToken: process.env.TWILIO_AUTH_TOKEN || '',
          phoneNumber: process.env.TWILIO_PHONE_NUMBER || '',
        },
        sendgrid: {
          apiKey: process.env.SENDGRID_API_KEY || '',
          fromEmail: process.env.SENDGRID_FROM_EMAIL || '',
        },
      });
      console.log('[Integrations] ✓ Communications initialized');
    }
  } catch (e) {
    console.error('[Integrations] Communications init failed:', e);
  }

  console.log('[Integrations] Initialization complete');
}
