import { describe, it, expect, vi, beforeEach } from 'vitest';
import { exportService } from '../ExportService';

// Mock DOM APIs used by downloadBlob
beforeEach(() => {
  // @ts-expect-error test shim
  global.URL = {
    createObjectURL: vi.fn(() => 'blob:mock'),
    revokeObjectURL: vi.fn(),
  } as any;

  const appendChild = vi.fn();
  const removeChild = vi.fn();
  const click = vi.fn();

  vi.spyOn(document, 'createElement').mockImplementation((tag: string) => {
    if (tag === 'a') {
      return { href: '', download: '', click } as any;
    }
    return document.createElement(tag);
  });
  vi.spyOn(document.body, 'appendChild').mockImplementation(appendChild as any);
  vi.spyOn(document.body, 'removeChild').mockImplementation(removeChild as any);
});

describe('ExportService', () => {
  it('exports JSON and triggers download', async () => {
    const spy = vi.spyOn<any, any>(exportService as any, 'downloadBlob').mockImplementation(() => {});
    const data = [{ a: 1 }, { a: 2 }];

    const blob = await exportService.export({ format: 'json', data, filename: 't.json' });
    expect(blob).toBeInstanceOf(Blob);

    const text = await (blob as Blob).text();
    expect(text).toContain('"a": 1');
    expect(spy).toHaveBeenCalled();
  });

  it('exports CSV via json2csv Parser', async () => {
    // Mock json2csv parser
    vi.doMock('@json2csv/plainjs', () => {
      return { Parser: class { parse() { return 'a,b\n1,2'; } } };
    });
    // Re-import module to apply mock
    const { exportService: svc } = await import('../ExportService');
    const spy = vi.spyOn<any, any>(svc as any, 'downloadBlob').mockImplementation(() => {});

    const blob = await svc.exportToCSV({ format: 'csv', data: [{ a: 1, b: 2 }] });
    expect(blob).toBeInstanceOf(Blob);
    const text = await blob.text();
    expect(text).toContain('a,b');
    expect(spy).toHaveBeenCalled();
  });
});
