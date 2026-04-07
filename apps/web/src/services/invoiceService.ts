import type { Invoice, InvoiceItem } from '../types/ownerOperator';

const genId = () => `inv_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

export class InvoiceService {
  async createInvoice(data: {
    clientName: string;
    clientAddress: string;
    items: InvoiceItem[];
    taxRate?: number;
    dueInDays?: number;
  }): Promise<Invoice> {
    const date = new Date();
    const dueDate = new Date(date);
    dueDate.setDate(dueDate.getDate() + (data.dueInDays || 30));

    const subtotal = data.items.reduce((sum, i) => sum + i.amount, 0);
    const tax = subtotal * (data.taxRate || 0);
    const total = subtotal + tax;

    const invoice: Invoice = {
      id: genId(),
      invoiceNumber: this.generateInvoiceNumber(),
      date,
      dueDate,
      clientName: data.clientName,
      clientAddress: data.clientAddress,
      items: data.items,
      subtotal,
      tax,
      total,
      status: 'draft',
    };

    await this.saveInvoice(invoice);
    return invoice;
  }

  async createInvoiceFromLoad(loadData: {
    loadId: string;
    clientName: string;
    clientAddress: string;
    origin: string;
    destination: string;
    miles: number;
    ratePerMile: number;
    additionalCharges?: Array<{ description: string; amount: number }>; 
  }): Promise<Invoice> {
    const items: InvoiceItem[] = [
      {
        description: `Transportation: ${loadData.origin} to ${loadData.destination}`,
        quantity: loadData.miles,
        rate: loadData.ratePerMile,
        amount: loadData.miles * loadData.ratePerMile,
      },
    ];

    if (loadData.additionalCharges) {
      for (const ch of loadData.additionalCharges) {
        items.push({ description: ch.description, quantity: 1, rate: ch.amount, amount: ch.amount });
      }
    }

    return this.createInvoice({ clientName: loadData.clientName, clientAddress: loadData.clientAddress, items });
  }

  private generateInvoiceNumber(): string {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const rand = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
    return `INV-${y}${m}-${rand}`;
  }

  private async saveInvoice(invoice: Invoice) {
    if (process.env.NODE_ENV !== 'production') {
      // eslint-disable-next-line no-console
      console.log('[InvoiceService] Saving invoice (mock):', invoice.invoiceNumber);
    }
  }
}

export const invoiceService = new InvoiceService();
