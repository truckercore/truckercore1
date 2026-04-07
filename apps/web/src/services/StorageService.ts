import { promises as fs } from 'fs';

export class StorageService {
  public async readFile(path: string): Promise<Buffer> {
    return fs.readFile(path);
  }
}

export default StorageService;
