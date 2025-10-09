import { promises as fs } from 'fs';
import { ProcessingQueue } from './ProcessingQueue';
import { StorageService } from './StorageService';

export interface UploadedFile {
  id: string;
  name: string;
  path: string;
  size: number;
  type: string;
  uploadedAt: Date;
}

export interface ProcessResult {
  success: boolean;
  jobId?: string;
  error?: string;
}

export interface ParsedCSV {
  headers: string[];
  rows: Record<string, string>[];
}

export class FileProcessor {
  private queue: ProcessingQueue;
  private storage: StorageService;
  private static readonly MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB

  constructor(queue?: ProcessingQueue, storage?: StorageService) {
    this.queue = queue || new ProcessingQueue();
    this.storage = storage || new StorageService();
  }

  public async processFile(file: UploadedFile): Promise<ProcessResult> {
    if (file.size > FileProcessor.MAX_FILE_SIZE) {
      throw new Error('File size exceeds limit');
    }

    try {
      const buffer = await this.storage.readFile(file.path);
      // Minimal validation: ensure non-empty
      if (!buffer || buffer.length === 0) {
        throw new Error('Empty file');
      }

      // Enqueue job
      const jobId = await this.queue.addJob({
        fileId: file.id,
        fileName: file.name,
        fileType: file.type,
        size: file.size
      });

      return { success: true, jobId };
    } catch (err: any) {
      throw new Error(err?.message || 'Processing failed');
    }
  }

  public async parseCSV(csvData: string): Promise<ParsedCSV> {
    const lines = this.splitLines(csvData);
    if (lines.length === 0) return { headers: [], rows: [] };

    const headers = this.parseCsvLine(lines[0]);
    const rows: Record<string, string>[] = [];

    for (let i = 1; i < lines.length; i++) {
      if (lines[i].trim() === '') continue;
      const values = this.parseCsvLine(lines[i]);
      const row: Record<string, string> = {};
      headers.forEach((h, idx) => {
        row[h] = values[idx] ?? '';
      });
      rows.push(row);
    }

    return { headers, rows };
  }

  // Simulated streaming parse to keep memory usage lower for very large inputs
  public async parseCSVStream(csvData: string): Promise<void> {
    const lines = this.splitLines(csvData);
    if (lines.length === 0) return;
    // First line headers
    const headers = this.parseCsvLine(lines[0]);

    // Process in chunks to avoid retaining all rows
    const CHUNK = 1000;
    let batch: any[] = [];
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      if (line.trim() === '') continue;
      const values = this.parseCsvLine(line);
      const row: Record<string, string> = {};
      headers.forEach((h, idx) => (row[h] = values[idx] ?? ''));
      batch.push(row);
      if (batch.length >= CHUNK) {
        // pretend to process
        batch = [];
        await Promise.resolve(); // yield to event loop
      }
    }
  }

  private splitLines(data: string): string[] {
    // Support both \r\n and \n
    return data.replace(/\r\n/g, '\n').split('\n');
  }

  private parseCsvLine(line: string): string[] {
    const result: string[] = [];
    let current = '';
    let inQuotes = false;

    for (let i = 0; i < line.length; i++) {
      const char = line[i];

      if (inQuotes) {
        if (char === '"') {
          // Check for escaped quote
          if (i + 1 < line.length && line[i + 1] === '"') {
            current += '"';
            i++; // skip the escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          current += char;
        }
      } else {
        if (char === ',') {
          result.push(current);
          current = '';
        } else if (char === '"') {
          inQuotes = true;
        } else {
          current += char;
        }
      }
    }

    result.push(current);
    return result;
  }
}

export default FileProcessor;
