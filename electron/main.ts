import { app, BrowserWindow, Menu, shell, session, protocol, ipcMain, dialog } from 'electron';
import { initializeIntegrations } from './integrations';
import * as path from 'path';
import * as url from 'url';
import { setupMenu } from './menu';
import { FleetManagerDashboard } from './managers/fleet_manager_dashboard';
import { SecureAutoUpdater } from './auto-updater';
import { PerformanceMonitor } from './performance_monitor';
import { AnalyticsTracker } from './analytics_tracker';
import { AdvancedSecretsManager } from './security/advanced_secrets_manager';
import { windowManager } from './window/WindowManager';

// Security: Enable sandbox and context isolation
app.commandLine.appendSwitch('enable-features', 'ElectronSerialChooser');

let mainWindow: BrowserWindow | null = null;
let isDev: boolean;
let secureUpdater: SecureAutoUpdater | null = null;
let perfMon: PerformanceMonitor | null = null;
let analytics: AnalyticsTracker | null = null;
let secretsMgr: AdvancedSecretsManager | null = null;

// Determine if running in development
isDev = process.env.NODE_ENV === 'development' || !!process.defaultApp;

// Custom protocol for deep linking (e.g., truckercore://fleet/123)
const PROTOCOL = 'truckercore';

let fleetDashboard: FleetManagerDashboard | null = null;

function createWindow(): void {
  // Configure session for multi-user support with persistent storage
  const partition = 'persist:default';
  const ses = session.fromPartition(partition);

  // Security headers for web content
  ses.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [
          "default-src 'self' 'unsafe-inline' 'unsafe-eval' https:; " +
            "script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; " +
            "style-src 'self' 'unsafe-inline' https:; " +
            "img-src 'self' data: https: blob:; " +
            "font-src 'self' data: https:; " +
            "connect-src 'self' https: wss: ws:;",
        ],
      },
    });
  });

  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1024,
    minHeight: 768,
    title: 'TruckerCore',
    icon: path.join(__dirname, '../resources/icon.png'),
    backgroundColor: '#0F1216',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      nodeIntegrationInWorker: false,
      nodeIntegrationInSubFrames: false,
      sandbox: true,
      webSecurity: true,
      allowRunningInsecureContent: false,
      preload: path.join(__dirname, 'preload.js'),
      webviewTag: false,
      spellcheck: true,
      partition: partition,
      session: ses as any,
    },
    show: false,
  });

  // Setup native menu
  setupMenu(mainWindow);

  // Load app URL
  const startUrl = isDev
    ? 'http://localhost:3000'
    : url.format({
        pathname: path.join(__dirname, '../out/index.html'),
        protocol: 'file:',
        slashes: true,
      });

  void mainWindow.loadURL(startUrl);

  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    mainWindow?.show();
    if (isDev) {
      mainWindow?.webContents.openDevTools();
    }
  });

  // Initialize FleetManagerDashboard (SQLite-backed) and start live updates
  try {
    const dbPath = path.join(app.getPath('userData'), 'truckercore.db');
    fleetDashboard = new FleetManagerDashboard(mainWindow, dbPath);
    fleetDashboard.startLiveUpdates(10000);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to initialize FleetManagerDashboard', e);
  }

  // Initialize API integrations (DAT, Trimble, Samsara, Motive, Geotab, Communications) conditionally via environment
  try {
    initializeIntegrations(mainWindow);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to initialize integrations', e);
  }

  // Start performance monitoring
  try {
    perfMon = new PerformanceMonitor(mainWindow);
    perfMon.start(5000);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to start PerformanceMonitor', e);
  }

  // Initialize Advanced Secrets Manager (SQLite optional)
  try {
    secretsMgr = new AdvancedSecretsManager();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to initialize AdvancedSecretsManager', e);
  }

  // Initialize analytics tracker (best-effort, gated by env)
  try {
    const enabled = !!(process.env.MIXPANEL_TOKEN || process.env.GOOGLE_ANALYTICS_ID || process.env.CUSTOM_ANALYTICS_ENDPOINT);
    if (enabled) {
      analytics = new AnalyticsTracker({
        enabled,
        mixpanelToken: process.env.MIXPANEL_TOKEN,
        googleAnalyticsId: process.env.GOOGLE_ANALYTICS_ID,
        customEndpoint: process.env.CUSTOM_ANALYTICS_ENDPOINT,
      });
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to initialize AnalyticsTracker', e);
  }

  // Handle external links - open in default browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http://localhost') || url.startsWith('file://')) {
      return { action: 'allow' };
    }
    void shell.openExternal(url);
    return { action: 'deny' };
  });

  // Prevent navigation to external sites
  mainWindow.webContents.on('will-navigate', (event, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);
    if (isDev && parsedUrl.hostname === 'localhost') {
      return;
    }
    if (!navigationUrl.startsWith('file://')) {
      event.preventDefault();
      void shell.openExternal(navigationUrl);
    }
  });

  // Handle window close
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Initialize secure auto-updater (production only)
  if (!isDev) {
    secureUpdater = new SecureAutoUpdater(mainWindow);
    secureUpdater.startAutoUpdateChecks(4);
  }

  // IPC handlers
  ipcMain.on('open-external', (_evt, target: string) => {
    if (typeof target === 'string' && target.length > 3) {
      void shell.openExternal(target);
    }
  });

  // Backward-compat event for install now
  ipcMain.on('install-update', () => {
    if (!isDev && secureUpdater) {
      secureUpdater.installUpdate();
    }
  });

  // New IPC: manual update control
  ipcMain.handle('check-for-updates', () => {
    if (secureUpdater) secureUpdater.checkForUpdates(true);
  });
  ipcMain.handle('download-update', () => {
    if (secureUpdater) secureUpdater.downloadUpdate();
  });
  ipcMain.handle('install-update', () => {
    if (secureUpdater) secureUpdater.installUpdate();
  });

  ipcMain.handle('show-save-dialog', async (_evt, options) => {
    const res = await dialog.showSaveDialog(mainWindow!, options ?? {});
    return res;
  });

  ipcMain.handle('show-open-dialog', async (_evt, options) => {
    const res = await dialog.showOpenDialog(mainWindow!, options ?? {});
    return res;
  });

  ipcMain.handle('get-version', async () => app.getVersion());

  // Secrets Manager IPC
  ipcMain.handle('secrets:set', async (_evt, key: string, value: string, options: any) => {
    if (!secretsMgr) return false;
    await secretsMgr.setSecret(key, value, options || {});
    return true;
  });
  ipcMain.handle('secrets:get', async (_evt, key: string, requiredScopes: string[] = [], purpose = 'runtime', accessedBy = 'system') => {
    if (!secretsMgr) return null;
    return await secretsMgr.getSecret(key, requiredScopes, purpose, accessedBy);
  });
  ipcMain.handle('secrets:rotate', async (_evt, key: string, newValue: string, rotatedBy = 'system') => {
    if (!secretsMgr) return false;
    await secretsMgr.rotateSecret(key, newValue, rotatedBy);
    return true;
  });
  ipcMain.handle('secrets:rotation-status', async () => {
    if (!secretsMgr) return [];
    return secretsMgr.getRotationStatus();
  });
  ipcMain.handle('secrets:vendor-scopes', async (_evt, vendor: string, level: 'read' | 'write' | 'admin' = 'read') => {
    if (!secretsMgr) return [];
    return secretsMgr.getVendorScopes(vendor, level);
  });
}

// Register custom protocol for deep linking
if (!app.isDefaultProtocolClient(PROTOCOL)) {
  app.setAsDefaultProtocolClient(PROTOCOL);
}

// Handle custom protocol on macOS
app.on('open-url', (event, deepLinkUrl) => {
  event.preventDefault();
  if (mainWindow) {
    mainWindow.webContents.send('deep-link', deepLinkUrl);
  }
});

// Single instance lock - prevent multiple instances
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', (_event, commandLine) => {
    const deep = commandLine.find((arg) => arg.startsWith(`${PROTOCOL}://`));
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
      if (deep) {
        mainWindow.webContents.send('deep-link', deep);
      }
    }
  });

  app.whenReady().then(() => {
    protocol.registerFileProtocol(PROTOCOL, (request, callback) => {
      const reqUrl = request.url.replace(`${PROTOCOL}://`, '');
      callback({ path: path.normalize(`${__dirname}/${reqUrl}`) });
    });

    createWindow();

    // Restore additional dashboard windows from last session
    try {
      windowManager.restoreWindows();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Failed to restore dashboard windows', e);
    }

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
      }
    });
  });
}

// Quit when all windows are closed (except macOS)
app.on('window-all-closed', () => {
  if (analytics) {
    void analytics.shutdown();
  }
  if (secretsMgr) {
    try { secretsMgr.close(); } catch {}
    secretsMgr = null;
  }
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Security: Validate and sanitize any web content
app.on('web-contents-created', (_event, contents) => {
  contents.on('will-navigate', (event, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);
    if (!['http:', 'https:', 'file:', PROTOCOL + ':'].includes(parsedUrl.protocol)) {
      event.preventDefault();
    }
  });
  contents.setWindowOpenHandler(({ url }) => {
    void shell.openExternal(url);
    return { action: 'deny' };
  });
});

// Handle OAuth redirects (for external browser login flow)
app.on('open-url', (event, deepUrl) => {
  event.preventDefault();
  if (deepUrl.startsWith(`${PROTOCOL}://callback`)) {
    const urlParams = new URL(deepUrl);
    const token = urlParams.searchParams.get('token');
    if (mainWindow && token) {
      mainWindow.webContents.send('oauth-callback', { token });
    }
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  app.quit();
});
