import { autoUpdater } from 'electron-updater';
import { BrowserWindow, dialog, Notification } from 'electron';
import log from 'electron-log';
import * as crypto from 'crypto';
import * as fs from 'fs';

// Configure logging
(autoUpdater as any).logger = log;
log.transports.file.level = 'info';

export class SecureAutoUpdater {
  private mainWindow: BrowserWindow;
  private updateCheckInterval: NodeJS.Timeout | null = null;
  private isChecking = false;
  private updateDownloaded = false;

  constructor(mainWindow: BrowserWindow) {
    this.mainWindow = mainWindow;
    this.configureUpdater();
    this.setupEventHandlers();
  }

  private configureUpdater() {
    // Manual download for user control
    autoUpdater.autoDownload = false;
    autoUpdater.autoInstallOnAppQuit = true;

    // Prefer publish config from package.json, but allow programmatic overrides via env
    // If GH_OWNER/REPO provided, set GitHub feed URL. Otherwise rely on electron-builder publish cfg.
    const ghOwner = process.env.GH_OWNER || 'your-org';
    const ghRepo = process.env.GH_REPO || 'truckercore';
    const ghToken = process.env.GH_TOKEN;

    try {
      autoUpdater.setFeedURL({
        provider: 'github',
        owner: ghOwner,
        repo: ghRepo,
        private: false,
        token: ghToken,
      } as any);
    } catch (e) {
      log.warn('[auto-updater] setFeedURL failed or not required; relying on publish config. Error:', e);
    }

    autoUpdater.allowDowngrade = false;
    autoUpdater.allowPrerelease = false;
  }

  private setupEventHandlers() {
    autoUpdater.on('checking-for-update', () => {
      log.info('Checking for updates...');
      this.isChecking = true;
      this.sendStatusToWindow('Checking for updates...');
    });

    autoUpdater.on('update-available', (info) => {
      log.info('Update available:', info);
      this.isChecking = false;

      const notification = new Notification({
        title: '🎉 Update Available',
        body: `Version ${info.version} is available. Click to download.`,
        urgency: 'normal' as any,
        silent: false,
      });

      notification.on('click', () => {
        this.downloadUpdate();
      });

      notification.show();

      // Show in-app notification
      this.mainWindow.webContents.send('update-available', {
        version: (info as any).version,
        releaseDate: (info as any).releaseDate,
        releaseNotes: (info as any).releaseNotes,
        size: this.formatBytes((info as any).files?.[0]?.size || 0),
      });
    });

    autoUpdater.on('update-not-available', (info) => {
      log.info('Update not available:', info);
      this.isChecking = false;
      this.sendStatusToWindow('You are running the latest version.');
    });

    autoUpdater.on('download-progress', (progressObj) => {
      const percent = Math.round(progressObj.percent);
      log.info(`Download progress: ${percent}%`);

      this.mainWindow.webContents.send('update-download-progress', {
        percent,
        transferred: this.formatBytes(progressObj.transferred),
        total: this.formatBytes(progressObj.total),
        bytesPerSecond: this.formatBytes(progressObj.bytesPerSecond),
      });

      // Taskbar/dock progress
      this.mainWindow.setProgressBar(percent / 100);
    });

    autoUpdater.on('update-downloaded', async (info) => {
      log.info('Update downloaded:', info);
      this.updateDownloaded = true;
      this.mainWindow.setProgressBar(-1); // Remove progress bar

      try {
        const isValid = await this.verifyDownloadedUpdate(info as any);
        if (isValid) {
          this.promptInstallUpdate(info as any);
        } else {
          this.handleUpdateError(new Error('Update verification failed - checksum mismatch'));
        }
      } catch (err: any) {
        this.handleUpdateError(err);
      }
    });

    autoUpdater.on('error', (error) => {
      this.handleUpdateError(error as any);
    });
  }

  private async verifyDownloadedUpdate(info: any): Promise<boolean> {
    try {
      // Note: electron-updater validates signatures for platform installers.
      // As an additional defense-in-depth, compute SHA-256 if file path is available.
      const anyUpdater: any = autoUpdater as any;
      const updateFilePath: string | undefined = anyUpdater.downloadedUpdateHelper?.downloadedFileInfo?.path;

      if (!updateFilePath) {
        log.warn('No update file path available for verification; relying on signature.');
        return true;
      }

      const fileBuffer = fs.readFileSync(updateFilePath);
      const hashSum = crypto.createHash('sha256');
      hashSum.update(fileBuffer);
      const hex = hashSum.digest('hex');

      const expectedHash: string | undefined = (info as any).sha512 || (info as any).sha256;
      if (expectedHash) {
        const isValid = hex === expectedHash;
        log.info(`Update verification: ${isValid ? 'PASSED' : 'FAILED'}`);
        return isValid;
      }

      log.warn('No checksum available in update info; proceeding based on signature validation.');
      return true;
    } catch (error) {
      log.error('Update verification error:', error);
      return false;
    }
  }

  private promptInstallUpdate(info: any) {
    const notification = new Notification({
      title: '✅ Update Ready',
      body: `Version ${info.version} is ready to install. Restart now?`,
      urgency: 'critical' as any,
      timeoutType: 'never' as any,
    });
    notification.show();

    void dialog
      .showMessageBox(this.mainWindow, {
        type: 'info',
        title: 'Update Ready to Install',
        message: `TruckerCore ${info.version} is ready to install.`,
        detail: 'The application will restart to complete the update.',
        buttons: ['Install Now', 'Install on Next Launch', 'View Release Notes'],
        defaultId: 0,
        cancelId: 1,
      })
      .then((result) => {
        if (result.response === 0) {
          this.installUpdate();
        } else if (result.response === 1) {
          this.sendStatusToWindow('Update will be installed when you close the app.');
        } else if (result.response === 2) {
          this.mainWindow.webContents.send('show-release-notes', info.releaseNotes);
        }
      });
  }

  public checkForUpdates(userInitiated = false) {
    if (this.isChecking) {
      log.info('Update check already in progress');
      return;
    }

    if (userInitiated) {
      this.sendStatusToWindow('Checking for updates...');
    }

    void autoUpdater
      .checkForUpdates()
      .then((result) => {
        log.info('Check for updates result:', result?.updateInfo?.version ?? 'n/a');
      })
      .catch((error) => {
        log.error('Check for updates error:', error);
        if (userInitiated) {
          this.sendStatusToWindow('Failed to check for updates. Please try again later.');
        }
      });
  }

  public downloadUpdate() {
    log.info('Starting update download...');
    this.sendStatusToWindow('Downloading update...');
    void autoUpdater.downloadUpdate();
  }

  public installUpdate() {
    if (!this.updateDownloaded) {
      log.warn('No update downloaded to install');
      return;
    }

    log.info('Installing update and restarting app...');
    this.mainWindow.webContents.send('before-update-install');
    setTimeout(() => {
      autoUpdater.quitAndInstall(false, true);
    }, 5000);
  }

  public startAutoUpdateChecks(intervalHours = 4) {
    // Check shortly after startup
    setTimeout(() => {
      this.checkForUpdates(false);
    }, 10000);

    this.updateCheckInterval = setInterval(() => {
      this.checkForUpdates(false);
    }, intervalHours * 60 * 60 * 1000);

    log.info(`Auto-update checks scheduled every ${intervalHours} hours`);
  }

  public stopAutoUpdateChecks() {
    if (this.updateCheckInterval) {
      clearInterval(this.updateCheckInterval);
      this.updateCheckInterval = null;
      log.info('Auto-update checks stopped');
    }
  }

  private handleUpdateError(error: Error) {
    log.error('Auto-updater error:', error);
    this.isChecking = false;
    this.mainWindow.setProgressBar(-1);

    const notification = new Notification({
      title: '❌ Update Error',
      body: 'Failed to download update. Check your internet connection.',
      urgency: 'normal' as any,
    });
    notification.show();

    this.mainWindow.webContents.send('update-error', {
      message: (error as any)?.message ?? String(error),
      code: (error as any)?.code,
    });
  }

  private sendStatusToWindow(message: string) {
    this.mainWindow.webContents.send('update-status', message);
  }

  private formatBytes(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
  }
}
