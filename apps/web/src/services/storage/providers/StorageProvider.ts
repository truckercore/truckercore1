import { DashboardStorage } from '../interfaces/IDashboardStorage';
import { LocalStorageDashboardStorage } from '../implementations/SharedPreferencesStorage';
import DefaultStorageMonitor from '../implementations/DefaultStorageMonitor';
import { MonitoredDashboardStorage } from '../decorators/MonitoredDashboardStorage';

export class StorageProvider {
  static getStorage(): DashboardStorage {
    const base = new LocalStorageDashboardStorage();
    const monitor = DefaultStorageMonitor.getInstance();
    return new MonitoredDashboardStorage(base, monitor);
  }
}

export default StorageProvider;
