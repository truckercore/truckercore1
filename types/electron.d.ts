export interface ElectronAPI {
  platform: string;
  invoke: (channel: string, ...args: any[]) => Promise<any>;
  onDeepLink: (callback: (url: string) => void) => void;
  onOAuthCallback: (callback: (data: { token: string }) => void) => void;

  // Auto-update APIs
  checkForUpdates: () => Promise<any>;
  downloadUpdate: () => Promise<any>;
  installUpdate: () => Promise<any>;
  onUpdateAvailable: (callback: (info?: any) => void) => void;
  onUpdateDownloaded: (callback: (info?: any) => void) => void;
  onUpdateDownloadProgress: (callback: (progress: any) => void) => void;
  onUpdateStatus: (callback: (status: string) => void) => void;
  onUpdateError: (callback: (error: any) => void) => void;
  onBeforeUpdateInstall: (callback: () => void) => void;
  onNavigate: (callback: (path: string) => void) => void;

  credentials: {
    save(username: string, password: string): Promise<void>;
    get(username: string): Promise<string | null>;
    delete(username: string): Promise<boolean>;
    findCredentials(): Promise<Array<{ account: string; password: string }>>;
  };
  openExternal: (url: string) => void;
  showSaveDialog: (options: any) => Promise<any>;
  showOpenDialog: (options: any) => Promise<any>;
  getVersion: () => Promise<string>;
}

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
}

export {};
