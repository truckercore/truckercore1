import { createWorker } from 'tesseract.js';

export interface ReceiptData {
  merchantName?: string;
  date?: Date;
  amount?: number;
  category?: string;
  items?: Array<{ name: string; price: number }>;
  fuelGallons?: number;
  pricePerGallon?: number;
}

export class OCRService {
  private worker: any | null = null;

  async initialize() {
    if (!this.worker) {
      this.worker = await createWorker('eng');
    }
  }

  async parseReceipt(imageFile: File | string): Promise<ReceiptData> {
    await this.initialize();
    if (!this.worker) throw new Error('OCR worker not initialized');

    const { data: { text } } = await this.worker.recognize(imageFile as any);
    return this.extractReceiptData(text);
  }

  private extractReceiptData(text: string): ReceiptData {
    const data: ReceiptData = {};

    // Extract date
    const datePatterns = [
      /(\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4})/,
      /(\d{4}[-\/]\d{1,2}[-\/]\d{1,2})/,
    ];

    for (const pattern of datePatterns) {
      const dateMatch = text.match(pattern);
      if (dateMatch) {
        data.date = new Date(dateMatch[1]);
        break;
      }
    }

    // Extract total amount
    const amountPatterns = [
      /total[:\s]*\$?(\d+\.\d{2})/i,
      /amount[:\s]*\$?(\d+\.\d{2})/i,
      /\$\s*(\d+\.\d{2})\s*$/m,
    ];

    for (const pattern of amountPatterns) {
      const amountMatch = text.match(pattern);
      if (amountMatch) {
        data.amount = parseFloat(amountMatch[1]);
        break;
      }
    }

    // Extract fuel-specific data
    const fuelGallonMatch = text.match(/(\d+\.\d{2,3})\s*gal/i);
    if (fuelGallonMatch) {
      data.fuelGallons = parseFloat(fuelGallonMatch[1]);
      data.category = 'fuel';
    }

    const pricePerGallonMatch = text.match(/\$?(\d+\.\d{2,3})\s*\/?\s*gal/i);
    if (pricePerGallonMatch) {
      data.pricePerGallon = parseFloat(pricePerGallonMatch[1]);
    }

    // Extract merchant name (first non-empty line)
    const lines = text.split('\n').filter((line) => line.trim());
    if (lines.length > 0) {
      data.merchantName = lines[0].trim();
    }

    return data;
  }

  async terminate() {
    if (this.worker) {
      await this.worker.terminate();
      this.worker = null;
    }
  }
}

export const ocrService = new OCRService();
