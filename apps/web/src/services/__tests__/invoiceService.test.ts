import { describe, it, expect, vi } from 'vitest';
import { InvoiceService } from '../invoiceService';

const svc = new InvoiceService();

describe('InvoiceService', () => {
  it('creates invoice with correct totals and due date', async () => {
    const now = new Date('2025-10-01T00:00:00Z');
    vi.setSystemTime(now);

    const invoice = await svc.createInvoice({
      clientName: 'ACME',
      clientAddress: '1 Road',
      taxRate: 0.1,
      items: [
        { description: 'Line 1', quantity: 2, rate: 50, amount: 100 },
        { description: 'Line 2', quantity: 1, rate: 25, amount: 25 },
      ],
    });

    expect(invoice.subtotal).toBe(125);
    expect(invoice.tax).toBeCloseTo(12.5, 1);
    expect(invoice.total).toBeCloseTo(137.5, 1);
    expect(invoice.status).toBe('draft');
    // 30 days after now
    expect(invoice.dueDate.getTime()).toBe(new Date('2025-10-31T00:00:00.000Z').getTime());
  });

  it('creates invoice from load data', async () => {
    const invoice = await svc.createInvoiceFromLoad({
      loadId: 'load1',
      clientName: 'Big Shipper',
      clientAddress: 'Dock 9',
      origin: 'DAL',
      destination: 'HOU',
      miles: 240,
      ratePerMile: 2.5,
      additionalCharges: [{ description: 'TONU', amount: 150 }],
    });

    expect(invoice.items.length).toBe(2);
    expect(invoice.subtotal).toBeCloseTo(240 * 2.5 + 150, 1);
  });
});
