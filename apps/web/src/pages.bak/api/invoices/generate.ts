import type { NextApiRequest, NextApiResponse } from 'next';
import { invoiceService } from '../../../../src/services/invoiceService';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'POST') {
    try {
      const invoice = await invoiceService.createInvoiceFromLoad(req.body);
      res.status(201).json(invoice);
    } catch (error) {
      res.status(500).json({ message: 'Failed to generate invoice' });
    }
  } else {
    res.status(405).json({ message: 'Method not allowed' });
  }
}
