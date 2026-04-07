import { contextBridge, ipcRenderer, IpcRendererEvent } from 'electron';
import keytar from 'keytar';

const SERVICE_NAME = 'TruckerCore';

const electronAPI = {
  platform: process.platform,

  // Generic invoke passthrough for IPC handlers registered via ipcMain.handle
  invoke: (channel: string, ...args: any[]) => ipcRenderer.invoke(channel, ...args),

  onDeepLink: (callback: (url: string) => void) => {
    ipcRenderer.on('deep-link', (_event: IpcRendererEvent, url: string) => callback(url));
  },

  onOAuthCallback: (callback: (data: { token: string }) => void) => {
    ipcRenderer.on('oauth-callback', (_event: IpcRendererEvent, data: { token: string }) => callback(data));
  },

  onUpdateAvailable: (callback: (info?: any) => void) => {
    ipcRenderer.on('update-available', (_e, info) => callback(info));
  },

  onUpdateDownloaded: (callback: (info?: any) => void) => {
    ipcRenderer.on('update-downloaded', (_e, info) => callback(info));
  },

  onUpdateDownloadProgress: (callback: (progress: any) => void) => {
    ipcRenderer.on('update-download-progress', (_e, progress) => callback(progress));
  },

  onUpdateStatus: (callback: (status: string) => void) => {
    ipcRenderer.on('update-status', (_e, status) => callback(status));
  },

  onUpdateError: (callback: (error: any) => void) => {
    ipcRenderer.on('update-error', (_e, error) => callback(error));
  },

  onBeforeUpdateInstall: (callback: () => void) => {
    ipcRenderer.on('before-update-install', () => callback());
  },

  // Navigation events from main process/menu
  onNavigate: (callback: (path: string) => void) => {
    ipcRenderer.on('navigate', (_e: IpcRendererEvent, path: string) => callback(path));
  },

  checkForUpdates: () => ipcRenderer.invoke('check-for-updates'),
  downloadUpdate: () => ipcRenderer.invoke('download-update'),
  installUpdate: () => ipcRenderer.invoke('install-update'),

  credentials: {
    async save(username: string, password: string): Promise<void> {
      await keytar.setPassword(SERVICE_NAME, username, password);
    },
    async get(username: string): Promise<string | null> {
      return await keytar.getPassword(SERVICE_NAME, username);
    },
    async delete(username: string): Promise<boolean> {
      return await keytar.deletePassword(SERVICE_NAME, username);
    },
    async findCredentials(): Promise<Array<{ account: string; password: string }>> {
      return await keytar.findCredentials(SERVICE_NAME);
    },
  },

  openExternal: (url: string) => {
    ipcRenderer.send('open-external', url);
  },

  showSaveDialog: async (options: { defaultPath?: string; filters?: Array<{ name: string; extensions: string[] }> }) => {
    return await ipcRenderer.invoke('show-save-dialog', options);
  },

  showOpenDialog: async (options: { properties?: string[]; filters?: Array<{ name: string; extensions: string[] }> }) => {
    return await ipcRenderer.invoke('show-open-dialog', options);
  },

  getVersion: () => ipcRenderer.invoke('get-version'),

  // Multi-window APIs (Electron only)
  window: {
    create: (dashboardId: string, options?: { displayId?: string; bounds?: { x: number; y: number; width: number; height: number }; widgets?: string[] }) =>
      ipcRenderer.invoke('window:create', dashboardId, options),
    close: (windowId: string) => ipcRenderer.invoke('window:close', windowId),
    getDisplays: () => ipcRenderer.invoke('window:getDisplays'),
    arrange: (dashboardId: string, layout: 'tile' | 'cascade' | 'grid') =>
      ipcRenderer.invoke('window:arrange', dashboardId, layout),
    send: (windowId: string, channel: string, data: any) => ipcRenderer.send('window:send', windowId, channel, data),
    broadcast: (channel: string, data: any) => ipcRenderer.send('window:broadcast', channel, data),
  },
};

contextBridge.exposeInMainWorld('electronAPI', electronAPI);

export type ElectronAPI = typeof electronAPI;

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}
