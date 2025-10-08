import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { OCRService } from '../ocrService';

// Mock tesseract.js to avoid heavy OCR in unit tests
vi.mock('tesseract.js', () => {
  const recognize = vi.fn(async () => ({ data: { text: SAMPLE_TEXT } }));
  return {
    createWorker: vi.fn(async () => ({
      recognize,
      terminate: vi.fn(async () => undefined),
    })),
  };
});

const SAMPLE_TEXT = `
Pilot Travel Center
123 Main St
Total: $123.45
11.50 gal @ $3.999 / gal
Date: 2025-09-30
`;

describe('OCRService', () => {
  let service: OCRService;

  beforeEach(() => {
    service = new OCRService();
  });

  afterEach(async () => {
    await service.terminate();
  });

  it('parses receipt text and extracts key fields', async () => {
    const data = await service.parseReceipt('dummy');

    expect(data.merchantName).toBe('Pilot Travel Center');
    expect(data.amount).toBeCloseTo(123.45, 2);
    expect(data.fuelGallons).toBeCloseTo(11.5, 2);
    expect(data.pricePerGallon).toBeCloseTo(3.999, 3);
    expect(data.category).toBe('fuel');
    expect(data.date).toBeInstanceOf(Date);
  });

  it('handles missing values gracefully', async () => {
    // Override mock to return minimal text
    const mod = await import('tesseract.js');
    // @ts-expect-error - accessing mocked function
    mod.createWorker.mockResolvedValue({
      recognize: vi.fn(async () => ({ data: { text: 'Some Store\nSubtotal $10.00' } })),
      terminate: vi.fn(async () => undefined),
    });

    const s = new OCRService();
    const d = await s.parseReceipt('img');
    expect(d.amount).toBe(10.0);
    expect(d.fuelGallons).toBeUndefined();
    await s.terminate();
  });
});
