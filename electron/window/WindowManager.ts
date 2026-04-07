import { BrowserWindow, screen, ipcMain } from 'electron';
import Store from 'electron-store';
import * as path from 'path';

interface Bounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface WindowState {
  windowId: string;
  dashboardId: string;
  bounds: Bounds;
  displayId: string;
  widgets: string[];
}

interface WindowStoreSchema {
  windowStates: WindowState[];
}

function generateId(): string {
  return `win_${Math.random().toString(36).slice(2)}_${Date.now()}`;
}

export class WindowManager {
  private static _instance: WindowManager;
  private windows: Map<string, BrowserWindow> = new Map();
  private store: Store<WindowStoreSchema>;

  private constructor() {
    this.store = new Store<WindowStoreSchema>({ name: 'window-states', defaults: { windowStates: [] } });
    this.registerIpc();
  }

  static get instance(): WindowManager {
    if (!this._instance) this._instance = new WindowManager();
    return this._instance;
  }

  getStates(): WindowState[] {
    return this.store.get('windowStates');
  }

  private saveState(state: WindowState): void {
    const states = this.getStates();
    const idx = states.findIndex(s => s.windowId === state.windowId);
    if (idx >= 0) {
      states[idx] = state;
    } else {
      states.push(state);
    }
    this.store.set('windowStates', states);
  }

  private updateState(windowId: string, updates: Partial<WindowState>): void {
    const states = this.getStates();
    const idx = states.findIndex(s => s.windowId === windowId);
    if (idx >= 0) {
      states[idx] = { ...states[idx], ...updates } as WindowState;
      this.store.set('windowStates', states);
    }
  }

  private removeState(windowId: string): void {
    const states = this.getStates().filter(s => s.windowId !== windowId);
    this.store.set('windowStates', states);
  }

  createDashboardWindow(
    dashboardId: string,
    options?: { displayId?: string; bounds?: Bounds; widgets?: string[] }
  ): string {
    const windowId = generateId();

    const displays = screen.getAllDisplays();
    const targetDisplay = options?.displayId
      ? displays.find(d => d.id.toString() === options.displayId) || screen.getPrimaryDisplay()
      : screen.getPrimaryDisplay();

    const work = targetDisplay.workArea;
    const defaultBounds: Bounds = {
      x: work.x + 60,
      y: work.y + 60,
      width: Math.max(800, Math.floor(work.width * 0.7)),
      height: Math.max(600, Math.floor(work.height * 0.7)),
    };

    const bounds = options?.bounds || defaultBounds;

    const win = new BrowserWindow({
      x: bounds.x,
      y: bounds.y,
      width: bounds.width,
      height: bounds.height,
      minWidth: 800,
      minHeight: 600,
      backgroundColor: '#0F1216',
      show: false,
      webPreferences: {
        contextIsolation: true,
        nodeIntegration: false,
        preload: path.join(__dirname, 'preload.js'),
        webSecurity: true,
        sandbox: true,
      },
    });

    // Load renderer with identifiers in query params
    const baseUrl = process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : `file://${path.join(__dirname, '../out/index.html')}`;
    const url = process.env.NODE_ENV === 'development'
      ? `${baseUrl}/dashboards?dashboardId=${encodeURIComponent(dashboardId)}&windowId=${windowId}`
      : `${baseUrl}?dashboardId=${encodeURIComponent(dashboardId)}&windowId=${windowId}`;

    void win.loadURL(url);

    win.once('ready-to-show', () => win.show());

    // Track position/size for persistence
    const persist = () => {
      const b = win.getBounds();
      const disp = screen.getDisplayNearestPoint({ x: b.x, y: b.y });
      this.updateState(windowId, { bounds: b as Bounds, displayId: disp.id.toString() });
    };
    win.on('moved', persist);
    win.on('resized', persist);

    win.on('closed', () => {
      this.windows.delete(windowId);
      this.removeState(windowId);
    });

    this.windows.set(windowId, win);
    this.saveState({
      windowId,
      dashboardId,
      bounds,
      displayId: targetDisplay.id.toString(),
      widgets: options?.widgets || [],
    });

    return windowId;
  }

  closeWindow(windowId: string): void {
    const win = this.windows.get(windowId);
    if (win) {
      win.close();
      this.windows.delete(windowId);
      this.removeState(windowId);
    }
  }

  restoreWindows(): void {
    const states = this.getStates();
    states.forEach(s => {
      try {
        this.createDashboardWindow(s.dashboardId, { bounds: s.bounds, displayId: s.displayId, widgets: s.widgets });
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error('Failed to restore window', s.windowId, e);
      }
    });
  }

  getDisplays(): Array<{ id: string; bounds: Bounds; workArea: Bounds; scaleFactor: number; rotation: number; primary: boolean }>{
    const primary = screen.getPrimaryDisplay();
    return screen.getAllDisplays().map(d => ({
      id: d.id.toString(),
      bounds: d.bounds as Bounds,
      workArea: d.workArea as Bounds,
      scaleFactor: d.scaleFactor,
      rotation: d.rotation,
      primary: d.id === primary.id,
    }));
  }

  arrangeWindows(dashboardId: string, layout: 'tile' | 'cascade' | 'grid'): void {
    const states = this.getStates().filter(s => s.dashboardId === dashboardId);
    const wins = states.map(s => ({ s, w: this.windows.get(s.windowId) })).filter(x => !!x.w) as Array<{ s: WindowState; w: BrowserWindow }>;
    if (wins.length === 0) return;

    const primary = screen.getPrimaryDisplay();
    switch (layout) {
      case 'tile':
        this.tile(wins, primary);
        break;
      case 'cascade':
        this.cascade(wins, primary);
        break;
      case 'grid':
        this.grid(wins);
        break;
    }
  }

  private tile(wins: Array<{ s: WindowState; w: BrowserWindow }>, display: Electron.Display): void {
    const count = wins.length;
    const cols = Math.ceil(Math.sqrt(count));
    const rows = Math.ceil(count / cols);
    const area = display.workArea;
    const tileW = Math.floor(area.width / cols);
    const tileH = Math.floor(area.height / rows);

    wins.forEach(({ w }, i) => {
      const c = i % cols;
      const r = Math.floor(i / cols);
      w.setBounds({ x: area.x + c * tileW, y: area.y + r * tileH, width: tileW, height: tileH });
    });
  }

  private cascade(wins: Array<{ s: WindowState; w: BrowserWindow }>, display: Electron.Display): void {
    const area = display.workArea;
    const baseW = Math.min(1200, Math.floor(area.width * 0.8));
    const baseH = Math.min(800, Math.floor(area.height * 0.8));
    const offset = 32;

    wins.forEach(({ w }, i) => {
      w.setBounds({ x: area.x + offset * i, y: area.y + offset * i, width: baseW, height: baseH });
    });
  }

  private grid(wins: Array<{ s: WindowState; w: BrowserWindow }>): void {
    const displays = screen.getAllDisplays();
    if (displays.length === 0) return;

    const perDisplay = Math.ceil(wins.length / displays.length);

    wins.forEach(({ w }, index) => {
      const dIdx = Math.floor(index / perDisplay);
      const d = displays[dIdx] || displays[0];
      const localIndex = index % perDisplay;
      const cols = Math.ceil(Math.sqrt(perDisplay));
      const rows = Math.ceil(perDisplay / cols);
      const area = d.workArea;
      const tileW = Math.floor(area.width / cols);
      const tileH = Math.floor(area.height / rows);
      const c = localIndex % cols;
      const r = Math.floor(localIndex / cols);
      w.setBounds({ x: area.x + c * tileW, y: area.y + r * tileH, width: tileW, height: tileH });
    });
  }

  private registerIpc(): void {
    ipcMain.handle('window:create', (_e, dashboardId: string, options?: { displayId?: string; bounds?: Bounds; widgets?: string[] }) => {
      if (typeof dashboardId !== 'string' || !dashboardId) throw new Error('Invalid dashboardId');
      return this.createDashboardWindow(dashboardId, options);
    });

    ipcMain.handle('window:close', (_e, windowId: string) => {
      if (typeof windowId !== 'string' || !windowId) throw new Error('Invalid windowId');
      this.closeWindow(windowId);
    });

    ipcMain.handle('window:getDisplays', () => {
      return this.getDisplays();
    });

    ipcMain.handle('window:arrange', (_e, dashboardId: string, layout: 'tile' | 'cascade' | 'grid') => {
      if (typeof dashboardId !== 'string' || !dashboardId) throw new Error('Invalid dashboardId');
      if (!['tile', 'cascade', 'grid'].includes(layout)) throw new Error('Invalid layout');
      this.arrangeWindows(dashboardId, layout);
    });

    ipcMain.on('window:send', (_e, windowId: string, channel: string, data: any) => {
      const win = this.windows.get(windowId);
      if (win && typeof channel === 'string') {
        win.webContents.send(channel, data);
      }
    });

    ipcMain.on('window:broadcast', (_e, channel: string, data: any) => {
      if (typeof channel !== 'string') return;
      this.windows.forEach(w => w.webContents.send(channel, data));
    });
  }
}

export const windowManager = WindowManager.instance;
